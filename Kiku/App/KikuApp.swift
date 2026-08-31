import SwiftUI
import SwiftData

@main
struct KikuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = SettingsStore()
    @StateObject private var focusTimer = FocusTimer.shared

    private let container: ModelContainer?

    init() {
        container = Self.makeContainer()
    }

    /// Builds the data store, falling back to an in-memory store so the app never
    /// crashes on launch if the on-disk store can't be opened or migrated.
    private static func makeContainer() -> ModelContainer? {
        if let persistent = try? ModelContainer(
            for: Subject.self, StudyEvent.self, StudySession.self, Goal.self) {
            return persistent
        }
        let memoryOnly = ModelConfiguration(isStoredInMemoryOnly: true)
        return try? ModelContainer(
            for: Subject.self, StudyEvent.self, StudySession.self, Goal.self,
            configurations: memoryOnly)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootView()
                        .modelContainer(container)
                        .environmentObject(settings)
                        .environmentObject(focusTimer)
                        .preferredColorScheme(settings.preferredColorScheme)
                        .frame(minWidth: 900, minHeight: 640)
                        .tint(Theme.Palette.accent)
                } else {
                    StartupErrorView()
                        .preferredColorScheme(settings.preferredColorScheme)
                        .frame(minWidth: 900, minHeight: 640)
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 760)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(focusTimer)
                .environmentObject(settings)
        } label: {
            MenuBarLabel()
                .environmentObject(focusTimer)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Shown only if the data store can't be created at all — a friendly fallback
/// instead of a crash.
private struct StartupErrorView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("🎐").font(.system(size: 52))
            Text("Kiku couldn't open its notebook")
                .font(.kTitle).foregroundStyle(Theme.Palette.textPrimary)
            Text("Something went wrong loading your data. Please quit and reopen Kiku. If it keeps happening, restarting your Mac usually fixes it 💛")
                .font(.kBody).foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button("Quit Kiku") { NSApp.terminate(nil) }
                .buttonStyle(.borderedProminent).tint(Theme.Palette.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.bg)
    }
}

/// Menu-bar icon that shows the live focus countdown when a session is running.
private struct MenuBarLabel: View {
    @EnvironmentObject private var focusTimer: FocusTimer

    var body: some View {
        HStack(spacing: 4) {
            Image("MenuBarIcon")
                .renderingMode(.template)
            if focusTimer.isActive {
                Text(focusTimer.remainingText).monospacedDigit()
            }
        }
    }
}
