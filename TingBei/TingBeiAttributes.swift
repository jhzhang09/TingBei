import Foundation
import ActivityKit

public struct TingBeiAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var units: Double
        public var confirmedUnits: Double?
        public var estimatedUnits: Double?
        public var softLimit: Double
        public var hardLimit: Double
        public var cue: String
        public var title: String
        public var message: String
        public var nextPromptAt: Date?
        public var elapsedSeconds: TimeInterval
        public var isOver: Bool
        public var physicalText: String?
        public var physicalSoftLimitText: String?
        public var overCount: Int?

        public init(
            units: Double,
            confirmedUnits: Double? = nil,
            estimatedUnits: Double? = nil,
            softLimit: Double,
            hardLimit: Double,
            cue: String,
            title: String,
            message: String,
            nextPromptAt: Date?,
            elapsedSeconds: TimeInterval,
            isOver: Bool,
            physicalText: String? = nil,
            physicalSoftLimitText: String? = nil,
            overCount: Int? = nil
        ) {
            self.units = units
            self.confirmedUnits = confirmedUnits
            self.estimatedUnits = estimatedUnits
            self.softLimit = softLimit
            self.hardLimit = hardLimit
            self.cue = cue
            self.title = title
            self.message = message
            self.nextPromptAt = nextPromptAt
            self.elapsedSeconds = elapsedSeconds
            self.isOver = isOver
            self.physicalText = physicalText
            self.physicalSoftLimitText = physicalSoftLimitText
            self.overCount = overCount
        }
    }

    public var startedAt: Date
    public var planName: String

    public init(startedAt: Date, planName: String) {
        self.startedAt = startedAt
        self.planName = planName
    }
}
