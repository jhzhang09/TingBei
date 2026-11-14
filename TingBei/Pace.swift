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
        DrinkPreset(id: "beer500", name: "啤酒", detail: "500 ml", grams: 18, category: .beer),
        DrinkPreset(id: "beer330", name: "啤酒", detail: "330 ml", grams: 12, category: .beer),
        DrinkPreset(id: "baijiu", name: "白酒", detail: "一两 · 50 ml", grams: 21, category: .baijiu),
        DrinkPreset(id: "wine", name: "红酒", detail: "150 ml", grams: 15, category: .wine),
        DrinkPreset(id: "huangjiu", name: "黄酒", detail: "100 ml", grams: 12, category: .custom),
        DrinkPreset(id: "cocktail", name: "鸡尾酒", detail: "一杯", grams: 18, category: .custom),
    ]

    static func inferredCategory(forPresetID presetID: String, fallback: BeverageCategory) -> BeverageCategory {
        switch presetID {
        case "beer500", "beer330":
            return .beer
        case "baijiu":
            return .baijiu
        case "wine":
            return .wine
        case "huangjiu", "cocktail", "generic":
            return .custom
        default:
            return fallback
        }
    }

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

        // 待校准提醒按时间从早到晚逐条呈现：每条未回应的过去提醒都在计入推测杯数，
        // 必须都能被用户确认或消除，不能只露出最近一条而让更早的推测静默累加。
        let unanswered = session.prompts.filter { $0.reply == nil && $0.at <= now }
        let pending = unanswered.min(by: { $0.at < $1.at })
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
            pendingCount: unanswered.count,
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

            // 估算增长：按方案自身节奏（预定时长内恰好喝到建议线）× 本拍实际间隔。
            // 不能按「每拍固定份数」累加：提醒随强度升级越来越密，固定份数会让推测速度越推越快、虚高。
            let stepEstimate = estimateRate(session) * at.timeIntervalSince(anchor)

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

    public var maxSoftPhysicalCount: Int {
        max(1, Int(floor(20.0 / standardUnitsPerUnit)))
    }

    public var maxHardPhysicalCount: Int {
        max(maxSoftPhysicalCount, Int(floor(25.0 / standardUnitsPerUnit)))
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

    /// 灵动岛紧凑态专用的简短物理量文案（如「3.5听」「2杯」），避免窄位截断
    public func formatCompactPhysical(from standardUnits: Double) -> String {
        let val = physicalValue(from: standardUnits)
        let num = Format.units(val)
        switch self {
        case .beer: return "\(num)听"
        case .baijiu: return "\(num)两"
        case .wine: return "\(num)杯"
        case .custom: return "\(Format.units(standardUnits))杯"
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

/// 表盘时标流派。rawValue 已持久化，只能改显示名，不能改 case 名。
public enum HorologyDialStyle: String, Codable, Sendable {
    case geneva       // 描金双线：十二点位双金线 + 十一道金标
    case ruKiln       // 弦纹开片：器物双弦纹 + 冰裂开片 + 支钉玉珠
    case breguet      // 宝相星芒：花边双轨 + 微珠 + 十二枚四芒宝相星
    case chronograph  // 北辰夜光：十二点位倒三角北辰 + 三六九夜光柱
    case enamel       // 界尺双轨：界画式双环分刻 + 四正界线
    case xuanInk      // 乌丝十二辰：乌丝双栏 + 十二辰界格 + 子位朱印

    public var displayName: String {
        switch self {
        case .geneva: "描金双线"
        case .ruKiln: "弦纹开片"
        case .breguet: "宝相星芒"
        case .chronograph: "北辰夜光"
        case .enamel: "界尺双轨"
        case .xuanInk: "乌丝十二辰"
        }
    }
}

/// 席间主题。rawValue 已持久化在用户设置中，只能改显示文案与配色，不能改 case 名或 rawValue。
/// 命名原则：名实相符——每个主题取一种中国器物、工艺或诗句，配色与表盘纹样都要对得上这个名字。
public enum AppTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case obsidianGold = "obsidianGold"         // 玄漆描金：黑漆为地，泥金描线
    case celadonJade = "celadonJade"           // 汝窑天青：雨过天青，冰裂开片
    case burgundyCellar = "burgundyCellar"     // 琥珀光：取李白「玉碗盛来琥珀光」
    case midnightSapphire = "midnightSapphire" // 霁蓝映月：霁蓝釉色，月白银辉
    case enamelIvory = "enamelIvory"           // 牙白界画：象牙瓷白，界尺工笔
    case xuanPaperInk = "xuanPaperInk"         // 宣纸水墨：松烟浓墨，泥金朱印

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .obsidianGold: "玄漆描金"
        case .celadonJade: "汝窑天青"
        case .burgundyCellar: "琥珀光"
        case .midnightSapphire: "霁蓝映月"
        case .enamelIvory: "牙白界画"
        case .xuanPaperInk: "宣纸水墨"
        }
    }

    public var subtitle: String {
        switch self {
        case .obsidianGold: "黑漆为地 · 泥金描线"
        case .celadonJade: "雨过天青 · 冰裂开片"
        case .burgundyCellar: "兰陵美酒 · 玉碗琥珀"
        case .midnightSapphire: "霁蓝釉色 · 月白银辉"
        case .enamelIvory: "象牙瓷白 · 界尺工笔"
        case .xuanPaperInk: "兰亭雅集 · 松烟泥金"
        }
    }

    public var poeticDescription: String {
        switch self {
        case .obsidianGold:
            "取明清黑漆描金器：乌黑漆地温润如夜，泥金细线勾勒刻度，子位以双金线为记。"
        case .celadonJade:
            "取意宋代汝窑「雨过天青云破处」：粉青釉面配香灰胎墨字，器物双弦纹与蝉翼冰裂开片。"
        case .burgundyCellar:
            "取李白「兰陵美酒郁金香，玉碗盛来琥珀光」：郁金酒色为地，琥珀暖光为饰，盘缘缀宝相星芒。"
        case .midnightSapphire:
            "取明清霁蓝釉：深蓝如夜、釉色匀净，月白银辉为针，子位一枚倒三角作北辰。"
        case .enamelIvory:
            "取宋元界画以尺引线的工整：象牙瓷白为地，乌墨双界为轨，铜金分刻，四正细线如界尺定位。"
        case .xuanPaperInk:
            "泾县生宣米白为地，徽州松烟浓墨，书画泥金与西泠朱砂印泥，乌丝界格温润儒雅。"
        }
    }

    public var icon: String {
        switch self {
        case .obsidianGold: "paintbrush.pointed"
        case .celadonJade: "drop.halffull"
        case .burgundyCellar: "wineglass"
        case .midnightSapphire: "moon.stars"
        case .enamelIvory: "ruler"
        case .xuanPaperInk: "seal.fill"
        }
    }

    public var isLight: Bool {
        switch self {
        case .celadonJade, .enamelIvory, .xuanPaperInk:
            return true
        case .obsidianGold, .burgundyCellar, .midnightSapphire:
            return false
        }
    }

    public var modeTag: String {
        switch self {
        case .celadonJade: "温润青釉"
        case .enamelIvory, .xuanPaperInk: "素雅清昼"
        case .obsidianGold, .burgundyCellar, .midnightSapphire: "深色夜宴"
        }
    }

    public var dialStyle: HorologyDialStyle {
        switch self {
        case .obsidianGold: .geneva
        case .celadonJade: .ruKiln
        case .burgundyCellar: .breguet
        case .midnightSapphire: .chronograph
        case .enamelIvory: .enamel
        case .xuanPaperInk: .xuanInk
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
    /// 尚未回应、且已计入推测的过去提醒条数（含 pendingPrompt 本身）
    var pendingCount: Int
    var softLimit: Double
    var hardLimit: Double
}

enum FeelingTag: String, Codable, CaseIterable, Identifiable, Sendable {
    case fresh = "fresh"
    case tipsy = "tipsy"
    case tired = "tired"
    case dizzy = "dizzy"
    case rough = "rough"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fresh: "清爽自在"
        case .tipsy: "恰到微醺"
        case .tired: "略显疲倦"
        case .dizzy: "有些上头"
        case .rough: "次日难受"
        }
    }

    var icon: String {
        switch self {
        case .fresh: "sun.max.fill"
        case .tipsy: "moon.stars.fill"
        case .tired: "zzz"
        case .dizzy: "wind"
        case .rough: "cloud.drizzle.fill"
        }
    }
}

struct DrinkPreset: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var detail: String
    var grams: Double
    var category: BeverageCategory? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, detail, grams, category
    }

    init(id: String, name: String, detail: String, grams: Double, category: BeverageCategory? = nil) {
        self.id = id
        self.name = name
        self.detail = detail
        self.grams = grams
        self.category = category
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        detail = try c.decode(String.self, forKey: .detail)
        grams = try c.decode(Double.self, forKey: .grams)
        category = try c.decodeIfPresent(BeverageCategory.self, forKey: .category)
    }

    var standardDrinks: Double { grams / Pace.gramsPerStandard }

    var resolvedCategory: BeverageCategory {
        category ?? Pace.inferredCategory(forPresetID: id, fallback: .custom)
    }

    static func custom(name: String, volumeMl: Double, abv: Double, category: BeverageCategory? = nil) -> DrinkPreset {
        let grams = volumeMl * (abv / 100.0) * 0.8
        let detail = "\(Int(volumeMl)) ml · \(String(format: "%.1f", abv))%"
        let safeName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return DrinkPreset(
            id: "custom_\(UUID().uuidString.prefix(6))",
            name: safeName.isEmpty ? "自选酒饮" : safeName,
            detail: detail,
            grams: grams,
            category: category
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
    /// 记录创建时的真实操作时间，用于回溯补记后「撤销」精准撤回最近一次操作
    var createdAt: Date? = nil
    /// 所属酒种（用于混合饮酒场次按实际酒种拆分统计）
    var category: BeverageCategory? = nil

    enum CodingKeys: String, CodingKey {
        case id, presetID, name, detail, grams, at, createdAt, category
    }

    init(
        id: UUID,
        presetID: String,
        name: String,
        detail: String,
        grams: Double,
        at: Date,
        createdAt: Date? = nil,
        category: BeverageCategory? = nil
    ) {
        self.id = id
        self.presetID = presetID
        self.name = name
        self.detail = detail
        self.grams = grams
        self.at = at
        self.createdAt = createdAt
        self.category = category
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        presetID = try c.decode(String.self, forKey: .presetID)
        name = try c.decode(String.self, forKey: .name)
        detail = try c.decode(String.self, forKey: .detail)
        grams = try c.decode(Double.self, forKey: .grams)
        at = try c.decode(Date.self, forKey: .at)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        category = try c.decodeIfPresent(BeverageCategory.self, forKey: .category)
    }

    func resolvedCategory(fallback: BeverageCategory) -> BeverageCategory {
        category ?? Pace.inferredCategory(forPresetID: presetID, fallback: fallback)
    }

    var preset: DrinkPreset {
        DrinkPreset(id: presetID, name: name, detail: detail, grams: grams, category: category)
    }
}

struct WaterLog: Codable, Identifiable, Equatable {
    var id: UUID
    var at: Date
    var createdAt: Date? = nil
}

struct BeverageBreakdownItem: Identifiable, Equatable {
    var id: String { category.id }
    var category: BeverageCategory
    var drinkCount: Int
    var confirmedGrams: Double
    var estimatedGrams: Double

    var totalGrams: Double { confirmedGrams + estimatedGrams }
    var confirmedUnits: Double { confirmedGrams / Pace.gramsPerStandard }
    var totalUnits: Double { totalGrams / Pace.gramsPerStandard }
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
    var feeling: FeelingTag? = nil
    var note: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, startedAt, endedAt, planName, beverageCategory, plannedMinutes, softLimit, hardLimit
        case minIntervalMinutes, estimateWhenSilent, drinks, waters, prompts
        case lastAnnouncedRank, lastAnnouncedCue, feeling, note
    }

    var plannedSeconds: TimeInterval { TimeInterval(max(plannedMinutes, 1) * 60) }
    var minIntervalSeconds: TimeInterval { TimeInterval(max(minIntervalMinutes, 1) * 60) }

    var alcoholGrams: Double { drinks.reduce(0) { $0 + $1.grams } }
    var standardDrinks: Double { alcoholGrams / Pace.gramsPerStandard }

    func confirmedUnits(at time: Date) -> Double {
        drinks.filter { $0.at <= time }.reduce(0) { $0 + $1.grams } / Pace.gramsPerStandard
    }

    func estimatedUnits(at time: Date) -> Double {
        guard estimateWhenSilent else { return 0 }
        return prompts.filter { $0.reply == nil && $0.at <= time }.reduce(0) { $0 + $1.estimate }
    }

    func units(at time: Date) -> Double {
        confirmedUnits(at: time) + estimatedUnits(at: time)
    }

    func beverageBreakdown(at time: Date? = nil, includeEstimated: Bool = true) -> [BeverageBreakdownItem] {
        let cutoff = time ?? endedAt ?? Date.distantFuture
        let relevantDrinks = drinks.filter { $0.at <= cutoff }
        var buckets: [BeverageCategory: (count: Int, confirmedGrams: Double, estimatedGrams: Double)] = [:]

        for drink in relevantDrinks {
            let cat = drink.resolvedCategory(fallback: beverageCategory)
            var entry = buckets[cat] ?? (0, 0, 0)
            entry.count += 1
            entry.confirmedGrams += drink.grams
            buckets[cat] = entry
        }

        if includeEstimated {
            let est = estimatedUnits(at: cutoff)
            if est > 0.001 {
                var entry = buckets[beverageCategory] ?? (0, 0, 0)
                entry.estimatedGrams += est * Pace.gramsPerStandard
                buckets[beverageCategory] = entry
            }
        }

        return buckets
            .map { key, value in
                BeverageBreakdownItem(
                    category: key,
                    drinkCount: value.count,
                    confirmedGrams: value.confirmedGrams,
                    estimatedGrams: value.estimatedGrams
                )
            }
            .sorted { lhs, rhs in
                if abs(lhs.totalGrams - rhs.totalGrams) > 0.01 {
                    return lhs.totalGrams > rhs.totalGrams
                }
                return lhs.drinkCount > rhs.drinkCount
            }
    }

    func isMixedBeverage(at time: Date? = nil) -> Bool {
        beverageBreakdown(at: time, includeEstimated: false).count > 1
    }

    func formattedMixSummary(at time: Date? = nil) -> String {
        let items = beverageBreakdown(at: time, includeEstimated: false)
        if items.isEmpty {
            let end = time ?? endedAt ?? Date()
            return beverageCategory.formatPhysical(from: units(at: end))
        }
        return items.map { item in
            "\(item.category.name) \(item.category.formatPhysical(from: item.confirmedUnits))"
        }.joined(separator: " · ")
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

    /// 是否为空场：须同时计入静默推测杯数，不能只看 drinks 是否为空，
    /// 否则整场未点记录、全靠推测的场次（可能已越线）会被误判为空场。
    var isEmptyRecord: Bool {
        outcome(at: endedAt ?? Date()) == .empty
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
        feeling = try c.decodeIfPresent(FeelingTag.self, forKey: .feeling)
        note = try c.decodeIfPresent(String.self, forKey: .note)
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

    /// 方案卡展示文案。必须由 softLimit 实际换算，保证卡片上的线与提醒/表盘使用的线一致。
    func displayDetail(for category: BeverageCategory) -> String {
        "\(category.formatPhysical(from: softLimit)) · \(Format.minutes(plannedMinutes))"
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
    var savedPresets: [DrinkPreset] = []
    var weeklyBudgetUnits: Double = 14.0

    mutating func normalize() {
        plannedMinutes = min(360, max(30, plannedMinutes))
        softLimit = min(20.0, max(1.0, softLimit))
        hardLimit = min(25.0, max(softLimit, hardLimit))
        minIntervalMinutes = min(90, max(10, minIntervalMinutes))
        weeklyBudgetUnits = min(60.0, max(2.0, weeklyBudgetUnits))
        if ![Plan.light.id, Plan.dinner.id, "custom"].contains(selectedPlanID) {
            selectedPlanID = Plan.light.id
        }
        var seenIDs = Set<String>()
        savedPresets = savedPresets.filter { preset in
            guard !preset.id.isEmpty, preset.grams > 0 else { return false }
            return seenIDs.insert(preset.id).inserted
        }
        if savedPresets.count > 20 {
            savedPresets = Array(savedPresets.prefix(20))
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
        savedPresets = try c.decodeIfPresent([DrinkPreset].self, forKey: .savedPresets) ?? base.savedPresets
        if let d = try? c.decode(Double.self, forKey: .weeklyBudgetUnits) {
            weeklyBudgetUnits = d
        } else {
            weeklyBudgetUnits = base.weeklyBudgetUnits
        }
    }
}

enum BackupRestoreMode: Equatable, Sendable {
    case merge
    case replace
}

struct BackupImportResult: Equatable {
    var state: SavedState
    var addedHistoryCount: Int
    var updatedHistoryCount: Int
    var addedPresetsCount: Int
}

struct SavedState: Codable, Equatable {
    static let maxHistoryCount = 500

    var schemaVersion: Int = 2
    var exportedAt: Date? = nil
    var settings = Settings()
    var active: Session?
    var history: [Session] = []

    enum CodingKeys: String, CodingKey {
        case schemaVersion, exportedAt, settings, active, history
    }

    init(
        schemaVersion: Int = 2,
        exportedAt: Date? = nil,
        settings: Settings = Settings(),
        active: Session? = nil,
        history: [Session] = []
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.settings = settings
        self.active = active
        self.history = history
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        exportedAt = try c.decodeIfPresent(Date.self, forKey: .exportedAt)
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        active = try c.decodeIfPresent(Session.self, forKey: .active)
        history = try c.decodeIfPresent([Session].self, forKey: .history) ?? []
    }

    func merged(with incoming: SavedState, mode: BackupRestoreMode) -> BackupImportResult {
        switch mode {
        case .replace:
            var next = incoming
            next.settings.normalize()
            if next.active?.endedAt != nil {
                next.active = nil
            }
            next.history.sort { $0.startedAt < $1.startedAt }
            if next.history.count > Self.maxHistoryCount {
                next.history = Array(next.history.suffix(Self.maxHistoryCount))
            }
            return BackupImportResult(
                state: next,
                addedHistoryCount: next.history.count,
                updatedHistoryCount: 0,
                addedPresetsCount: next.settings.savedPresets.count
            )

        case .merge:
            var next = self
            var historyByID: [UUID: Session] = Dictionary(uniqueKeysWithValues: next.history.map { ($0.id, $0) })
            var added = 0
            var updated = 0

            for incomingSession in incoming.history {
                if let existing = historyByID[incomingSession.id] {
                    if Self.shouldPrefer(incoming: incomingSession, over: existing) {
                        historyByID[incomingSession.id] = incomingSession
                        updated += 1
                    }
                } else {
                    historyByID[incomingSession.id] = incomingSession
                    added += 1
                }
            }

            var mergedHistory = Array(historyByID.values).sorted { $0.startedAt < $1.startedAt }
            if mergedHistory.count > Self.maxHistoryCount {
                mergedHistory = Array(mergedHistory.suffix(Self.maxHistoryCount))
            }
            next.history = mergedHistory

            let existingPresetIDs = Set(next.settings.savedPresets.map(\.id))
            var addedPresets = 0
            for preset in incoming.settings.savedPresets where !existingPresetIDs.contains(preset.id) {
                next.settings.savedPresets.append(preset)
                addedPresets += 1
            }
            if next.active == nil, let incomingActive = incoming.active, incomingActive.endedAt == nil {
                next.active = incomingActive
            }
            next.settings.normalize()
            return BackupImportResult(
                state: next,
                addedHistoryCount: added,
                updatedHistoryCount: updated,
                addedPresetsCount: addedPresets
            )
        }
    }

    private static func shouldPrefer(incoming: Session, over existing: Session) -> Bool {
        guard incoming != existing else { return false }
        let incomingScore = completenessScore(of: incoming)
        let existingScore = completenessScore(of: existing)
        if incomingScore != existingScore {
            return incomingScore > existingScore
        }
        let incomingEnd = incoming.endedAt ?? incoming.startedAt
        let existingEnd = existing.endedAt ?? existing.startedAt
        return incomingEnd > existingEnd
    }

    private static func completenessScore(of session: Session) -> Int {
        var score = session.drinks.count * 2 + session.waters.count
        if session.endedAt != nil { score += 5 }
        if session.feeling != nil { score += 3 }
        if let note = session.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score += 3
        }
        return score
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

    static func monthTitle(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "zh_CN")))
    }

    static func monthDay(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))
    }

    static func sessionTimeRange(start: Date, end: Date) -> String {
        let calendar = Calendar.current
        let startStr = shortTime(start)
        let endStr = shortTime(end)
        if calendar.isDate(start, inSameDayAs: end) {
            return "\(startStr)–\(endStr)"
        }
        return "\(startStr)–次日 \(endStr)"
    }

    static func sessionDayAndRange(start: Date, end: Date) -> String {
        "\(day(start)) \(sessionTimeRange(start: start, end: end))"
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

        // 5. 方案卡展示的建议线必须与实际 softLimit 换算一致
        for plan in [Plan.light, Plan.dinner] {
            for cat in BeverageCategory.allCases {
                let expected = cat.formatPhysical(from: plan.softLimit)
                assert(plan.displayDetail(for: cat).hasPrefix(expected), "\(plan.name)·\(cat.name) 方案卡应显示 \(expected)")
            }
        }
        assert(Plan.light.displayDetail(for: .beer).hasPrefix("3.5 听"), "小酌啤酒建议线应为 3.5 听")

        // 6. 空场判定须计入静默推测：整场没点记录但有推测杯数的场次不是空场
        var silent = session
        silent.drinks = []
        silent.waters = []
        silent.prompts = Pace.projectPrompts(silent, now: start)
        silent.endedAt = start.addingTimeInterval(70 * 60)
        assert(silent.drinks.isEmpty && silent.units(at: silent.endedAt!) > 0, "静默场次应有推测杯数")
        assert(!silent.isEmptyRecord, "有推测杯数的静默场次不应被判为空场")
        var blank = silent
        blank.endedAt = start.addingTimeInterval(10 * 60)
        assert(blank.isEmptyRecord, "首次提醒前结束、无记录的场次应为空场")

        // 7. 静默推测按方案节奏：全程不回应时，到预定时长的推测量不应超过建议线，也不应少于一拍以上
        var quiet = session
        quiet.drinks = []
        quiet.waters = []
        quiet.prompts = Pace.projectPrompts(quiet, now: start)
        let atPlanned = quiet.units(at: start.addingTimeInterval(quiet.plannedSeconds))
        assert(atPlanned <= quiet.softLimit + 0.0001, "静默推测在预定时长内不应超过建议线（实际 \(atPlanned)）")
        assert(atPlanned >= quiet.softLimit - Pace.estimateRate(quiet) * 30 * 60 - 0.0001, "静默推测不应明显低于方案节奏（实际 \(atPlanned)）")

        // 8. 多条未回应提醒按时间从早到晚逐条校准
        let t65 = start.addingTimeInterval(65 * 60)
        let snap65 = Pace.evaluate(quiet, now: t65)
        let unansweredAt65 = quiet.prompts.filter { $0.at <= t65 }
        assert(unansweredAt65.count >= 2, "65 分钟时应已有至少 2 条提醒")
        assert(snap65.pendingCount == unansweredAt65.count, "pendingCount 应等于未回应的过去提醒数")
        assert(snap65.pendingPrompt?.id == unansweredAt65.min(by: { $0.at < $1.at })?.id, "应先呈现最早一条待校准提醒")

        // 9. 关闭静默推测后，未回应提醒不再计入推测杯数
        var noEst = quiet
        noEst.estimateWhenSilent = false
        assert(noEst.estimatedUnits(at: t65) == 0, "关闭静默推测后 estimatedUnits 应为 0")

        // 10. 物理单位上限换算与 Settings.normalize 一致，步进器不会卡死
        for cat in BeverageCategory.allCases {
            assert(Double(cat.maxSoftPhysicalCount) * cat.standardUnitsPerUnit <= 20.0 + 0.0001, "\(cat.name) 物理建议线上限不应超过 20 标准杯")
            assert(Double(cat.maxHardPhysicalCount) * cat.standardUnitsPerUnit <= 25.0 + 0.0001, "\(cat.name) 物理警戒线上限不应超过 25 标准杯")
        }

        // 11. 混合酒种单场按实际饮品类别拆分统计
        let beerPreset = Pace.presets.first { $0.id == "beer500" }!
        let mixed = Session(
            id: UUID(),
            startedAt: start,
            endedAt: start.addingTimeInterval(90 * 60),
            planName: "聚餐",
            beverageCategory: .beer,
            plannedMinutes: 180,
            softLimit: 6.0,
            hardLimit: 9.0,
            minIntervalMinutes: 25,
            estimateWhenSilent: false,
            drinks: [
                DrinkLog(id: UUID(), presetID: preset.id, name: preset.name, detail: preset.detail, grams: preset.grams, at: start.addingTimeInterval(10 * 60), category: .baijiu),
                DrinkLog(id: UUID(), presetID: beerPreset.id, name: beerPreset.name, detail: beerPreset.detail, grams: beerPreset.grams, at: start.addingTimeInterval(35 * 60), category: .beer),
            ],
            waters: [],
            prompts: [],
            lastAnnouncedRank: 0
        )
        assert(mixed.isMixedBeverage(), "同时记了白酒和啤酒应判定为混饮")
        let breakdown = mixed.beverageBreakdown(includeEstimated: false)
        assert(breakdown.count == 2, "混合酒种拆分应包含 2 个类别")
        assert(breakdown.first?.category == .baijiu, "克数更高的白酒应排在第一位")

        // 12. Settings.normalize 约束每周参考预算与收藏酒品去重
        var rawSettings = Settings()
        rawSettings.weeklyBudgetUnits = 99
        let dupPreset = DrinkPreset(id: "ipa", name: "精酿 IPA", detail: "473 ml · 6.5%", grams: 24.6, category: .beer)
        rawSettings.savedPresets = [dupPreset, dupPreset]
        rawSettings.normalize()
        assert(rawSettings.weeklyBudgetUnits == 60.0, "每周预算应限制在 60 标准杯以内")
        assert(rawSettings.savedPresets.count == 1, "重复 ID 的收藏预设应自动去重")

        // 13. SavedState 向后兼容旧版 JSON 并支持体感与随笔字段
        let legacyJSON = """
        {
          "settings": {
            "plannedMinutes": 120,
            "softLimit": 4.5,
            "hardLimit": 6.0,
            "minIntervalMinutes": 30,
            "selectedPlanID": "light",
            "selectedBeverageCategory": "beer"
          },
          "history": []
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedLegacy = try? decoder.decode(SavedState.self, from: legacyJSON)
        assert(decodedLegacy != nil, "旧版 SavedState JSON 应能平滑解码")
        assert(decodedLegacy?.settings.weeklyBudgetUnits == 14.0, "缺省每周预算应回退到默认值 14")

        // 14. SavedState 备份去重合并：新增场次、更新带体感的新版本、保留既有场次
        var s1 = mixed
        let s2ID = UUID()
        let s2Older = Session(
            id: s2ID,
            startedAt: start.addingTimeInterval(86400),
            endedAt: start.addingTimeInterval(90000),
            planName: "小酌",
            beverageCategory: .wine,
            plannedMinutes: 120,
            softLimit: 4.5,
            hardLimit: 6.0,
            minIntervalMinutes: 30,
            estimateWhenSilent: false,
            drinks: [],
            waters: [],
            prompts: [],
            lastAnnouncedRank: 0
        )
        var s2Richer = s2Older
        s2Richer.feeling = .fresh
        s2Richer.note = "状态很好"
        let currentState = SavedState(settings: rawSettings, active: nil, history: [s2Older])
        let incomingState = SavedState(settings: rawSettings, active: nil, history: [s1, s2Richer])
        let merged = currentState.merged(with: incomingState, mode: .merge)
        assert(merged.addedHistoryCount == 1, "合并应新增 1 场缺失手帐")
        assert(merged.updatedHistoryCount == 1, "合并应更新带体感随笔的那 1 场")
        assert(merged.state.history.count == 2, "合并后总场次应为 2")
        assert(merged.state.history.last?.feeling == .fresh, "合并后应保留更丰富的体感标签")
        s1.feeling = .tipsy
        assert(s1.feeling == .tipsy)

        print("✅ PaceChecks: All state machine & projection assertions passed.")
    }

    static let _autoRun: Void = {
        run()
    }()
}

let _ = PaceChecks._autoRun
#endif
