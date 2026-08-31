import Foundation
import SwiftData

@Model
final class StudySession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date
    var focusMinutes: Int
    var note: String
    var moodRating: Int?
    var sourceRaw: String

    var subject: Subject?
    var event: StudyEvent?

    var source: SessionSource {
        get { SessionSource(rawValue: sourceRaw) ?? .pomodoro }
        set { sourceRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(),
         startedAt: Date,
         endedAt: Date,
         focusMinutes: Int,
         note: String = "",
         moodRating: Int? = nil,
         source: SessionSource = .pomodoro,
         subject: Subject? = nil,
         event: StudyEvent? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.focusMinutes = focusMinutes
        self.note = note
        self.moodRating = moodRating
        self.sourceRaw = source.rawValue
        self.subject = subject
        self.event = event
    }
}
