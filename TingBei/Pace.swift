import Foundation

/// 一杯「标准杯」按大约 14 克乙醇估算，只用来比较这一场的量。
/// 不是血液酒精浓度，也不能用来判断能不能开车。
///
/// 设计原则：真正喝酒时没人愿意一直点手机。所以这一场以「主动提醒」为主：
/// app 按节奏定时问一句，用户在通知上点一下就能确认；不理也行，按方案节奏估算。
/// 随着杯数和时间逼近自己定的线，提醒越来越密、越来越急，直到收杯。
enum Pace {
    static let gramsPerStandard = 14.0

    /// 在通知上点了「喝了一杯」但不知道具体喝了什么时，按一个标准杯记。
    static let genericDrink = DrinkPreset(id: "generic", name: "一杯", detail: "按 1 标准杯", grams: 14)

    /// 未来最多预排多少条提醒（系统上限 64 条，留出余量）。
    static let promptBudget = 48

    static let presets: [DrinkPreset] = [
        DrinkPreset(id: "beer330", name: "啤酒", detail: "330 ml", grams: 12),
        DrinkPreset(id: "beer500", name: "啤酒", detail: "500 ml", grams: 18),
        DrinkPreset(id: "wine", name: "红酒", detail: "150 ml", grams: 15),
        DrinkPreset(id: "huangjiu", name: "黄酒", detail: "100 ml", grams: 12),
        DrinkPreset(id: "baijiu", name: "白酒", detail: "一两 · 50 ml", grams: 21),
        DrinkPreset(id: "cocktail", name: "鸡尾酒", detail: "一杯", grams: 18),
    ]

    // MARK: - 提醒强度阶梯

    /// 当前该用哪一级提醒。杯数和时间任何一条先到都会升级，只升不降（除非用户纠正了杯数）。
    static func intensity(units: Double, elapsed: TimeInterval, session: Session) -> Intensity {
        let planned = session.plannedSeconds
        let soft = Double(max(session.softLimit, 1))
        let hard = Double(max(session.hardLimit, session.softLimit))
        let epsilon = 0.0001
        if units >= hard - epsilon || elapsed >= planned + 30 * 60 {
            return .over
        }
        if units >= soft - epsilon || elapsed >= planned {
            return .due
        }
        let pressure = max(units / soft, elapsed / planned)
        if pressure >= 0.75 {
            return .near
        }
        if pressure >= 0.45 {
            return .steady
        }
        return .quiet
    }

    /// 每一级提醒之间隔多久。越往后越密。
    static func gap(for intensity: Intensity, session: Session) -> TimeInterval {
        let base = session.minIntervalSeconds
        switch intensity {
        case .quiet:
            return max(15 * 60, base)
        case .steady:
            return max(12 * 60, base * 0.75)
        case .near:
            return min(20 * 60, max(10 * 60, base * 0.5))
        case .due:
            return 8 * 60
        case .over:
            return 4 * 60
        }
    }

    /// 没回应时按方案自己的节奏估算：在预定时长里刚好喝到建议线。
    static func estimateRate(_ session: Session) -> Double {
        guard session.estimateWhenSilent else { return 0 }
        return Double(session.softLimit) / session.plannedSeconds
    }

    // MARK: - 当前状态

    static func evaluate(_ session: Session, now: Date) -> PaceSnapshot {
        let elapsed = max(0, now.timeIntervalSince(session.startedAt))
        let confirmed = session.confirmedUnits(at: now)
        let estimated = session.estimatedUnits(at: now)
        let units = confirmed + estimated
        let level = intensity(units: units, elapsed: elapsed, session: session)

        let fast = tooFast(session, now: now)
        let lastDrink = session.drinks.filter { $0.at <= now }.max(by: { $0.at < $1.at })

        let cue: Cue
        switch level {
        case .over:
            cue = .over
        case .due:
            cue = .due
        case _ where fast.isTooFast:
            cue = .hurried
        case .near:
            cue = .near
        case .steady:
            cue = .settle
        case .quiet:
            cue = (lastDrink != nil || estimated > 0) ? .settle : .calm
        }

        let pending = session.prompts
            .filter { $0.reply == nil && $0.at <= now }
            .max(by: { $0.at < $1.at })
            .flatMap { prompt -> Prompt? in
                // 用户在这条提醒之后已经手动记过，就不再追问。
                if let lastDrink, lastDrink.at >= prompt.at { return nil }
                return prompt
            }
        let next = session.prompts
            .filter { $0.reply == nil && $0.at > now }
            .min(by: { $0.at < $1.at })

        let copy = copy(
            cue: cue,
            session: session,
            units: units,
            elapsed: elapsed,
            waitMinutes: fast.waitMinutes
        )

        return PaceSnapshot(
            cue: cue,
            intensity: level,
            title: copy.title,
            message: copy.message,
            units: units,
            confirmedUnits: confirmed,
            estimatedUnits: estimated,
            drinkCount: session.drinks.count,
            waterCount: session.waters.count,
            elapsed: elapsed,
            planned: session.plannedSeconds,
            isTooFast: fast.isTooFast,
            waitMinutes: fast.waitMinutes,
            sinceLastDrink: lastDrink.map { now.timeIntervalSince($0.at) },
            nextPrompt: next,
            pendingPrompt: pending,
            softLimit: session.softLimit,
            hardLimit: session.hardLimit
        )
    }

    // MARK: - 预排提醒

    /// 从现在起往后推算提醒时间表。确定性：同样的记录总是得到同样的时间，
    /// 所以每次回到前台重新排程都不会把提醒往后推。
    static func projectPrompts(_ session: Session, now: Date) -> [Prompt] {
        guard session.endedAt == nil else { return [] }
        let start = session.startedAt
        let rate = estimateRate(session)
        var units = session.confirmedUnits(at: now) + session.estimatedUnits(at: now)

        let pastPrompts = session.prompts.filter { $0.at <= now }
        let lastDrinkAt = session.drinks.map(\.at).filter { $0 <= now }.max()
        var anchor = max(start, lastDrinkAt ?? start, pastPrompts.map(\.at).max() ?? start)
        let isFresh = session.drinks.isEmpty && pastPrompts.isEmpty
        let horizon = start.addingTimeInterval(session.plannedSeconds * 3 + 2 * 3600)
        let planned = session.plannedSeconds
        let boundaries = [planned * 0.45, planned * 0.75, planned, planned + 30 * 60]
            .map { start.addingTimeInterval($0) }

        var result: [Prompt] = []
        while result.count < promptBudget {
            let current = intensity(units: units, elapsed: anchor.timeIntervalSince(start), session: session)
            var wait = gap(for: current, session: session)
            if isFresh && result.isEmpty {
                wait = min(wait, 20 * 60)
            }
            var at = anchor.addingTimeInterval(wait)
            // 对齐到下一级的起点，保证每一级都至少提醒一次；离得很近就并到那一刻。
            if let boundary = boundaries.first(where: { $0 > anchor.addingTimeInterval(60) }),
               boundary <= at || boundary.timeIntervalSince(at) < wait * 0.5 {
                at = boundary
            }
            if at < now.addingTimeInterval(60) {
                at = now.addingTimeInterval(60)
            }
            if at > horizon {
                break
            }
            let estimate = rate * at.timeIntervalSince(anchor)
            units += estimate
            let level = intensity(units: units, elapsed: at.timeIntervalSince(start), session: session)
            result.append(
                Prompt(
                    id: UUID(),
                    at: at,
                    level: level,
                    estimate: estimate,
                    projectedUnits: units,
                    reply: nil,
                    drinkID: nil
                )
            )
            anchor = at
        }
        return result
    }

    /// 通知文案。越往后越直接。`ordinal` 是进入越线后的第几次提醒。
    static func notificationCopy(for prompt: Prompt, session: Session, ordinal: Int) -> (title: String, body: String) {
        let n = Format.units(prompt.projectedUnits)
        let soft = session.softLimit
        let hard = session.hardLimit
        let unitsOver = prompt.projectedUnits >= Double(hard) - 0.0001
        let unitsDue = prompt.projectedUnits >= Double(soft) - 0.0001
        let overMinutes = max(0, Int(prompt.at.timeIntervalSince(session.startedAt) - session.plannedSeconds) / 60)
        let overGap = Int(gap(for: .over, session: session) / 60)

        switch prompt.level {
        case .quiet:
            if prompt.projectedUnits < 0.95 && session.drinks.isEmpty {
                return ("开喝了吗？", "喝了就点「喝了一杯」。不理也行，我按节奏估。")
            }
            return ("大概第 \(n) 杯了？", "点一下帮我对个数。不理也行，我按节奏估。")
        case .steady:
            return ("约 \(n) 杯了", "节奏还行。下一杯慢一点，先喝口水。")
        case .near:
            return ("快到线了", "约 \(n) 杯，你的线是 \(soft)。这杯就当最后一杯。")
        case .due:
            if unitsDue {
                return ("到线了，收吧", "约 \(n) 杯，到你定的 \(soft) 杯了。现在停，刚刚好。")
            }
            return ("时间到了，收吧", "预定的 \(Format.minutes(session.plannedMinutes))到了。现在停，刚刚好。")
        case .over:
            let lead = unitsOver
                ? "约 \(n) 杯，已经超过你定的上限 \(hard)。"
                : "已经超出预定 \(overMinutes) 分钟。"
            let tail = ordinal >= 4
                ? "现在停下，比再喝一杯好得多。"
                : "每 \(overGap) 分钟提醒一次，直到你点「我收杯了」。"
            return ("停。第 \(ordinal) 次提醒", lead + tail)
        }
    }

    // MARK: - 私有

    /// 两杯离得太近。间隔按上一杯的量加权：一两白酒要比一小瓶啤酒等得更久。
    private static func tooFast(_ session: Session, now: Date) -> (isTooFast: Bool, waitMinutes: Int) {
        let ordered = session.drinks.filter { $0.at <= now }.sorted { $0.at < $1.at }
        guard ordered.count >= 2 else { return (false, 0) }
        let last = ordered[ordered.count - 1]
        let previous = ordered[ordered.count - 2]
        let weight = min(2, max(0.5, previous.grams / gramsPerStandard))
        let need = session.minIntervalSeconds * weight
        let gap = last.at.timeIntervalSince(previous.at)
        let since = now.timeIntervalSince(last.at)
        guard gap < need, since < need else { return (false, 0) }
        return (true, max(1, Int(ceil((need - since) / 60))))
    }

    private static func copy(
        cue: Cue,
        session: Session,
        units: Double,
        elapsed: TimeInterval,
        waitMinutes: Int
    ) -> (title: String, message: String) {
        let n = Format.units(units)
        let unitsDue = units >= Double(session.softLimit) - 0.0001
        let unitsOver = units >= Double(session.hardLimit) - 0.0001
        switch cue {
        case .calm:
            return ("慢慢来", "放下手机，到点我会问你。")
        case .settle:
            return ("节奏刚好", "下一杯不急，先喝口水。")
        case .hurried:
            return ("有点快了", "上两杯离得太近。停一会儿，喝口水，大约 \(waitMinutes) 分钟。")
        case .near:
            if units >= Double(session.softLimit) * 0.75 {
                return ("快到线了", "约 \(n) 杯，你的线是 \(session.softLimit)。这杯就当最后一杯。")
            }
            return ("快到时间了", "预定时间过了大半，可以开始收尾。")
        case .due:
            if unitsDue {
                return ("可以收了", "约 \(n) 杯，到你定的 \(session.softLimit) 杯了。")
            }
            return ("时间到了", "预定的 \(Format.minutes(session.plannedMinutes))到了。现在停，刚刚好。")
        case .over:
            if unitsOver {
                return ("该停了", "约 \(n) 杯，超过你定的上限 \(session.hardLimit)。提醒会越来越密，直到你收杯。")
            }
            let over = max(0, Int(elapsed - session.plannedSeconds) / 60)
            return ("该停了", "已经超出预定 \(over) 分钟。提醒会越来越密，直到你收杯。")
        }
    }
}

// MARK: - 模型

/// 提醒强度，从安静到强硬共五级。
enum Intensity: Int, Codable, Comparable, CaseIterable {
    case quiet = 0
    case steady
    case near
    case due
    case over

    static func < (lhs: Intensity, rhs: Intensity) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .quiet: "轻声"
        case .steady: "留意"
        case .near: "收尾"
        case .due: "到线"
        case .over: "强提醒"
        }
    }
}

enum Cue: String, Codable, Equatable {
    case calm
    case settle
    case hurried
    case near
    case due
    case over
}

enum PromptReply: String, Codable, Equatable {
    /// 在通知上确认喝了一杯。
    case drank
    /// 确认这段时间没喝。
    case skipped
    /// 用户自己手动记了一杯，这条提醒被那一杯覆盖。
    case logged
}

/// 一次主动提醒。没回应且已经过去的提醒按 `estimate` 计入估算杯数。
struct Prompt: Codable, Identifiable, Equatable {
    var id: UUID
    var at: Date
    var level: Intensity
    var estimate: Double
    var projectedUnits: Double
    var reply: PromptReply?
    var drinkID: UUID?
}

struct PaceSnapshot: Equatable {
    var cue: Cue
    var intensity: Intensity
    var title: String
    var message: String
    var units: Double
    var confirmedUnits: Double
    var estimatedUnits: Double
    var drinkCount: Int
    var waterCount: Int
    var elapsed: TimeInterval
    var planned: TimeInterval
    var isTooFast: Bool
    var waitMinutes: Int
    var sinceLastDrink: TimeInterval?
    var nextPrompt: Prompt?
    var pendingPrompt: Prompt?
    var softLimit: Int
    var hardLimit: Int
}

struct DrinkPreset: Identifiable, Equatable {
    var id: String
    var name: String
    var detail: String
    var grams: Double

    var standardDrinks: Double { grams / Pace.gramsPerStandard }

    static func custom(name: String, volumeMl: Double, abv: Double) -> DrinkPreset {
        let grams = volumeMl * (abv / 100.0) * 0.8
        let detail = "\(Int(volumeMl)) ml · \(String(format: "%.1f", abv))%"
        let safeName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return DrinkPreset(
            id: "custom_\(UUID().uuidString.prefix(6))",
            name: safeName.isEmpty ? "自选酒饮" : safeName,
            detail: detail,
            grams: grams
        )
    }
}

struct DrinkLog: Codable, Identifiable, Equatable {
    var id: UUID
    var presetID: String
    var name: String
    var detail: String
    var grams: Double
    var at: Date

    var preset: DrinkPreset {
        DrinkPreset(id: presetID, name: name, detail: detail, grams: grams)
    }
}

struct WaterLog: Codable, Identifiable, Equatable {
    var id: UUID
    var at: Date
}

struct Session: Codable, Identifiable, Equatable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var planName: String = "自定义"
    var plannedMinutes: Int
    var softLimit: Int
    var hardLimit: Int
    var minIntervalMinutes: Int
    var estimateWhenSilent: Bool = true
    var drinks: [DrinkLog]
    var waters: [WaterLog]
    var prompts: [Prompt] = []
    var lastAnnouncedRank: Int
    var lastAnnouncedCue: Cue? = nil

    enum CodingKeys: String, CodingKey {
        case id, startedAt, endedAt, planName, plannedMinutes, softLimit, hardLimit
        case minIntervalMinutes, estimateWhenSilent, drinks, waters, prompts
        case lastAnnouncedRank, lastAnnouncedCue
    }

    var plannedSeconds: TimeInterval { TimeInterval(max(plannedMinutes, 1) * 60) }
    var minIntervalSeconds: TimeInterval { TimeInterval(max(minIntervalMinutes, 1) * 60) }

    var alcoholGrams: Double { drinks.reduce(0) { $0 + $1.grams } }
    var standardDrinks: Double { alcoholGrams / Pace.gramsPerStandard }

    func confirmedUnits(at time: Date) -> Double {
        drinks.filter { $0.at <= time }.reduce(0) { $0 + $1.grams } / Pace.gramsPerStandard
    }

    func estimatedUnits(at time: Date) -> Double {
        prompts.filter { $0.reply == nil && $0.at <= time }.reduce(0) { $0 + $1.estimate }
    }

    func units(at time: Date) -> Double {
        confirmedUnits(at: time) + estimatedUnits(at: time)
    }

    var duration: TimeInterval {
        let end = endedAt ?? Date()
        return max(0, end.timeIntervalSince(startedAt))
    }

    /// 只按杯量判定结果。坐得久但喝得少不是失败，超时只作为附注。
    func outcome(at end: Date) -> Outcome {
        let units = units(at: end)
        if units < 0.05 {
            return .empty
        }
        if units >= Double(hardLimit) - 0.0001 {
            return .crossed
        }
        if units >= Double(softLimit) - 0.0001 {
            return .touched
        }
        return .within
    }

    /// 比预定多坐了多少分钟（没超时为 0）。
    var overtimeMinutes: Int {
        max(0, Int(duration - plannedSeconds) / 60)
    }
}

extension Session {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        planName = try c.decodeIfPresent(String.self, forKey: .planName) ?? "自定义"
        plannedMinutes = try c.decode(Int.self, forKey: .plannedMinutes)
        softLimit = try c.decode(Int.self, forKey: .softLimit)
        hardLimit = try c.decode(Int.self, forKey: .hardLimit)
        minIntervalMinutes = try c.decode(Int.self, forKey: .minIntervalMinutes)
        // 旧版本没有估算，按「不估算」读回来，避免历史记录凭空多出杯数。
        estimateWhenSilent = try c.decodeIfPresent(Bool.self, forKey: .estimateWhenSilent) ?? false
        drinks = try c.decodeIfPresent([DrinkLog].self, forKey: .drinks) ?? []
        waters = try c.decodeIfPresent([WaterLog].self, forKey: .waters) ?? []
        prompts = try c.decodeIfPresent([Prompt].self, forKey: .prompts) ?? []
        lastAnnouncedRank = try c.decodeIfPresent(Int.self, forKey: .lastAnnouncedRank) ?? 0
        lastAnnouncedCue = try c.decodeIfPresent(Cue.self, forKey: .lastAnnouncedCue)
    }
}

enum Outcome: Equatable {
    case within
    case touched
    case crossed
    case empty

    var title: String {
        switch self {
        case .within: "收在线内"
        case .touched: "到线就收"
        case .crossed: "越过线了"
        case .empty: "滴酒未沾"
        }
    }

    var detail: String {
        switch self {
        case .within:
            "这场停在你自己的线前面。"
        case .touched:
            "刚好到线。能停下来就很好。"
        case .crossed:
            "这场越过线了。下次可以把线定低一点，或者早点开始收尾。"
        case .empty:
            "这场没有喝酒，清爽收场。"
        }
    }
}

struct Plan: Equatable, Identifiable {
    var id: String
    var name: String
    var plannedMinutes: Int
    var softLimit: Int
    var hardLimit: Int
    var minIntervalMinutes: Int

    var detail: String {
        "\(softLimit) 标准杯 · \(Format.minutes(plannedMinutes))"
    }

    static let light = Plan(
        id: "light",
        name: "小酌",
        plannedMinutes: 90,
        softLimit: 2,
        hardLimit: 3,
        minIntervalMinutes: 40
    )

    static let dinner = Plan(
        id: "dinner",
        name: "聚餐",
        plannedMinutes: 180,
        softLimit: 4,
        hardLimit: 6,
        minIntervalMinutes: 25
    )
}

struct Settings: Codable, Equatable {
    var plannedMinutes: Int = 120
    var softLimit: Int = 3
    var hardLimit: Int = 5
    var minIntervalMinutes: Int = 30
    var keepScreenOn: Bool = false
    var estimateWhenSilent: Bool = true
    var selectedPlanID: String = Plan.light.id

    mutating func normalize() {
        plannedMinutes = min(360, max(30, plannedMinutes))
        softLimit = min(12, max(1, softLimit))
        hardLimit = min(16, max(softLimit, hardLimit))
        minIntervalMinutes = min(90, max(10, minIntervalMinutes))
        if ![Plan.light.id, Plan.dinner.id, "custom"].contains(selectedPlanID) {
            selectedPlanID = Plan.light.id
        }
    }

    var customPlan: Plan {
        Plan(
            id: "custom",
            name: "自定义",
            plannedMinutes: plannedMinutes,
            softLimit: softLimit,
            hardLimit: hardLimit,
            minIntervalMinutes: minIntervalMinutes
        )
    }

    var selectedPlan: Plan {
        switch selectedPlanID {
        case Plan.dinner.id: .dinner
        case "custom": customPlan
        default: .light
        }
    }
}

extension Settings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = Settings()
        plannedMinutes = try c.decodeIfPresent(Int.self, forKey: .plannedMinutes) ?? base.plannedMinutes
        softLimit = try c.decodeIfPresent(Int.self, forKey: .softLimit) ?? base.softLimit
        hardLimit = try c.decodeIfPresent(Int.self, forKey: .hardLimit) ?? base.hardLimit
        minIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .minIntervalMinutes) ?? base.minIntervalMinutes
        keepScreenOn = try c.decodeIfPresent(Bool.self, forKey: .keepScreenOn) ?? base.keepScreenOn
        estimateWhenSilent = try c.decodeIfPresent(Bool.self, forKey: .estimateWhenSilent) ?? base.estimateWhenSilent
        selectedPlanID = try c.decodeIfPresent(String.self, forKey: .selectedPlanID) ?? base.selectedPlanID
    }
}

enum Format {
    static func units(_ value: Double) -> String {
        let tenths = (value * 10).rounded() / 10
        if abs(tenths - tenths.rounded()) < 0.001 {
            return String(Int(tenths.rounded()))
        }
        return String(format: "%.1f", tenths)
    }

    static func minutes(_ minutes: Int) -> String {
        if minutes % 60 == 0 {
            return "\(minutes / 60) 小时"
        }
        if minutes > 60 {
            let hours = minutes / 60
            let rest = minutes % 60
            return "\(hours) 小时 \(rest) 分"
        }
        return "\(minutes) 分钟"
    }

    /// 1:12 这样的短时长。
    static func hm(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval)) / 60
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func shortTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Locale(identifier: "zh_CN")))
    }

    static func day(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        }
        if calendar.isDateInYesterday(date) {
            return "昨天"
        }
        return date.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))
    }

    static func until(_ date: Date, now: Date) -> String {
        let minutes = max(1, Int(ceil(date.timeIntervalSince(now) / 60)))
        if minutes < 60 {
            return "\(minutes) 分钟后"
        }
        let hours = minutes / 60
        let rest = minutes % 60
        if rest == 0 {
            return "\(hours) 小时后"
        }
        return "\(hours) 小时 \(rest) 分后"
    }
}

#if PACE_CHECKS
enum PaceChecks {
    static func run() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        let calm = Pace.evaluate(make(start: start), now: start.addingTimeInterval(60))
        check(calm.cue == .calm, "刚开始应该是 calm，实际 \(calm.cue)")

        let oneBeer = Pace.evaluate(
            make(start: start, soft: 3, hard: 5, drinks: [drink("beer330", at: start.addingTimeInterval(60))]),
            now: start.addingTimeInterval(5 * 60)
        )
        check(oneBeer.cue == .settle, "一小瓶啤酒离 3 标准杯还远，应是 settle，实际 \(oneBeer.cue)")

        let fast = Pace.evaluate(
            make(start: start, soft: 6, hard: 8, interval: 30, drinks: [
                drink("beer500", at: start.addingTimeInterval(10 * 60)),
                drink("beer500", at: start.addingTimeInterval(20 * 60)),
            ]),
            now: start.addingTimeInterval(25 * 60)
        )
        check(fast.cue == .hurried, "两杯只隔 10 分钟应该是 hurried，实际 \(fast.cue)")

        let fastRecovered = Pace.evaluate(
            make(start: start, soft: 6, hard: 8, interval: 30, drinks: [
                drink("beer500", at: start),
                drink("beer500", at: start.addingTimeInterval(10 * 60)),
            ]),
            now: start.addingTimeInterval(60 * 60)
        )
        check(fastRecovered.cue != .hurried, "间隔已经过去，不应继续算喝太快")

        // 白酒更烈，同样 35 分钟的间隔仍然算快；啤酒 330 就不算。
        let baijiuGap = Pace.evaluate(
            make(start: start, soft: 6, hard: 8, interval: 30, drinks: [
                drink("baijiu", at: start),
                drink("beer330", at: start.addingTimeInterval(35 * 60)),
            ]),
            now: start.addingTimeInterval(36 * 60)
        )
        check(baijiuGap.isTooFast, "一两白酒后 35 分钟就续，应按加权间隔算快")
        let beerGap = Pace.evaluate(
            make(start: start, soft: 6, hard: 8, interval: 30, drinks: [
                drink("beer330", at: start),
                drink("beer330", at: start.addingTimeInterval(35 * 60)),
            ]),
            now: start.addingTimeInterval(36 * 60)
        )
        check(!beerGap.isTooFast, "啤酒 330 后 35 分钟不算快")

        let due = Pace.evaluate(
            make(start: start, soft: 2, hard: 4, drinks: [drink("baijiu", at: start), drink("baijiu", at: start.addingTimeInterval(40 * 60))]),
            now: start.addingTimeInterval(45 * 60)
        )
        check(due.cue == .due, "两杯白酒应到线，实际 \(due.cue)")

        let over = Pace.evaluate(
            make(start: start, soft: 2, hard: 3, drinks: [
                drink("baijiu", at: start),
                drink("baijiu", at: start.addingTimeInterval(40 * 60)),
                drink("baijiu", at: start.addingTimeInterval(80 * 60)),
            ]),
            now: start.addingTimeInterval(81 * 60)
        )
        check(over.cue == .over, "三杯白酒应越过上限")

        check(Pace.evaluate(make(start: start, minutes: 90), now: start.addingTimeInterval(90 * 60)).cue == .due, "到点应提醒收杯")
        check(Pace.evaluate(make(start: start, minutes: 90), now: start.addingTimeInterval(121 * 60)).cue == .over, "超时半小时应升到 over")

        // 结果只看杯量：坐了很久但只喝一小瓶，不算越线。
        var longSit = make(start: start, minutes: 90, soft: 3, hard: 5, drinks: [drink("beer330", at: start)])
        longSit.endedAt = start.addingTimeInterval(200 * 60)
        check(longSit.outcome(at: longSit.endedAt!) == .within, "超时但喝得少应是 within")
        check(longSit.overtimeMinutes == 110, "超时分钟应为 110，实际 \(longSit.overtimeMinutes)")

        // 提醒时间表：越往后越密，且最终升到强提醒。
        let fresh = make(start: start, minutes: 90, soft: 2, hard: 3, interval: 40, estimate: true)
        let plan = Pace.projectPrompts(fresh, now: start.addingTimeInterval(30))
        check(!plan.isEmpty, "应排出提醒")
        check(plan.count <= Pace.promptBudget, "不能超过提醒上限")
        check(plan[0].at.timeIntervalSince(start) <= 20 * 60 + 1, "第一条提醒应在 20 分钟内")
        var lastAt = start
        for prompt in plan {
            let gap = prompt.at.timeIntervalSince(lastAt)
            check(gap > 0, "提醒时间必须递增")
            lastAt = prompt.at
        }
        check(Set(plan.map(\.level)) == Set(Intensity.allCases), "五级提醒都应出现，实际 \(Set(plan.map(\.level)))")
        let overGaps = zip(plan, plan.dropFirst()).filter { $0.0.level == .over }.map { $0.1.at.timeIntervalSince($0.0.at) }
        check(overGaps.allSatisfy { $0 <= 4 * 60 + 1 }, "强提醒应每 4 分钟一次")
        check(plan.map(\.level).last == .over, "一直不回应应升到强提醒")
        check(zip(plan, plan.dropFirst()).allSatisfy { $0.level <= $1.level }, "强度只升不降")

        // 不估算时，杯数只来自确认。
        let noEstimate = make(start: start, estimate: false)
        check(Pace.projectPrompts(noEstimate, now: start).allSatisfy { $0.estimate == 0 }, "关闭估算时不应估杯")

        // 过去的未回应提醒计入估算；回应「没喝」后不再计入。
        var estimated = fresh
        estimated.prompts = Pace.projectPrompts(estimated, now: start)
        let afterFirst = estimated.prompts[0].at.addingTimeInterval(1)
        check(estimated.estimatedUnits(at: afterFirst) > 0, "未回应的提醒应计入估算")
        estimated.prompts[0].reply = .skipped
        check(estimated.estimatedUnits(at: afterFirst) == 0, "回应没喝后不应计入")

        // 重排确定性：同样记录重排两次，时间一致。
        let a = Pace.projectPrompts(fresh, now: start.addingTimeInterval(120)).map(\.at)
        let b = Pace.projectPrompts(fresh, now: start.addingTimeInterval(180)).map(\.at)
        check(a.prefix(5) == b.prefix(5), "重排不应把提醒往后推")

        let customPreset = DrinkPreset.custom(name: "精酿IPA", volumeMl: 500, abv: 7.0)
        check(abs(customPreset.grams - 28.0) < 0.01, "500ml 7% 精酿酒精克数应约为 28g")

        check(make(start: start).outcome(at: start.addingTimeInterval(600)) == .empty, "空场次结算应为 empty")
        print("PaceChecks OK · 提醒 \(plan.count) 条 · 间隔(分) \(plan.prefix(12).map { Int($0.at.timeIntervalSince(start) / 60) })")
    }

    private static func make(
        start: Date,
        minutes: Int = 90,
        soft: Int = 2,
        hard: Int = 3,
        interval: Int = 30,
        estimate: Bool = false,
        drinks: [DrinkLog] = []
    ) -> Session {
        Session(
            id: UUID(),
            startedAt: start,
            endedAt: nil,
            plannedMinutes: minutes,
            softLimit: soft,
            hardLimit: hard,
            minIntervalMinutes: interval,
            estimateWhenSilent: estimate,
            drinks: drinks,
            waters: [],
            lastAnnouncedRank: 0
        )
    }

    private static func drink(_ id: String, at: Date) -> DrinkLog {
        guard let preset = Pace.presets.first(where: { $0.id == id }) else {
            fputs("缺少酒类 \(id)\n", stderr)
            exit(1)
        }
        return DrinkLog(id: UUID(), presetID: preset.id, name: preset.name, detail: preset.detail, grams: preset.grams, at: at)
    }

    private static func check(_ condition: Bool, _ message: String) {
        if !condition {
            fputs("FAIL \(message)\n", stderr)
            exit(1)
        }
    }

    static let _autoRun: Void = {
        run()
    }()
}

let _ = PaceChecks._autoRun
#endif
