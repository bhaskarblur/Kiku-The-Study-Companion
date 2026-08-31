import Foundation
import SwiftData

@Model
final class StudyEvent {
    @Attribute(.unique) var id: UUID
    var title: String
    var start: Date
    var end: Date
    var notes: String
    var colorHex: String
    var reminderLeadMinutes: Int
    var recurrenceRaw: String
    var presenceCheckEnabled: Bool
    var createdAt: Date

    /// Identifier of the mirrored EventKit event (for Calendar/Google sync), if any.
    var ekIdentifier: String?

    var subject: Subject?

    @Relationship(deleteRule: .nullify, inverse: \StudySession.event)
    var sessions: [StudySession] = []

    var recurrence: Recurrence {
        get { Recurrence(rawValue: recurrenceRaw) ?? .none }
        set { recurrenceRaw = newValue.rawValue }
    }

    var durationMinutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }

    /// True when the event window has passed with no logged session.
    var wasSkipped: Bool { end < .now && sessions.isEmpty }

    init(id: UUID = UUID(),
         title: String,
         start: Date,
         end: Date,
         notes: String = "",
         colorHex: String = Theme.subjectColors[0],
         reminderLeadMinutes: Int = 10,
         recurrence: Recurrence = .none,
         presenceCheckEnabled: Bool = false,
         subject: Subject? = nil,
         createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.notes = notes
        self.colorHex = colorHex
        self.reminderLeadMinutes = reminderLeadMinutes
        self.recurrenceRaw = recurrence.rawValue
        self.presenceCheckEnabled = presenceCheckEnabled
        self.subject = subject
        self.createdAt = createdAt
    }
}
