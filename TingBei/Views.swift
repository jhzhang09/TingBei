import SwiftUI
import UIKit

// MARK: - Theme (方案 A：暗夜香槟与黑金美学)

enum Theme {
    static let bg = Color(red: 0.04, green: 0.035, blue: 0.03) // 纯粹暗夜微暖黑 #0A0908
    static let raised = Color(red: 0.11, green: 0.095, blue: 0.08)
    static let surface = Color(red: 0.16, green: 0.14, blue: 0.12)
    static let cream = Color(red: 0.93, green: 0.90, blue: 0.85) // 象牙暖白 #EDE6DA
    static let mute = Color(red: 0.93, green: 0.90, blue: 0.85).opacity(0.52)
    static let faint = Color(red: 0.93, green: 0.90, blue: 0.85).opacity(0.12)
    static let gold = Color(red: 0.79, green: 0.66, blue: 0.43) // 尊贵香槟金 #C9A96E
    static let wine = Color(red: 0.76, green: 0.28, blue: 0.22) // 警戒深酒红
    static let sage = Color(red: 0.58, green: 0.68, blue: 0.52) // 沉静鼠尾草绿
    static let water = Color(red: 0.42, green: 0.68, blue: 0.86)
    static let ink = Color(red: 0.06, green: 0.05, blue: 0.04)

    static func tint(_ cue: Cue) -> Color {
        switch cue {
        case .calm, .settle:
            sage
        case .hurried, .near:
            gold
        case .due, .over:
            wine
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var store = store
        ZStack {
            NightBackground(cue: store.snapshot?.cue)
            if store.active != nil {
                SessionView()
            } else {
                HomeView()
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.gold)
        .sensoryFeedback(trigger: store.hapticEvent) { _, event in
            switch event {
            case .tap: .impact(weight: .medium)
            case .soft: .impact(weight: .light)
            case .warning: .warning
            case .stop: .error
            case .success: .success
            case nil: nil
            }
        }
        .onAppear { store.sceneAppeared() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.sceneAppeared()
            } else if phase == .background {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
        .sheet(item: $store.review) { session in
            SummarySheet(session: session)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
        }
    }
}

// MARK: - Night Background

struct NightBackground: View {
    var cue: Cue?

    var body: some View {
        let heat = heat(for: cue)
        ZStack {
            Theme.bg
            RadialGradient(
                colors: [
                    Theme.gold.opacity(0.12 * (1 - heat) + 0.03),
                    Theme.wine.opacity(0.40 * heat),
                    .clear,
                ],
                center: .top,
                startRadius: 10,
                endRadius: 580
            )
        }
        .ignoresSafeArea()
        .animation(.smooth(duration: 0.6), value: cue)
    }

    private func heat(for cue: Cue?) -> Double {
        switch cue {
        case nil, .calm:
            0
        case .settle:
            0.10
        case .hurried:
            0.35
        case .near:
            0.55
        case .due:
            0.75
        case .over:
            1.0
        }
    }
}

// MARK: - Home View

struct HomeView: View {
    @Environment(SessionStore.self) private var store
    @State private var isCustomExpanded = false
    @State private var showSecretSignature = false

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                plansSection
                customSection
                if !store.history.isEmpty {
                    historySection
                }
                footnote
                if showSecretSignature || (store.signatureStatus.daysRemaining != nil && store.signatureStatus.daysRemaining! <= 2) {
                    signatureBadge
                }
                if store.saveFailed {
                    Text("本地记录暂未写入成功，请检查存储空间。")
                        .font(.footnote)
                        .foregroundStyle(Theme.wine)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                CupMark()
                    .onLongPressGesture(minimumDuration: 1.5) {
                        withAnimation {
                            showSecretSignature.toggle()
                        }
                    }
                Text("停杯")
                    .font(.system(size: 44, weight: .light, design: .serif))
                    .foregroundStyle(Theme.cream)
            }
            Text("开喝后放下手机。无需频繁掏出记录，app 将按节拍主动提醒，随时间与酒意递增密度，守护从容。")
                .font(.subheadline)
                .lineSpacing(4)
                .foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 10)
    }

    private var plansSection: some View {
        VStack(spacing: 12) {
            PlanCard(plan: .light, isSelected: store.settings.selectedPlanID == Plan.light.id) {
                store.settings.selectedPlanID = Plan.light.id
                store.start(.light)
            }
            PlanCard(plan: .dinner, isSelected: store.settings.selectedPlanID == Plan.dinner.id) {
                store.settings.selectedPlanID = Plan.dinner.id
                store.start(.dinner)
            }
        }
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.smooth(duration: 0.3)) {
                    isCustomExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("自定义方案")
                            .font(.system(.title3, design: .serif))
                            .foregroundStyle(Theme.cream)
                        Text("\(store.settings.softLimit) 标准杯 · \(Format.minutes(store.settings.plannedMinutes)) · 基础间隔 \(store.settings.minIntervalMinutes) 分钟")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                    }
                    Spacer()
                    Image(systemName: isCustomExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Theme.gold)
                        .font(.subheadline)
                }
            }
            .buttonStyle(.plain)

            if isCustomExpanded {
                Divider().background(Theme.faint)
                SettingStepper(
                    title: "建议停杯线",
                    value: "\(store.settings.softLimit) 标准杯",
                    range: 1...12,
                    step: 1,
                    valueBinding: Bindable(store).settings.softLimit
                )
                SettingStepper(
                    title: "严格警戒线",
                    value: "\(store.settings.hardLimit) 标准杯",
                    range: store.settings.softLimit...16,
                    step: 1,
                    valueBinding: Bindable(store).settings.hardLimit
                )
                SettingStepper(
                    title: "预定时长",
                    value: Format.minutes(store.settings.plannedMinutes),
                    range: 30...360,
                    step: 15,
                    valueBinding: Bindable(store).settings.plannedMinutes
                )
                SettingStepper(
                    title: "两杯初始建议间隔",
                    value: "\(store.settings.minIntervalMinutes) 分钟",
                    range: 10...90,
                    step: 5,
                    valueBinding: Bindable(store).settings.minIntervalMinutes
                )
                Toggle(isOn: Bindable(store).settings.estimateWhenSilent) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("未回应时自动按节奏估算")
                            .foregroundStyle(Theme.cream)
                        Text("酒桌不方便拿手机时，保持杯量推测并在界面醒目标注")
                            .font(.caption2)
                            .foregroundStyle(Theme.mute)
                    }
                }
                .tint(Theme.gold)

                Toggle(isOn: Bindable(store).settings.keepScreenOn) {
                    Text("开喝后屏幕不自动锁屏")
                        .foregroundStyle(Theme.cream)
                }
                .tint(Theme.gold)

                FillButton(title: "按此目标开始", color: Theme.gold) {
                    store.settings.selectedPlanID = "custom"
                    store.start(store.settings.customPlan)
                }
            }
        }
        .padding(18)
        .background(CardChrome())
        .onChange(of: store.settings) { _, _ in
            store.normalizeAndSaveSettings()
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("历史回顾")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Theme.cream)
                Spacer()
                if store.history.contains(where: { $0.drinks.isEmpty }) {
                    Button("清理空场次") {
                        withAnimation {
                            store.clearEmptyHistory()
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.mute)
                }
            }

            VStack(spacing: 8) {
                ForEach(store.history.reversed()) { session in
                    Button {
                        store.review = session
                    } label: {
                        HistoryRow(session: session) {
                            withAnimation {
                                store.deleteHistory(id: session.id)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var footnote: some View {
        Text("标准杯基于世界卫生组织 14 克纯乙醇计算。本应用提供自律提醒，无法测算实际血液酒精浓度，酒后严禁驾车。")
            .font(.footnote)
            .foregroundStyle(Theme.mute.opacity(0.8))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var signatureBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(store.signatureStatus.daysRemaining != nil && store.signatureStatus.daysRemaining! > 1 ? Theme.sage : Theme.gold)
                .frame(width: 6, height: 6)
            Text(store.signatureStatus.displayText)
                .font(.caption2)
                .foregroundStyle(Theme.mute)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(Theme.raised))
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Session View (方案 A：黑金腕表表盘与极简控制)

struct SessionView: View {
    @Environment(SessionStore.self) private var store
    @State private var showingDrinks = false
    @State private var confirmingEnd = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 10)

            ScrollView {
                VStack(spacing: 20) {
                    if let snap = store.snapshot, let session = store.active {
                        watchDial(snap, session: session)
                        statusBanner(snap)
                        if store.notificationPermission == .denied {
                            notificationNotice
                        }
                        sessionLogs(session)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }

            bottomActions
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
        .sheet(isPresented: $showingDrinks) {
            DrinkSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
        }
        .confirmationDialog("结束这场？", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("结束这场", role: .destructive) { store.end() }
            Button("还没停，继续", role: .cancel) {}
        } message: {
            Text("结束后将终止排期提醒，并为您生成今晚的数据复盘。")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(store.active?.planName ?? "小酌")
                        .font(.system(.subheadline, design: .serif).weight(.medium))
                        .foregroundStyle(Theme.gold)
                    Text("·")
                        .foregroundStyle(Theme.mute)
                    Text(Format.shortTime(store.active?.startedAt ?? .now))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.mute)
                }
            }
            Spacer()
            if let snap = store.snapshot {
                Text("\(Format.hm(snap.elapsed)) / \(Format.hm(snap.planned))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.mute)
            }
        }
    }

    // 双环高端腕表表盘：外环时间，内环杯量
    private func watchDial(_ snap: PaceSnapshot, session: Session) -> some View {
        let soft = Double(max(session.softLimit, 1))
        let hard = Double(max(session.hardLimit, session.softLimit))
        let cupProgress = min(1.0, snap.units / hard)
        let timeProgress = min(1.0, snap.elapsed / session.plannedSeconds)
        let isEstimatedOnly = snap.confirmedUnits == 0 && snap.estimatedUnits > 0

        return ZStack {
            // 表盘刻度线背景
            DialTicksView()
                .frame(width: 250, height: 250)

            // 外圈细线：预定时长进度
            Circle()
                .stroke(Theme.gold.opacity(0.16), lineWidth: 1.5)
                .frame(width: 236, height: 236)
            Circle()
                .trim(from: 0, to: timeProgress)
                .stroke(Theme.gold, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 236, height: 236)
                .animation(.smooth(duration: 0.5), value: timeProgress)

            // 内圈：杯量进度
            Circle()
                .stroke(Theme.faint, lineWidth: 5)
                .frame(width: 196, height: 196)

            Circle()
                .trim(from: 0, to: cupProgress)
                .stroke(
                    snap.units >= hard ? Theme.wine : (snap.units >= soft ? Theme.wine.opacity(0.8) : Theme.cream),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 196, height: 196)
                .animation(.smooth(duration: 0.5), value: cupProgress)

            // 软限刻度小点 (在 soft/hard 的比例位置)
            let softRatio = soft / hard
            let softAngle = Angle.degrees(softRatio * 360 - 90)
            Circle()
                .fill(Theme.gold)
                .frame(width: 6, height: 6)
                .offset(x: 98 * cos(softAngle.radians), y: 98 * sin(softAngle.radians))

            // 中心大字数据
            VStack(spacing: 2) {
                if snap.estimatedUnits > 0 {
                    Text(isEstimatedOnly ? "节 奏 估 算" : "含 估 算")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(3)
                        .foregroundStyle(Theme.gold)
                } else {
                    Text("当 前 摄 入")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(3)
                        .foregroundStyle(Theme.mute)
                }

                Text(Format.units(snap.units))
                    .font(.system(size: 86, weight: .light, design: .serif))
                    .foregroundStyle(Theme.cream)
                    .contentTransition(.numericText())

                Text("/ \(session.softLimit) 标准杯")
                    .font(.subheadline)
                    .foregroundStyle(Theme.mute)
                    .padding(.top, -6)
            }
        }
        .frame(width: 260, height: 260)
        .padding(.vertical, 12)
    }

    private func statusBanner(_ snap: PaceSnapshot) -> some View {
        VStack(spacing: 8) {
            Text(snap.title)
                .font(.system(size: 24, weight: .light, design: .serif))
                .foregroundStyle(Theme.cream)

            Text(snap.message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true)

            if let next = snap.nextPrompt {
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge")
                        .font(.caption2)
                    Text("下次提醒 \(Format.shortTime(next.at)) · \(Format.until(next.at, now: store.now))")
                        .font(.caption.monospacedDigit())
                }
                .foregroundStyle(Theme.gold.opacity(0.9))
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }

    private var notificationNotice: some View {
        Button {
            store.openNotificationSettings()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bell.slash")
                Text("通知未授权。离屏时无法主动递增提醒，点此前往开启。")
                    .font(.footnote)
            }
            .foregroundStyle(Theme.gold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.gold.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private func sessionLogs(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("本场记录")
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Theme.cream)
                Spacer()
                if !session.drinks.isEmpty || !session.waters.isEmpty {
                    Button("撤销上一条") { store.undoLast() }
                        .font(.footnote)
                        .foregroundStyle(Theme.mute)
                }
            }

            if session.drinks.isEmpty && session.waters.isEmpty && session.prompts.filter({ $0.reply == nil && $0.at <= store.now }).isEmpty {
                Text("暂无手动操作。到点通知将主动询问，或直接点击下方「+1」补记。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.mute)
                    .padding(.vertical, 8)
            } else {
                ForEach(lines(session)) { line in
                    HStack(alignment: .firstTextBaseline) {
                        Text(Format.shortTime(line.at))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.mute)
                            .frame(width: 48, alignment: .leading)
                        Text(line.text)
                            .font(.subheadline)
                            .foregroundStyle(line.color)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    }

    // 方案 A 标志性三元按钮组：水 · +1 · 收
    private var bottomActions: some View {
        VStack(spacing: 8) {
            if let toast = store.toast {
                Text(toast)
                    .font(.footnote)
                    .foregroundStyle(Theme.gold)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(alignment: .bottom, spacing: 28) {
                // 喝水
                VStack(spacing: 6) {
                    Button {
                        store.logWater()
                    } label: {
                        Circle()
                            .stroke(Theme.water.opacity(0.4), lineWidth: 1)
                            .background(Circle().fill(Theme.raised))
                            .frame(width: 58, height: 58)
                            .overlay(
                                Image(systemName: "drop.fill")
                                    .font(.title3)
                                    .foregroundStyle(Theme.water)
                            )
                    }
                    .buttonStyle(.plain)
                    Text("喝了水")
                        .font(.caption2)
                        .foregroundStyle(Theme.mute)
                }

                // 核心 +1 (香槟金大圈)
                VStack(spacing: 6) {
                    Button {
                        showingDrinks = true
                    } label: {
                        Circle()
                            .stroke(Theme.gold, lineWidth: 1.5)
                            .background(Circle().fill(Theme.gold.opacity(0.12)))
                            .frame(width: 76, height: 76)
                            .overlay(
                                Text("+1")
                                    .font(.system(size: 28, weight: .light, design: .serif))
                                    .foregroundStyle(Theme.gold)
                            )
                    }
                    .buttonStyle(.plain)
                    Text("记一杯 / 纠正")
                        .font(.caption2)
                        .foregroundStyle(Theme.mute)
                }

                // 收杯
                VStack(spacing: 6) {
                    Button {
                        confirmingEnd = true
                    } label: {
                        Circle()
                            .fill(store.snapshot?.intensity == .over || store.snapshot?.intensity == .due ? Theme.wine : Theme.gold)
                            .frame(width: 58, height: 58)
                            .overlay(
                                Text("收")
                                    .font(.system(size: 20, weight: .medium, design: .serif))
                                    .foregroundStyle(Theme.bg)
                            )
                    }
                    .buttonStyle(.plain)
                    Text("我收了")
                        .font(.caption2)
                        .foregroundStyle(Theme.mute)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func lines(_ session: Session) -> [LogLine] {
        var items: [LogLine] = []

        for drink in session.drinks {
            items.append(
                LogLine(
                    id: drink.id,
                    at: drink.at,
                    text: "\(drink.name) · \(Format.units(drink.grams / Pace.gramsPerStandard)) 标准杯",
                    color: Theme.cream
                )
            )
        }
        for water in session.waters {
            items.append(
                LogLine(
                    id: water.id,
                    at: water.at,
                    text: "💧 喝了一杯水",
                    color: Theme.water
                )
            )
        }
        // 列出被自动估算纳入的提醒节点
        for prompt in session.prompts where prompt.reply == nil && prompt.at <= store.now {
            items.append(
                LogLine(
                    id: prompt.id,
                    at: prompt.at,
                    text: "◌ 节奏估算节点 · 约 \(Format.units(prompt.estimate)) 标准杯",
                    color: Theme.gold.opacity(0.8)
                )
            )
        }

        return items.sorted { $0.at > $1.at }
    }
}

// 腕表刻度圆环绘图组件
struct DialTicksView: View {
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            Path { path in
                for i in 0..<60 {
                    let angle = Double(i) * 6.0 * .pi / 180.0
                    let isMajor = i % 5 == 0
                    let r1: CGFloat = 118
                    let r2: CGFloat = isMajor ? 111 : 115
                    let p1 = CGPoint(x: center.x + r1 * sin(angle), y: center.y - r1 * cos(angle))
                    let p2 = CGPoint(x: center.x + r2 * sin(angle), y: center.y - r2 * cos(angle))
                    path.move(to: p1)
                    path.addLine(to: p2)
                }
            }
            .stroke(Theme.cream.opacity(0.18), lineWidth: 1)
        }
    }
}

// MARK: - Drink Sheet (支持同上一杯快捷与回溯补记时间)

struct DrinkSheet: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var tab = 0
    @State private var customName = ""
    @State private var customVolume: Double = 330
    @State private var customAbv: Double = 5.0
    @State private var minutesAgo: Int = 0

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var targetLogTime: Date {
        Date.now.addingTimeInterval(-Double(minutesAgo * 60))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("记录这杯")
                    .font(.system(size: 28, weight: .light, design: .serif))
                    .foregroundStyle(Theme.cream)
                Spacer()
                Picker("类型", selection: $tab) {
                    Text("预设酒饮").tag(0)
                    Text("自选酒饮").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            .padding(.top, 14)

            // 时间回溯快捷选择器：解决酒桌上忘记及时掏手机的场景
            HStack(spacing: 8) {
                Text("时间:")
                    .font(.caption)
                    .foregroundStyle(Theme.mute)
                ForEach([0, 10, 20, 30], id: \.self) { min in
                    Button(min == 0 ? "刚才" : "\(min)分钟前") {
                        minutesAgo = min
                    }
                    .font(.caption2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(minutesAgo == min ? Theme.gold : Theme.raised))
                    .foregroundStyle(minutesAgo == min ? Theme.bg : Theme.mute)
                }
            }

            // 同上一杯快捷大卡片
            if let lastDrink = store.active?.drinks.last {
                Button {
                    store.logDrink(preset: lastDrink.preset, at: targetLogTime)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("同上一杯：\(lastDrink.name)")
                                .font(.headline)
                                .foregroundStyle(Theme.cream)
                            Text("\(lastDrink.detail) · 约 \(Format.units(lastDrink.grams / Pace.gramsPerStandard)) 标准杯")
                                .font(.caption)
                                .foregroundStyle(Theme.gold)
                        }
                        Spacer()
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Theme.gold)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.gold.opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            if tab == 0 {
                presetGrid
            } else {
                customDrinkForm
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
    }

    private var presetGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Pace.presets) { preset in
                Button {
                    store.logDrink(preset: preset, at: targetLogTime)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(preset.name)
                            .font(.system(.title3, design: .serif))
                        Text(preset.detail)
                            .font(.subheadline)
                            .foregroundStyle(Theme.mute)
                        Text("约 \(Format.units(preset.standardDrinks)) 标准杯")
                            .font(.caption)
                            .foregroundStyle(Theme.gold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Theme.raised))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.cream)
            }
        }
    }

    private var customDrinkForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("酒品名称（可选，如精酿IPA）", text: $customName)
                .textFieldStyle(.plain)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.raised))
                .foregroundStyle(Theme.cream)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("容量")
                        .foregroundStyle(Theme.mute)
                    Spacer()
                    Text("\(Int(customVolume)) ml")
                        .foregroundStyle(Theme.cream)
                        .font(.body.monospacedDigit())
                }
                Slider(value: $customVolume, in: 20...1000, step: 10)
                    .tint(Theme.gold)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("酒精度 (ABV)")
                        .foregroundStyle(Theme.mute)
                    Spacer()
                    Text(String(format: "%.1f %%", customAbv))
                        .foregroundStyle(Theme.cream)
                        .font(.body.monospacedDigit())
                }
                Slider(value: $customAbv, in: 1...65, step: 0.5)
                    .tint(Theme.gold)
            }

            let calcGrams = customVolume * (customAbv / 100.0) * 0.8
            let calcUnits = calcGrams / Pace.gramsPerStandard

            HStack {
                Text("折合约 \(Format.units(calcUnits)) 标准杯")
                    .font(.headline)
                    .foregroundStyle(Theme.gold)
                Spacer()
                Text("纯酒精约 \(Int(calcGrams))g")
                    .font(.caption)
                    .foregroundStyle(Theme.mute)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.raised))

            FillButton(title: "确认记录", color: Theme.gold) {
                store.logCustom(name: customName, volumeMl: customVolume, abv: customAbv, at: targetLogTime)
                dismiss()
            }
        }
    }
}

// MARK: - Summary Sheet (数据复盘)

struct SummarySheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: Session

    var body: some View {
        let end = session.endedAt ?? .now
        let outcome = session.outcome(at: end)
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(outcome.title)
                    .font(.system(size: 38, weight: .light, design: .serif))
                    .foregroundStyle(outcome == .crossed ? Theme.wine : Theme.cream)
                Text(outcome.detail)
                    .font(.body)
                    .foregroundStyle(Theme.mute)
            }

            VStack(spacing: 12) {
                statRow(title: "饮酒时长", value: Format.clock(session.duration))
                if session.overtimeMinutes > 0 {
                    Divider().background(Theme.faint)
                    statRow(title: "比预定多坐了", value: "\(session.overtimeMinutes) 分钟")
                }
                Divider().background(Theme.faint)
                statRow(title: "总摄入量", value: "\(Format.units(session.units(at: end))) 标准杯")
                Divider().background(Theme.faint)
                statRow(title: "其中手动记录", value: "\(session.drinks.count) 次 · \(Format.units(session.confirmedUnits(at: end))) 标准杯")
                Divider().background(Theme.faint)
                statRow(title: "补水次数", value: "\(session.waters.count) 次")
            }
            .padding(18)
            .background(CardChrome())

            if session.waters.count >= session.drinks.count && !session.drinks.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.water)
                    Text("整场水酒穿插及时，给身体留足了恢复缓冲。")
                        .font(.footnote)
                        .foregroundStyle(Theme.cream)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.water.opacity(0.12)))
            }

            Spacer()
            FillButton(title: "完成复盘", color: Theme.gold) {
                dismiss()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Theme.mute)
            Spacer()
            Text(value)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.cream)
        }
    }
}

// MARK: - Components

struct PlanCard: View {
    let plan: Plan
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.name)
                            .font(.system(.title2, design: .serif))
                            .foregroundStyle(Theme.cream)
                        if isSelected {
                            Text("上次所用")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.gold.opacity(0.2)))
                                .foregroundStyle(Theme.gold)
                        }
                    }
                    Text(plan.detail)
                        .font(.subheadline)
                        .foregroundStyle(Theme.mute)
                    Text("警戒线 \(plan.hardLimit) · 初始建议间隔 \(plan.minIntervalMinutes) 分钟")
                        .font(.caption)
                        .foregroundStyle(Theme.mute)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(Theme.gold)
            }
            .padding(18)
            .background(CardChrome())
        }
        .buttonStyle(.plain)
    }
}

struct HistoryRow: View {
    let session: Session
    var onDelete: () -> Void

    var body: some View {
        let end = session.endedAt ?? session.startedAt
        let outcome = session.outcome(at: end)
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Format.day(session.startedAt)) · \(Format.shortTime(session.startedAt))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.mute)
                Text("\(Format.clock(session.duration)) · \(Format.units(session.units(at: end))) 标准杯")
                    .font(.body)
                    .foregroundStyle(Theme.cream)
            }
            Spacer()
            Text(outcome.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(outcome == .crossed ? Theme.wine : (outcome == .empty ? Theme.mute : Theme.sage))
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(Theme.mute.opacity(0.6))
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(CardChrome())
    }
}

struct SettingStepper: View {
    let title: String
    let value: String
    let range: ClosedRange<Int>
    let step: Int
    let valueBinding: Binding<Int>

    var body: some View {
        Stepper(value: valueBinding, in: range, step: step) {
            HStack {
                Text(title)
                    .foregroundStyle(Theme.mute)
                Spacer()
                Text(value)
                    .foregroundStyle(Theme.cream)
                    .monospacedDigit()
            }
        }
        .foregroundStyle(Theme.cream)
    }
}

struct FillButton: View {
    var title: String
    var systemImage: String?
    var color: Color
    var foreground: Color = Theme.ink
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(foreground)
            .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct CupMark: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.gold, lineWidth: 1.5)
            Image(systemName: "wineglass")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Theme.cream)
        }
        .frame(width: 44, height: 44)
    }
}

struct CardChrome: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Theme.raised)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.faint, lineWidth: 1)
            )
    }
}

private struct LogLine: Identifiable {
    var id: UUID
    var at: Date
    var text: String
    var color: Color
}
