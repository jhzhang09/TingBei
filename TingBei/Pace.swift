import Foundation

/// 一杯「标准杯」按大约 14 克乙醇估算，只用来比较这一场的量。
/// 不是血液酒精浓度，也不能用来判断能不能开车。
enum Pace {
    static let gramsPerStandard = 14.0

    /// 在通知上点了「喝了一杯」但不知道具体喝了什么时，按一个标准杯记。
    static let genericDrink = DrinkPreset(id: "generic", name: "一杯", detail: "按 1 标准杯", grams: 14)

    /// 未来最多预排多少条提醒（系统上限 64 条，留出余量设为 60 条，在 10 分钟越线期可覆盖长达 10 小时）。
    static let promptBudget = 60

    static let presets: [DrinkPreset] = [
        DrinkPreset(id: "beer500", name: "啤酒", detail: "500 ml", grams: 18),
        DrinkPreset(id: "beer330", name: "啤酒", detail: "330 ml", grams: 12),
        DrinkPreset(id: "baijiu", name: "白酒", detail: "一两 · 50 ml", grams: 21),
        DrinkPreset(id: "wine", name: "红酒", detail: "150 ml", grams: 15),
        DrinkPreset(id: "huangjiu", name: "黄酒", detail: "100 ml", grams: 12),
        DrinkPreset(id: "cocktail", name: "鸡尾酒", detail: "一杯", grams: 18),
    ]

    // MARK: - 提醒强度阶梯

    /// 当前该用哪一级提醒。杯数和时间任何一条先到都会升级，只升不降（除非用户纠正了杯数）。
    static func intensity(units: Double, elapsed: TimeInterval, session: Session) -> Intensity {
        let planned = session.plannedSeconds
        let soft = max(session.softLimit, 1.0)
        let hard = max(session.hardLimit, session.softLimit)
        let epsilon = 0.0001
        if units >= hard - epsilon || elapsed >= planned + 30 * 60 {
            return .over
        }
        if units >= soft - epsilon || elapsed >= planned {
            return .due
        }
        let pressure = max(units / soft, elapsed / planned)
        if pressure >= 0.70 {
            return .near
        }
        if pressure >= 0.35 {
            return .steady
        }
        return .quiet
    }

    /// 每一级提醒之间隔多久。
    /// 严格遵循等差反推算法：第一次通知 30 分钟，最后最频繁通知 10 分钟。
    /// 30m ➔ 25m ➔ 20m ➔ 15m ➔ 10m (持续循环)
    static func gap(for intensity: Intensity, session: Session) -> TimeInterval {
        switch intensity {
        case .quiet:
            return 30 * 60   // 初始探索：30 分钟
        case .steady:
            return 25 * 60   // 稳步巡航：25 分钟
        case .near:
            return 20 * 60   // 逼近建议线：20 分钟
        case .due:
            return 15 * 60   // 到达建议线：15 分钟
        case .over:
            return 10 * 60   // 越线/超限：10 分钟（终极最高频，持续循环直到收杯）
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
                if let lastDrink, lastDrink.at >= prompt.at { return nil }
                return prompt
            }
        let next = session.prompts
            .filter { $0.reply == nil && $0.at > now }
            .min(by: { $0.at < $1.at })

        let category = session.beverageCategory
        let physicalText = category.formatPhysical(from: units)

        let copy = copy(
            cue: cue,
            session: session,
            units: units,
            elapsed: elapsed,
            waitMinutes: fast.waitMinutes
        )

        // 诗意微醺状态铭牌（用于表盘顶部艺术字）
        let poeticPhase: String
        switch cue {
        case .calm:
            poeticPhase = "初 酌 · 从 容"
        case .settle:
            poeticPhase = "微 醺 · 适 意"
        case .hurried:
            poeticPhase = "湍 急 · 宜 缓"
        case .near:
            poeticPhase = "尽 兴 · 临 线"
        case .due:
            poeticPhase = "盈 满 · 当 止"
        case .over:
            poeticPhase = "越 界 · 停 杯"
        }

        return PaceSnapshot(
            cue: cue,
            intensity: level,
            poeticPhase: poeticPhase,
            title: copy.title,
            message: copy.message,
            units: units,
            confirmedUnits: confirmed,
            estimatedUnits: estimated,
            physicalText: physicalText,
            category: category,
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

    // MARK: - 预排提醒（等差反推算法）

    /// 从现在起往后推算提醒时间表。
    /// 遵循：30m -> 25m -> 20m -> 15m -> 10m（越线后恒定 10m，直到收杯）。
    static func projectPrompts(_ session: Session, now: Date) -> [Prompt] {
        guard session.endedAt == nil else { return [] }
        let start = session.startedAt
        let category = session.beverageCategory

        let pastPrompts = session.prompts.filter { $0.at <= now }
        let lastDrinkAt = session.drinks.map(\.at).filter { $0 <= now }.max()
        var anchor = max(start, lastDrinkAt ?? start, pastPrompts.map(\.at).max() ?? start)
        var units = session.confirmedUnits(at: now) + session.estimatedUnits(at: now)

        var result: [Prompt] = []
        var stepIndex = pastPrompts.count
        var overCounter = 0

        // 持续推算，不自动收杯，直到填满预算（60 条，可覆盖 10 小时以上）
        while result.count < promptBudget {
            let elapsedFromStart = anchor.timeIntervalSince(start)
            let current = intensity(units: units, elapsed: elapsedFromStart, session: session)
            let wait = gap(for: current, session: session)
            var at = anchor.addingTimeInterval(wait)

            if at < now.addingTimeInterval(30) {
                at = now.addingTimeInterval(30)
            }

            stepIndex += 1

            // 估算增长：不再碎成零头，而是按阶段平滑增加
            let stepEstimate: Double
            if session.estimateWhenSilent {
                if current == .over {
                    stepEstimate = 0.2 // 越线后小幅度渐增
                } else {
                    stepEstimate = session.softLimit / 4.0 // 4个常规节拍均匀分布
                }
            } else {
                stepEstimate = 0
            }

            units += stepEstimate
            let level = intensity(units: units, elapsed: at.timeIntervalSince(start), session: session)

            if level == .over {
                overCounter += 1
            }

            let semantic: String = makeSemanticText(
                level: level,
                stepIndex: stepIndex,
                category: category,
                projectedUnits: units,
                overCounter: overCounter
            )

            result.append(
                Prompt(
                    id: UUID(),
                    at: at,
                    level: level,
                    estimate: stepEstimate,
                    projectedUnits: units,
                    semanticText: semantic,
                    reply: nil,
                    drinkID: nil
                )
            )
            anchor = at
        }
        return result
    }

    private static func makeSemanticText(
        level: Intensity,
        stepIndex: Int,
        category: BeverageCategory,
        projectedUnits: Double,
        overCounter: Int
    ) -> String {
        switch level {
        case .quiet:
            return "节奏推测 · 约第 1 \(category.unitName)"
        case .steady:
            let approxVal = max(1, Int(round(category.physicalValue(from: projectedUnits))))
            return "节奏推测 · 约第 \(approxVal) \(category.unitName)"
        case .near:
            return "节奏推测 · 逼近建议线 · \(category.formatPhysical(from: projectedUnits))"
        case .due:
            return "到线提醒 · 建议停杯 · \(category.formatPhysical(from: projectedUnits))"
        case .over:
            return "越线强提醒 · 第 \(max(1, overCounter)) 次"
        }
    }

    /// 通知文案。越往后越直接。结合当前酒种说人话。
    static func notificationCopy(for prompt: Prompt, session: Session, ordinal: Int) -> (title: String, body: String) {
        let cat = session.beverageCategory
        let physicalDesc = cat.formatPhysical(from: prompt.projectedUnits)
        let soft = session.softLimit
        let hard = session.hardLimit
        let softPhysical = cat.formatPhysical(from: soft)
        let hardPhysical = cat.formatPhysical(from: hard)

        switch prompt.level {
        case .quiet:
            switch cat {
            case .baijiu:
                return ("开喝半小时了", "第一小盅大概抿得差不多了？白酒后劲大，下一盅先不急，多喝两口温水。")
            case .beer:
                return ("开喝半小时了", "第一听啤酒大概差不多了？下一听慢点开，先喝口水润润。")
            case .wine:
                return ("开喝半小时了", "第一杯红酒慢慢品。下一杯不急，先喝口水。")
            case .custom:
                return ("开喝半小时了", "大概第 1 标准杯了？放下手机，多喝水，到点我会继续问你。")
            }
        case .steady:
            switch cat {
            case .baijiu:
                return ("喝了约 \(physicalDesc)", "节奏还挺稳。白酒易上头，中途多吃两口菜，喝点水。")
            case .beer:
                return ("喝了约 \(physicalDesc)", "节奏刚好。下一听放慢点，中间多喝水。")
            default:
                return ("约 \(physicalDesc) 了", "节奏还行。下一杯慢一点，先喝口水。")
            }
        case .near:
            return ("快到建议线了", "累计约 \(physicalDesc)，建议线是 \(softPhysical)。这杯喝完就可以开始收尾了。")
        case .due:
            return ("到线了，收吧", "已到你定的建议线 \(softPhysical)。现在停杯，明天清醒舒服。")
        case .over:
            let tail = "每 10 分钟提醒一次，直到你点「我收杯了」。"
            return ("停。第 \(ordinal) 次越线提醒", "累计约 \(physicalDesc)，已超上限 \(hardPhysical)。现在停下！\(tail)")
        }
    }

    // MARK: - 私有

    private static func tooFast(_ session: Session, now: Date) -> (isTooFast: Bool, waitMinutes: Int) {
        let ordered = session.drinks.filter { $0.at <= now }.sorted { $0.at < $1.at }
        guard ordered.count >= 2 else { return (false, 0) }
        let last = ordered[ordered.count - 1]
        let previous = ordered[ordered.count - 2]
        let weight = min(2, max(0.5, previous.grams / gramsPerStandard))
        var need = session.minIntervalSeconds * weight
        // 真实代谢缓冲闭环：在上一杯之后每喝一杯水，折抵 5 分钟急饮冷却等待
        let recentWaters = session.waters.filter { $0.at >= previous.at && $0.at <= now }.count
        if recentWaters > 0 {
            need = max(5 * 60, need - Double(recentWaters) * 5 * 60)
        }
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
        let cat = session.beverageCategory
        let physicalDesc = cat.formatPhysical(from: units)
        let softDesc = cat.formatPhysical(from: session.softLimit)
        let hardDesc = cat.formatPhysical(from: session.hardLimit)

        switch cue {
        case .calm:
            return ("慢慢来", "放下手机尽兴聚聚，到点我会提醒你。")
        case .settle:
            return ("节奏刚好", "当前约 \(physicalDesc)。下一杯不急，先喝口水。")
        case .hurried:
            return ("有点快了", "上两杯喝得太急。先停一停喝杯水，缓大约 \(waitMinutes) 分钟。")
        case .near:
            return ("快到线了", "约 \(physicalDesc)，建议上限是 \(softDesc)。这杯就当最后一杯吧。")
        case .due:
            return ("可以收了", "已到建议线 \(softDesc)。现在收杯，明早一身轻松。")
        case .over:
            let overMinutes = max(0, Int(elapsed - session.plannedSeconds) / 60)
            if units >= Double(session.hardLimit) - 0.0001 {
                return ("该停了", "约 \(physicalDesc)，已超过上限 \(hardDesc)。每 10 分钟持续提醒，直到你收杯。")
            }
            return ("该停了", "已超出预定时长 \(overMinutes) 分钟。每 10 分钟持续提醒，直到你收杯。")
        }
    }
}

// MARK: - 模型扩展：酒种与声音

public enum BeverageCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case beer = "beer"       // 啤酒
    case baijiu = "baijiu"   // 白酒
    case wine = "wine"       // 红酒
    case custom = "custom"   // 混饮/通用

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .beer: "啤酒"
        case .baijiu: "白酒"
        case .wine: "红酒"
        case .custom: "混饮/通用"
        }
    }

    public var unitName: String {
        switch self {
        case .beer: "听"
        case .baijiu: "两"
        case .wine: "杯"
        case .custom: "标准杯"
        }
    }

    public var icon: String {
        switch self {
        case .beer: "mug.fill"
        case .baijiu: "flame.fill"
        case .wine: "wineglass.fill"
        case .custom: "sparkles"
        }
    }

    public var specSubtitle: String {
        switch self {
        case .beer: "500ml / 听 · 约 1.3 标准杯"
        case .baijiu: "50ml / 两 · 约 1.5 标准杯"
        case .wine: "150ml / 杯 · 约 1.1 标准杯"
        case .custom: "14g 纯乙醇 / 标准杯"
        }
    }

    /// 1个物理单位折合的标准杯数 (WHO标准：1标准杯 = 14克乙醇)
    /// 啤酒：1大听 (500ml 4.5% ≈ 18g乙醇) ≈ 1.286 标准杯
    /// 白酒：1两 (50ml 52度 ≈ 21g乙醇) = 1.50 标准杯 (小酌3两=4.5杯，聚餐6两=9杯)
    /// 红酒：1杯 (150ml 12.5% ≈ 15g乙醇) ≈ 1.071 标准杯 (小酌4杯≈4.3杯，聚餐8杯≈8.6杯)
    /// 通用：1标准杯 = 1.0
    public var standardUnitsPerUnit: Double {
        switch self {
        case .beer: 18.0 / 14.0
        case .baijiu: 1.50
        case .wine: 1.071
        case .custom: 1.0
        }
    }

    public func physicalValue(from standardUnits: Double) -> Double {
        standardUnits / standardUnitsPerUnit
    }

    public func formatPhysical(from standardUnits: Double) -> String {
        let val = physicalValue(from: standardUnits)
        switch self {
        case .beer:
            let rounded = (val * 10).rounded() / 10
            if abs(rounded - rounded.rounded()) < 0.05 {
                return "\(Int(rounded.rounded())) 听"
            }
            return String(format: "%.1f 听", rounded)
        case .baijiu:
            let rounded = (val * 10).rounded() / 10
            if abs(rounded - rounded.rounded()) < 0.05 {
                return "\(Int(rounded.rounded())) 两"
            }
            return String(format: "%.1f 两", rounded)
        case .wine:
            let rounded = (val * 10).rounded() / 10
            if abs(rounded - rounded.rounded()) < 0.05 {
                return "\(Int(rounded.rounded())) 杯"
            }
            return String(format: "%.1f 杯", rounded)
        case .custom:
            let rounded = (standardUnits * 10).rounded() / 10
            if abs(rounded - rounded.rounded()) < 0.05 {
                return "\(Int(rounded.rounded())) 标准杯"
            }
            return "\(Format.units(standardUnits)) 标准杯"
        }
    }
}

public enum NotificationSoundOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case glass = "glass"     // 连环碰杯 (3.8秒，高频强穿透)
    case bell = "bell"       // 铜钟三鸣 (4.5秒，浑厚宏亮)
    case water = "water"     // 醒神琶音 (3.5秒，明亮抓耳)
    case wood = "wood"       // 木鱼连击 (3.2秒，节奏紧凑)
    case system = "system"   // 系统默认音

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .glass: "连环碰杯"
        case .bell: "铜钟三鸣"
        case .water: "醒神琶音"
        case .wood: "木鱼连击"
        case .system: "系统默认"
        }
    }

    public var fileName: String? {
        switch self {
        case .glass: "glass.caf"
        case .bell: "bell.caf"
        case .water: "water.caf"
        case .wood: "wood.caf"
        case .system: nil
        }
    }
}

public enum HorologyDialStyle: String, Codable, Sendable {
    case geneva       // 日内瓦条形精密刻度
    case oriental     // 东方十二辰玉珠星点
    case breguet      // 古典宝玑铁轨圈与十字线
    case chronograph  // 现代双层测速仪夜光锚点

    public var displayName: String {
        switch self {
        case .geneva: "日内瓦条形时标"
        case .oriental: "东方十二辰星点"
        case .breguet: "古典宝玑铁轨盘"
        case .chronograph: "深潜夜光测速盘"
        }
    }
}

public enum AppTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case obsidianGold = "obsidianGold"         // 曜石黑金（默认深色）
    case celadonJade = "celadonJade"           // 汝窑天青（宋韵青玉深色）
    case burgundyCellar = "burgundyCellar"     // 微醺酒庄（勃艮第玫瑰金深色）
    case midnightSapphire = "midnightSapphire" // 深海蓝盘（皇家午夜蓝深色）
    case enamelIvory = "enamelIvory"           // 大明火珐琅（日内瓦暖白浅色）
    case xuanPaperInk = "xuanPaperInk"         // 宣纸水墨（兰亭松烟浅色）

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .obsidianGold: "曜石黑金"
        case .celadonJade: "汝窑天青"
        case .burgundyCellar: "微醺酒庄"
        case .midnightSapphire: "深海蓝盘"
        case .enamelIvory: "大明火珐琅"
        case .xuanPaperInk: "宣纸水墨"
        }
    }

    public var subtitle: String {
        switch self {
        case .obsidianGold: "朗格夜宴 · 德系黑金"
        case .celadonJade: "宋韵流觞 · 雨过天青"
        case .burgundyCellar: "勃艮第夜 · 玫瑰铜金"
        case .midnightSapphire: "皇家午夜 · 冰川铂金"
        case .enamelIvory: "日内瓦白盘 · 琥珀古铜"
        case .xuanPaperInk: "兰亭雅集 · 宣纸松烟"
        }
    }

    public var poeticDescription: String {
        switch self {
        case .obsidianGold:
            "深邃曜石黑底配朗格香槟金与波尔多红宝石，适合夜间威士忌酒廊与商务晚宴。"
        case .celadonJade:
            "取意宋代汝窑天青釉与竹林夜雨，温润青玉光泽配朱砂印泥，清雅克制。"
        case .burgundyCellar:
            "古老地下橡木桶酒窖、陈年黑皮诺与 18K 玫瑰金怀表，浓郁浪漫的烛光氛围。"
        case .midnightSapphire:
            "瑞士深海潜水腕表午夜蓝太阳纹表盘，配冰川铂金与夜光冰蓝，冷静理性。"
        case .enamelIvory:
            "大明火暖象牙白珐琅盘配烤漆墨字与琥珀铜金，通透明亮，极适合午宴与日间茶叙。"
        case .xuanPaperInk:
            "手工生宣米白底、松烟浓墨与苍松黛青，如展开一卷曲水流觞的东方文人手卷。"
        }
    }

    public var icon: String {
        switch self {
        case .obsidianGold: "wineglass"
        case .celadonJade: "leaf.fill"
        case .burgundyCellar: "sparkles"
        case .midnightSapphire: "safari.fill"
        case .enamelIvory: "sun.max.fill"
        case .xuanPaperInk: "seal.fill"
        }
    }

    public var isLight: Bool {
        switch self {
        case .enamelIvory, .xuanPaperInk:
            return true
        case .obsidianGold, .celadonJade, .burgundyCellar, .midnightSapphire:
            return false
        }
    }

    public var modeTag: String {
        isLight ? "浅色日间" : "深色夜间"
    }

    public var dialStyle: HorologyDialStyle {
        switch self {
        case .obsidianGold: .geneva
        case .celadonJade: .oriental
        case .burgundyCellar: .breguet
        case .midnightSapphire: .chronograph
        case .enamelIvory: .breguet
        case .xuanPaperInk: .oriental
        }
    }
}

// MARK: - 模型

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
    case drank
    case skipped
    case logged
}

struct Prompt: Codable, Identifiable, Equatable {
    var id: UUID
    var at: Date
    var level: Intensity
    var estimate: Double
    var projectedUnits: Double
    var semanticText: String?
    var reply: PromptReply?
    var drinkID: UUID?
}

struct PaceSnapshot: Equatable {
    var cue: Cue
    var intensity: Intensity
    var poeticPhase: String
    var title: String
    var message: String
    var units: Double
    var confirmedUnits: Double
    var estimatedUnits: Double
    var physicalText: String
    var category: BeverageCategory
    var drinkCount: Int
    var waterCount: Int
    var elapsed: TimeInterval
    var planned: TimeInterval
    var isTooFast: Bool
    var waitMinutes: Int
    var sinceLastDrink: TimeInterval?
    var nextPrompt: Prompt?
    var pendingPrompt: Prompt?
    var softLimit: Double
    var hardLimit: Double
}

struct DrinkPreset: Identifiable, Equatable, Sendable {
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
    var beverageCategory: BeverageCategory = .beer
    var plannedMinutes: Int
    var softLimit: Double
    var hardLimit: Double
    var minIntervalMinutes: Int
    var estimateWhenSilent: Bool = true
    var drinks: [DrinkLog]
    var waters: [WaterLog]
    var prompts: [Prompt] = []
    var lastAnnouncedRank: Int
    var lastAnnouncedCue: Cue? = nil

    enum CodingKeys: String, CodingKey {
        case id, startedAt, endedAt, planName, beverageCategory, plannedMinutes, softLimit, hardLimit
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
        beverageCategory = try c.decodeIfPresent(BeverageCategory.self, forKey: .beverageCategory) ?? .beer
        plannedMinutes = try c.decode(Int.self, forKey: .plannedMinutes)
        if let d = try? c.decode(Double.self, forKey: .softLimit) {
            softLimit = d
        } else {
            softLimit = Double(try c.decode(Int.self, forKey: .softLimit))
        }
        if let d = try? c.decode(Double.self, forKey: .hardLimit) {
            hardLimit = d
        } else {
            hardLimit = Double(try c.decode(Int.self, forKey: .hardLimit))
        }
        minIntervalMinutes = try c.decode(Int.self, forKey: .minIntervalMinutes)
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

struct Plan: Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var plannedMinutes: Int
    var softLimit: Double
    var hardLimit: Double
    var minIntervalMinutes: Int
    var defaultBeverage: BeverageCategory = .baijiu

    var detail: String {
        "\(Format.units(softLimit)) 标准杯 · \(Format.minutes(plannedMinutes))"
    }

    func displayDetail(for category: BeverageCategory) -> String {
        switch id {
        case Plan.light.id:
            switch category {
            case .baijiu:
                return "3 两 · \(Format.minutes(plannedMinutes))"
            case .beer:
                return "4 听 · \(Format.minutes(plannedMinutes))"
            case .wine:
                return "4 杯 · \(Format.minutes(plannedMinutes))"
            case .custom:
                return "约 4.5 标准杯 · \(Format.minutes(plannedMinutes))"
            }
        case Plan.dinner.id:
            switch category {
            case .baijiu:
                return "6 两 · \(Format.minutes(plannedMinutes))"
            case .beer:
                return "7 听 · \(Format.minutes(plannedMinutes))"
            case .wine:
                return "8 杯 · \(Format.minutes(plannedMinutes))"
            case .custom:
                return "约 9 标准杯 · \(Format.minutes(plannedMinutes))"
            }
        default:
            let physical = category.formatPhysical(from: softLimit)
            return "\(physical) · \(Format.minutes(plannedMinutes))"
        }
    }

    static let light = Plan(
        id: "light",
        name: "小酌",
        plannedMinutes: 120,
        softLimit: 4.5,
        hardLimit: 6.0,
        minIntervalMinutes: 30,
        defaultBeverage: .baijiu
    )

    static let dinner = Plan(
        id: "dinner",
        name: "聚餐",
        plannedMinutes: 210,
        softLimit: 9.0,
        hardLimit: 12.0,
        minIntervalMinutes: 25,
        defaultBeverage: .baijiu
    )
}

struct Settings: Codable, Equatable {
    var plannedMinutes: Int = 120
    var softLimit: Double = 4.5
    var hardLimit: Double = 6.0
    var minIntervalMinutes: Int = 30
    var keepScreenOn: Bool = false
    var estimateWhenSilent: Bool = true
    var selectedPlanID: String = Plan.light.id
    var selectedBeverageCategory: BeverageCategory = .baijiu
    var notificationSound: NotificationSoundOption = .glass
    var selectedTheme: AppTheme = .obsidianGold

    mutating func normalize() {
        plannedMinutes = min(360, max(30, plannedMinutes))
        softLimit = min(20.0, max(1.0, softLimit))
        hardLimit = min(25.0, max(softLimit, hardLimit))
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
            minIntervalMinutes: minIntervalMinutes,
            defaultBeverage: selectedBeverageCategory
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
        if let d = try? c.decode(Double.self, forKey: .softLimit) {
            softLimit = d
        } else if let i = try? c.decode(Int.self, forKey: .softLimit) {
            softLimit = Double(i)
        } else {
            softLimit = base.softLimit
        }
        if let d = try? c.decode(Double.self, forKey: .hardLimit) {
            hardLimit = d
        } else if let i = try? c.decode(Int.self, forKey: .hardLimit) {
            hardLimit = Double(i)
        } else {
            hardLimit = base.hardLimit
        }
        minIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .minIntervalMinutes) ?? base.minIntervalMinutes
        keepScreenOn = try c.decodeIfPresent(Bool.self, forKey: .keepScreenOn) ?? base.keepScreenOn
        estimateWhenSilent = try c.decodeIfPresent(Bool.self, forKey: .estimateWhenSilent) ?? base.estimateWhenSilent
        selectedPlanID = try c.decodeIfPresent(String.self, forKey: .selectedPlanID) ?? base.selectedPlanID
        selectedBeverageCategory = try c.decodeIfPresent(BeverageCategory.self, forKey: .selectedBeverageCategory) ?? base.selectedBeverageCategory
        notificationSound = try c.decodeIfPresent(NotificationSoundOption.self, forKey: .notificationSound) ?? base.notificationSound
        selectedTheme = try c.decodeIfPresent(AppTheme.self, forKey: .selectedTheme) ?? base.selectedTheme
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

    /// 根据当前时间段返回自然的场次称谓（如“午间”、“午后”、“今晚”、“本场”）
    static func sessionPeriodPrompt(at date: Date = .now) -> (question: String, actionPrefix: String) {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 11..<14:
            return ("中午主要喝什么", "开启午间")
        case 14..<17:
            return ("下午主要喝什么", "开启午后")
        case 17...23, 0..<5:
            return ("今晚主要喝什么", "开启今晚")
        default:
            return ("本场主要喝什么", "开启本场")
        }
    }
}

#if PACE_CHECKS && os(macOS)
enum PaceChecks {
    static func run() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = Session(
            id: UUID(),
            startedAt: start,
            endedAt: nil,
            planName: "小酌",
            beverageCategory: .baijiu,
            plannedMinutes: 120,
            softLimit: 4.5,
            hardLimit: 6.0,
            minIntervalMinutes: 30,
            estimateWhenSilent: true,
            drinks: [],
            waters: [],
            prompts: [],
            lastAnnouncedRank: 0
        )

        // 1. 初始状态检验
        session.prompts = Pace.projectPrompts(session, now: start)
        assert(session.prompts.count == Pace.promptBudget, "预排数量应等于预算")
        let snap0 = Pace.evaluate(session, now: start)
        assert(snap0.intensity == .quiet, "开局应为 quiet")
        assert(snap0.cue == .calm, "开局应为 calm")
        assert(abs(session.prompts[0].at.timeIntervalSince(start) - 30 * 60) < 1, "首条提醒应为 30 分钟后")

        // 2. 静默 35 分钟后触发 pendingPrompt 与估算增长
        let t35 = start.addingTimeInterval(35 * 60)
        let snap35 = Pace.evaluate(session, now: t35)
        assert(snap35.estimatedUnits > 0, "静默应产生估算杯数")
        assert(snap35.pendingPrompt != nil, "应存在待回应的提醒")

        // 3. 急饮检测
        let preset = Pace.presets.first { $0.id == "baijiu" }!
        session.drinks.append(DrinkLog(id: UUID(), presetID: preset.id, name: preset.name, detail: preset.detail, grams: preset.grams, at: start.addingTimeInterval(5 * 60)))
        session.drinks.append(DrinkLog(id: UUID(), presetID: preset.id, name: preset.name, detail: preset.detail, grams: preset.grams, at: start.addingTimeInterval(15 * 60)))
        let snapFast = Pace.evaluate(session, now: start.addingTimeInterval(16 * 60))
        assert(snapFast.isTooFast, "10分钟内连喝两盅白酒应触发急饮提示")
        assert(snapFast.cue == .hurried, "Cue 应为 hurried")

        // 4. 越线状态检测
        for i in 0..<4 {
            session.drinks.append(DrinkLog(id: UUID(), presetID: preset.id, name: preset.name, detail: preset.detail, grams: preset.grams, at: start.addingTimeInterval(Double(30 + i * 20) * 60)))
        }
        let snapOver = Pace.evaluate(session, now: start.addingTimeInterval(110 * 60))
        assert(snapOver.intensity == .over, "超出硬限应为 over")
        assert(snapOver.cue == .over, "Cue 应为 over")
        assert(Pace.gap(for: snapOver.intensity, session: session) == 10 * 60, "越线后提醒间隔应为 10 分钟")

        print("✅ PaceChecks: All state machine & projection assertions passed.")
    }

    static let _autoRun: Void = {
        run()
    }()
}

let _ = PaceChecks._autoRun
#endif
