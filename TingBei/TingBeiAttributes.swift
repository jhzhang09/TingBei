import Foundation
import ActivityKit

public struct TingBeiAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var units: Double
        public var softLimit: Int
        public var hardLimit: Int
        public var cue: String
        public var title: String
        public var message: String
        public var nextPromptAt: Date?
        public var elapsedSeconds: TimeInterval
        public var isOver: Bool

        public init(
            units: Double,
            softLimit: Int,
            hardLimit: Int,
            cue: String,
            title: String,
            message: String,
            nextPromptAt: Date?,
            elapsedSeconds: TimeInterval,
            isOver: Bool
        ) {
            self.units = units
            self.softLimit = softLimit
            self.hardLimit = hardLimit
            self.cue = cue
            self.title = title
            self.message = message
            self.nextPromptAt = nextPromptAt
            self.elapsedSeconds = elapsedSeconds
            self.isOver = isOver
        }
    }

    public var startedAt: Date
    public var planName: String

    public init(startedAt: Date, planName: String) {
        self.startedAt = startedAt
        self.planName = planName
    }
}
