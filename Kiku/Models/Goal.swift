import Foundation
import SwiftData

@Model
final class Goal {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var target: Int
    var createdAt: Date

    var type: GoalType {
        get { GoalType(rawValue: typeRaw) ?? .dailyMinutes }
        set { typeRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), type: GoalType, target: Int, createdAt: Date = .now) {
        self.id = id
        self.typeRaw = type.rawValue
        self.target = target
        self.createdAt = createdAt
    }
}
