import Foundation

/// 一杯「标准杯」按大约 14 克乙醇估算，只用来比较这一场的量。
/// 不是血液酒精浓度，也不能用来判断能不能开车。
enum Pace {
    static let gramsPerStandard = 14.0

    static let presets: [DrinkPreset] = [
        DrinkPreset(id: "beer330", name: "啤酒", detail: "330 ml", grams: 12),
        DrinkPreset(id: "beer500", name: "啤酒", detail: "500 ml", grams: 18),
        DrinkPreset(id: "wine", name: "红酒", detail: "150 ml", grams: 15),
        DrinkPreset(id: "huangjiu", name: "黄酒", detail: "100 ml", grams: 12),
        DrinkPreset(id: "baijiu", name: "白酒", detail: "一两 · 50 ml", grams: 21),
        DrinkPreset(id: "cocktail", name: "鸡尾酒", detail: "一杯", grams: 18),
    ]

    /// 提醒分六档，数值越大越该停。同时命中多条线时取更高的一档。
    /// 标准杯、两杯间隔、预定结束时间互相独立，任何一条到了都会升档。
    static func evaluate(_ session: Session, now: Date) -> PaceSnapshot {
        let elapsed = max(0, now.timeIntervalSince(session.startedAt))
        let planned = TimeInterval(session.plannedMinutes * 60)
        let minGap = TimeInterval(session.minIntervalMinutes * 60)
        let units = session.standardDrinks
        let soft = Double(session.softLimit)
        let hard = Double(session.hardLimit)

        let tooFast = isTooFast(session, now: now, minGap: minGap)
        let waitMinutes = waitMinutes(session, now: now, minGap: minGap, tooFast: tooFast)

        let lastDrink = session.drinks.max(by: { $0.at < $1.at })
        let cooldownRemaining: TimeInterval
        if let lastDrink {
            let nextSafe = lastDrink.at.addingTimeInterval(minGap)
            cooldownRemaining = max(0, nextSafe.timeIntervalSince(now))
        } else {
            cooldownRemaining = 0
        }

        let gramOver = units >= hard
        let timeOver = elapsed >= planned + 30 * 60
        let gramDue = units >= soft
        let timeDue = elapsed >= planned
        let gramNear = units >= soft * 0.7 && units < soft
        let timeNear = elapsed >= planned * 0.75 && elapsed < planned
        let settle = elapsed >= 20 * 60 || !session.drinks.isEmpty

        let cue: Cue
        if gramOver || timeOver {
            cue = .over
        } else if gramDue || timeDue {
            cue = .due
        } else if tooFast {
            cue = .hurried
        } else if gramNear || timeNear {
            cue = .near
        } else if settle {
            cue = .settle
        } else {
            cue = .calm
        }

        let copy = copy(
            cue: cue,
            session: session,
            units: units,
            tooFast: tooFast,
            waitMinutes: waitMinutes,
            gramNear: gramNear,
            timeNear: timeNear,
            gramDue: gramDue,
            timeDue: timeDue,
            gramOver: gramOver,
            timeOver: timeOver
        )

        return PaceSnapshot(
            cue: cue,
            rank: cue.rank,
            title: copy.title,
            message: copy.message,
            standardDrinks: units,
            drinkCount: session.drinks.count,
            waterCount: session.waters.count,
            elapsed: elapsed,
            planned: planned,
            isTooFast: tooFast,
            waitMinutes: waitMinutes,
            cooldownRemaining: cooldownRemaining,
            softLimit: session.softLimit,
            hardLimit: session.hardLimit
        )
    }

    /// 锁屏后仍要响的提醒。只排未来的，最多由调用方再截断。
    static func plannedCues(session: Session, now: Date) -> [PlannedCue] {
        let start = session.startedAt
        let planned = TimeInterval(session.plannedMinutes * 60)
        let planEnd = start.addingTimeInterval(planned)
        let interval = TimeInterval(session.minIntervalMinutes * 60)
        let units = session.standardDrinks
        var cues: [PlannedCue] = []

        func add(_ id: String, _ at: Date, _ title: String, _ body: String) {
            guard at.timeIntervalSince(now) >= 5 else { return }
            cues.append(PlannedCue(id: id, at: at, title: title, body: body))
        }

        if session.drinks.isEmpty {
            add(
                "log",
                start.addingTimeInterval(20 * 60),
                "记上一杯",
                "开喝二十分钟了。喝了的话记一杯，我才算得准。"
            )
        }

        if units < Double(session.softLimit), let last = session.drinks.last {
            add(
                "interval",
                last.at.addingTimeInterval(interval),
                "间隔到了",
                "你给自己留的 \(session.minIntervalMinutes) 分钟到了。这不是叫你续杯，是问你要不要停在这里。"
            )
        }

        add(
            "near-time",
            start.addingTimeInterval(planned * 0.75),
            "快到你定的时间",
            "预定时间过去四分之三了。可以开始收杯。"
        )
        add(
            "due-time",
            planEnd,
            "时间到了",
            "这场预定的 \(Format.minutes(session.plannedMinutes))结束了。"
        )
        add(
            "over-time",
            planEnd.addingTimeInterval(30 * 60),
            "超时了",
            "已经超出预定半小时。现在停比较好。"
        )

        if units >= Double(session.hardLimit) {
            for step in 1...6 {
                add(
                    "over-\(step)",
                    now.addingTimeInterval(TimeInterval(step) * 10 * 60),
                    "该停了",
                    "已经 \(Format.units(units)) 标准杯，超过你定的 \(session.hardLimit)。我还会再提醒。"
                )
            }
        } else if units >= Double(session.softLimit) {
            for step in 1...4 {
                add(
                    "due-\(step)",
                    now.addingTimeInterval(TimeInterval(step) * 15 * 60),
                    "可以停了",
                    "已经 \(Format.units(units)) 标准杯，你的线是 \(session.softLimit)。"
                )
            }
        }

        var seen = Set<String>()
        return cues
            .sorted { $0.at < $1.at }
            .filter { seen.insert($0.id).inserted }
    }

    private static func isTooFast(_ session: Session, now: Date, minGap: TimeInterval) -> Bool {
        guard session.drinks.count >= 2 else { return false }
        let ordered = session.drinks.sorted { $0.at < $1.at }
        guard let last = ordered.last, let previous = ordered.dropLast().last else { return false }
        let gap = last.at.timeIntervalSince(previous.at)
        let since = now.timeIntervalSince(last.at)
        return gap < minGap && since < minGap
    }

    private static func waitMinutes(_ session: Session, now: Date, minGap: TimeInterval, tooFast: Bool) -> Int {
        guard tooFast, let last = session.drinks.max(by: { $0.at < $1.at }) else { return 1 }
        let remain = minGap - now.timeIntervalSince(last.at)
        return max(1, Int(ceil(remain / 60)))
    }

    private static func copy(
        cue: Cue,
        session: Session,
        units: Double,
        tooFast: Bool,
        waitMinutes: Int,
        gramNear: Bool,
        timeNear: Bool,
        gramDue: Bool,
        timeDue: Bool,
        gramOver: Bool,
        timeOver: Bool
    ) -> (title: String, message: String) {
        let pace = tooFast ? "上两杯隔得太近，先再等 \(waitMinutes) 分钟。" : ""
        switch cue {
        case .calm:
            return ("慢慢喝", "这场刚开始。喝下第一口时记一杯，我按你的线来提醒。")
        case .settle:
            if session.drinks.isEmpty {
                return ("记上一杯", "开喝有一会儿了。喝了的话记一杯，我才算得准。")
            }
            return ("先别急着续", "现在是 \(Format.units(units)) 标准杯。下一杯不用那么快，先喝点水。")
        case .hurried:
            return ("喝得有点快", "上两杯隔得太近。先停大约 \(waitMinutes) 分钟，喝口水。")
        case .near:
            let base: String
            if gramNear && timeNear {
                base = "杯量和时间都快到了。可以开始收。"
            } else if gramNear {
                base = "再喝一点就到你定的 \(session.softLimit) 标准杯。这杯可以当最后一杯。"
            } else {
                base = "预定时间过去四分之三了。开始收杯还来得及。"
            }
            return ("快到线了", pace.isEmpty ? base : base + pace)
        case .due:
            let base: String
            if gramDue && timeDue {
                base = "杯量和时间都到线了。现在是 \(Format.units(units)) 标准杯。"
            } else if gramDue {
                base = "到你定的 \(session.softLimit) 标准杯了。这杯可以是最后一杯。"
            } else {
                base = "预定的 \(Format.minutes(session.plannedMinutes))到了。还想喝的话，也先停一停。"
            }
            return ("可以停了", pace.isEmpty ? base : base + pace)
        case .over:
            let base: String
            if gramOver {
                base = "已经 \(Format.units(units)) 标准杯，超过你定的 \(session.hardLimit)。再记要按住按钮，我还会继续提醒。"
            } else if timeOver {
                base = "已经超出预定时间半小时。现在停比较好。"
            } else {
                base = "已经越过你给自己的线。现在停。"
            }
            return ("停一下", base)
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

    var rank: Int {
        switch self {
        case .calm: 0
        case .settle: 1
        case .hurried: 2
        case .near: 3
        case .due: 4
        case .over: 5
        }
    }
}

struct PaceSnapshot: Equatable {
    var cue: Cue
    var rank: Int
    var title: String
    var message: String
    var standardDrinks: Double
    var drinkCount: Int
    var waterCount: Int
    var elapsed: TimeInterval
    var planned: TimeInterval
    var isTooFast: Bool
    var waitMinutes: Int
    var cooldownRemaining: TimeInterval
    var softLimit: Int
    var hardLimit: Int
}

struct PlannedCue: Equatable {
    var id: String
    var at: Date
    var title: String
    var body: String
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
}

struct WaterLog: Codable, Identifiable, Equatable {
    var id: UUID
    var at: Date
}

struct Session: Codable, Identifiable, Equatable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var plannedMinutes: Int
    var softLimit: Int
    var hardLimit: Int
    var minIntervalMinutes: Int
    var drinks: [DrinkLog]
    var waters: [WaterLog]
    var lastAnnouncedRank: Int
    var lastAnnouncedCue: Cue? = nil

    var alcoholGrams: Double { drinks.reduce(0) { $0 + $1.grams } }
    var standardDrinks: Double { alcoholGrams / Pace.gramsPerStandard }

    var duration: TimeInterval {
        let end = endedAt ?? Date()
        return max(0, end.timeIntervalSince(startedAt))
    }

    func outcome(at end: Date) -> Outcome {
        if drinks.isEmpty {
            return .empty
        }
        switch Pace.evaluate(self, now: end).cue {
        case .over:
            return .crossed
        case .due:
            return .touched
        case .calm, .settle, .hurried, .near:
            return .within
        }
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
        case .touched: "到线才收"
        case .crossed: "越过线了"
        case .empty: "未饮酒收场"
        }
    }

    var detail: String {
        switch self {
        case .within:
            "这场停在你自己的线前面。"
        case .touched:
            "刚好到线。能停下来就很好。"
        case .crossed:
            "这场越过线了。下次可以把杯数或时间定短一点。"
        case .empty:
            "这场没有记录饮酒，清爽收杯。"
        }
    }
}

struct Plan: Equatable {
    var name: String
    var detail: String
    var plannedMinutes: Int
    var softLimit: Int
    var hardLimit: Int
    var minIntervalMinutes: Int

    static let light = Plan(
        name: "小酌",
        detail: "2 标准杯 · 90 分钟",
        plannedMinutes: 90,
        softLimit: 2,
        hardLimit: 3,
        minIntervalMinutes: 40
    )

    static let dinner = Plan(
        name: "聚餐",
        detail: "4 标准杯 · 3 小时",
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
    var keepScreenOn: Bool = true

    mutating func normalize() {
        plannedMinutes = min(360, max(30, plannedMinutes))
        softLimit = min(12, max(1, softLimit))
        hardLimit = min(16, max(softLimit, hardLimit))
        minIntervalMinutes = min(90, max(10, minIntervalMinutes))
    }

    var plan: Plan {
        Plan(
            name: "自定义",
            detail: "\(softLimit) 标准杯 · \(Format.minutes(plannedMinutes))",
            plannedMinutes: plannedMinutes,
            softLimit: softLimit,
            hardLimit: hardLimit,
            minIntervalMinutes: minIntervalMinutes
        )
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
        date.formatted(.dateTime.hour().minute().locale(Locale(identifier: "zh_CN")))
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

        let settleTime = Pace.evaluate(make(start: start), now: start.addingTimeInterval(25 * 60))
        check(settleTime.cue == .settle, "25 分钟还没记杯应该提醒补记")

        let oneBeer = Pace.evaluate(
            make(start: start, soft: 3, hard: 5, drinks: [drink("beer330", at: start.addingTimeInterval(60))]),
            now: start.addingTimeInterval(5 * 60)
        )
        check(oneBeer.cue == .settle, "一小瓶啤酒离 3 标准杯还远，不应升到 near")

        let fast = Pace.evaluate(
            make(
                start: start,
                soft: 6,
                hard: 8,
                interval: 30,
                drinks: [
                    drink("beer500", at: start.addingTimeInterval(10 * 60)),
                    drink("beer500", at: start.addingTimeInterval(20 * 60)),
                ]
            ),
            now: start.addingTimeInterval(25 * 60)
        )
        check(fast.cue == .hurried, "两杯只隔 10 分钟应该是 hurried，实际 \(fast.cue)")

        let fastRecovered = Pace.evaluate(
            make(
                start: start,
                soft: 6,
                hard: 8,
                interval: 30,
                drinks: [
                    drink("beer500", at: start),
                    drink("beer500", at: start.addingTimeInterval(10 * 60)),
                ]
            ),
            now: start.addingTimeInterval(50 * 60)
        )
        check(fastRecovered.cue != .hurried, "间隔已经过去，不应继续算喝太快")

        let baijiuNear = Pace.evaluate(
            make(start: start, soft: 2, hard: 3, drinks: [drink("baijiu", at: start)]),
            now: start.addingTimeInterval(2 * 60)
        )
        check(baijiuNear.cue == .near, "一两白酒应接近 2 标准杯的线，实际 \(baijiuNear.cue)")

        let due = Pace.evaluate(
            make(start: start, soft: 2, hard: 4, drinks: [drink("baijiu", at: start), drink("baijiu", at: start.addingTimeInterval(40 * 60))]),
            now: start.addingTimeInterval(45 * 60)
        )
        check(due.cue == .due, "两杯白酒应到线，实际 \(due.cue) units \(due.standardDrinks)")

        let over = Pace.evaluate(
            make(
                start: start,
                soft: 2,
                hard: 3,
                drinks: [
                    drink("baijiu", at: start),
                    drink("baijiu", at: start.addingTimeInterval(40 * 60)),
                    drink("baijiu", at: start.addingTimeInterval(80 * 60)),
                ]
            ),
            now: start.addingTimeInterval(81 * 60)
        )
        check(over.cue == .over, "三杯白酒应越过硬线")

        let timeDue = Pace.evaluate(make(start: start, minutes: 90), now: start.addingTimeInterval(90 * 60))
        check(timeDue.cue == .due, "到点即使没喝酒也该提醒收杯")

        let timeOver = Pace.evaluate(make(start: start, minutes: 90), now: start.addingTimeInterval(121 * 60))
        check(timeOver.cue == .over, "超时半小时应升到 over")

        let future = Pace.plannedCues(session: make(start: start), now: start.addingTimeInterval(60))
        check(future.allSatisfy { $0.at.timeIntervalSince(start.addingTimeInterval(60)) >= 5 }, "不应安排已经过去的提醒")
        check(Set(future.map(\.id)).count == future.count, "提醒 id 重复")
        check(future.contains { $0.id == "log" }, "还没记杯时应安排补记提醒")

        let logged = Pace.plannedCues(
            session: make(start: start, drinks: [drink("beer330", at: start)]),
            now: start.addingTimeInterval(60)
        )
        check(!logged.contains { $0.id == "log" }, "已经记杯就不必再催补记")

        let customPreset = DrinkPreset.custom(name: "精酿IPA", volumeMl: 500, abv: 7.0)
        check(abs(customPreset.grams - 28.0) < 0.01, "500ml 7% 精酿酒精克数应约为 28g")
        check(abs(customPreset.standardDrinks - 2.0) < 0.01, "28g 应折算为 2.0 标准杯")

        let emptySession = make(start: start)
        check(emptySession.outcome(at: start.addingTimeInterval(10 * 60)) == .empty, "空会话结算应为 empty")
    }

    private static func make(
        start: Date,
        minutes: Int = 90,
        soft: Int = 2,
        hard: Int = 3,
        interval: Int = 30,
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
}
#endif
