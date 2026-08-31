import Foundation
import Combine

enum FocusPhase: String {
    case idle, running, paused, finished
}

/// Whether the current countdown is a focus session or a break.
enum FocusKind {
    case focus, breakTime
}

/// Snapshot handed to the session-log sheet when a focus session ends.
struct PendingLog: Identifiable, Equatable {
    let id = UUID()
    let minutes: Int
    let subjectName: String?
    let colorHex: String
    let eventID: UUID?
}

/// Drives the Pomodoro focus timer. Survives view changes as an app-level object.
@MainActor
final class FocusTimer: ObservableObject {
    /// Shared instance so notification actions (e.g. "Start focus") can drive it too.
    static let shared = FocusTimer()

    @Published private(set) var phase: FocusPhase = .idle
    @Published private(set) var kind: FocusKind = .focus
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var total: TimeInterval = 0

    /// Context for the active session.
    @Published var subjectName: String? = nil
    @Published var subjectColorHex: String = Theme.subjectColors[0]
    @Published var linkedEventID: UUID? = nil

    /// Set when a session ends (naturally or via Finish) so the UI can prompt a log.
    @Published var pendingLog: PendingLog? = nil

    /// Number of focus sessions completed (used to decide short vs long break).
    private(set) var completedFocusSessions = 0

    private var timer: AnyCancellable?
    private(set) var startedAt: Date?

    // Persistence so an in-progress session survives quitting the app.
    private let stateKey = "kiku.focusTimerState"
    private let counterKey = "kiku.completedFocusSessions"

    private struct Snapshot: Codable {
        var kind: String
        var phase: String
        var total: Double
        var fireDate: Date?
        var remaining: Double
        var subjectName: String?
        var colorHex: String
        var linkedEventID: UUID?
    }

    init() {
        completedFocusSessions = UserDefaults.standard.integer(forKey: counterKey)
        restore()
    }

    var progress: Double {
        guard total > 0 else { return 0 }
        return 1 - (remaining / total)
    }

    var remainingText: String {
        let m = Int(remaining) / 60
        let s = Int(remaining) % 60
        return String(format: "%02d:%02d", m, s)
    }

    var isActive: Bool { phase == .running || phase == .paused }
    var isBreak: Bool { kind == .breakTime }

    func start(minutes: Int, subjectName: String? = nil, colorHex: String = Theme.subjectColors[0], eventID: UUID? = nil) {
        kind = .focus
        total = TimeInterval(minutes * 60)
        remaining = total
        self.subjectName = subjectName
        self.subjectColorHex = colorHex
        self.linkedEventID = eventID
        startedAt = .now
        phase = .running
        tick()
        persist()
    }

    /// Starts a break countdown (short or long). No session log at the end.
    func startBreak(minutes: Int) {
        kind = .breakTime
        total = TimeInterval(max(1, minutes) * 60)
        remaining = total
        subjectName = nil
        linkedEventID = nil
        startedAt = .now
        phase = .running
        tick()
        persist()
    }

    func pause() {
        guard phase == .running else { return }
        phase = .paused
        timer?.cancel()
        persist()
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .running
        tick()
        persist()
    }

    func stop() { resetToIdle() }

    /// Ends the current phase early. Focus → prompts a log for time done; break → back to idle.
    func finishNow() {
        guard isActive else { return }
        timer?.cancel()
        timer = nil
        remaining = 0
        switch kind {
        case .focus:
            phase = .finished
            queueLog()
        case .breakTime:
            resetToIdle()
        }
    }

    /// Elapsed focus minutes for logging a session.
    func elapsedMinutes() -> Int {
        max(0, Int((total - remaining) / 60))
    }

    private func tick() {
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.remaining > 0 else {
                    self.completeNaturally()
                    return
                }
                self.remaining -= 1
            }
    }

    private func completeNaturally() {
        timer?.cancel()
        timer = nil
        remaining = 0
        switch kind {
        case .focus:
            completedFocusSessions += 1
            UserDefaults.standard.set(completedFocusSessions, forKey: counterKey)
            phase = .finished
            NotificationManager.shared.fireNow(title: "Focus complete! 🎉",
                                               body: "Lovely work — time for a well-earned break ☕️")
            queueLog()
            clearPersisted()
        case .breakTime:
            NotificationManager.shared.fireNow(title: "Break’s over 🌱",
                                               body: "Ready for another focused round? You’ve got this.",
                                               category: NotificationManager.breakOverCategoryID)
            resetToIdle()
        }
    }

    private func queueLog() {
        pendingLog = PendingLog(minutes: max(1, elapsedMinutes()),
                                subjectName: subjectName,
                                colorHex: subjectColorHex,
                                eventID: linkedEventID)
    }

    private func resetToIdle() {
        timer?.cancel()
        timer = nil
        kind = .focus
        phase = .idle
        remaining = 0
        total = 0
        startedAt = nil
        linkedEventID = nil
        subjectName = nil
        pendingLog = nil
        clearPersisted()
    }

    // MARK: - Persistence

    private func persist() {
        guard isActive else { clearPersisted(); return }
        let snap = Snapshot(
            kind: kind == .breakTime ? "break" : "focus",
            phase: phase == .paused ? "paused" : "running",
            total: total,
            fireDate: phase == .running ? Date().addingTimeInterval(remaining) : nil,
            remaining: remaining,
            subjectName: subjectName,
            colorHex: subjectColorHex,
            linkedEventID: linkedEventID
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: stateKey)
        }
    }

    private func clearPersisted() {
        UserDefaults.standard.removeObject(forKey: stateKey)
    }

    /// Restores an in-progress session on launch, accounting for time elapsed while closed.
    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: stateKey),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }

        kind = snap.kind == "break" ? .breakTime : .focus
        total = snap.total
        subjectName = snap.subjectName
        subjectColorHex = snap.colorHex
        linkedEventID = snap.linkedEventID

        if snap.phase == "paused" {
            remaining = snap.remaining
            phase = .paused
            startedAt = Date().addingTimeInterval(-(total - remaining))
            return
        }

        // Was running — compute how much is left after the time away.
        let rem = (snap.fireDate ?? Date()).timeIntervalSinceNow
        if rem > 0.5 {
            remaining = rem
            phase = .running
            startedAt = Date().addingTimeInterval(-(total - remaining))
            tick()
        } else {
            // It finished while the app was closed.
            remaining = 0
            switch kind {
            case .focus:
                completedFocusSessions += 1
                UserDefaults.standard.set(completedFocusSessions, forKey: counterKey)
                phase = .finished
                queueLog()
            case .breakTime:
                kind = .focus
                phase = .idle
            }
            clearPersisted()
        }
    }
}
