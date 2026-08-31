import Foundation
import SwiftData

@Model
final class Subject {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var icon: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \StudyEvent.subject)
    var events: [StudyEvent] = []

    @Relationship(deleteRule: .nullify, inverse: \StudySession.subject)
    var sessions: [StudySession] = []

    init(id: UUID = UUID(),
         name: String,
         colorHex: String,
         icon: String = "book.closed.fill",
         createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.createdAt = createdAt
    }
}
