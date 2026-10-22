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
    @State private var showSecretSignature = false

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                beveragePickerSection
                planSelectionSection
                startSessionSection
                settingsAndPreferencesSection
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
            Text("开喝后放下手机。无需频繁掏出记录，app 按节拍主动推测提醒，随时间与酒意递增密度，守护从容。")
                .font(.subheadline)
                .lineSpacing(4)
                .foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 10)
    }

    // 今晚喝什么选择器
    private var beveragePickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今晚主要喝什么")
                .font(.system(.subheadline, design: .serif).weight(.medium))
                .foregroundStyle(Theme.cream)

            HStack(spacing: 8) {
                ForEach(BeverageCategory.allCases) { cat in
                    let isSelected = store.settings.selectedBeverageCategory == cat
                    Button {
                        store.settings.selectedBeverageCategory = cat
                        store.normalizeAndSaveSettings()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: cat.icon)
                                .font(.caption)
                            Text(cat.name)
                                .font(.caption.weight(isSelected ? .semibold : .regular))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(isSelected ? Theme.gold : Theme.raised))
                        .foregroundStyle(isSelected ? Theme.ink : Theme.cream)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // 方案选择区域（纯选择，绝不自动开始）
    private var planSelectionSection: some View {
        let cat = store.settings.selectedBeverageCategory
        return VStack(alignment: .leading, spacing: 12) {
            Text("设定目标场景")
                .font(.system(.subheadline, design: .serif).weight(.medium))
                .foregroundStyle(Theme.cream)

            VStack(spacing: 10) {
                PlanSelectionCard(
                    title: "小酌",
                    badge: Plan.light.displayDetail(for: cat),
                    detail: "轻松微醺，适度怡情",
                    isSelected: store.settings.selectedPlanID == Plan.light.id
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.settings.selectedPlanID = Plan.light.id
                        store.normalizeAndSaveSettings()
                    }
                }

                PlanSelectionCard(
                    title: "聚餐",
                    badge: Plan.dinner.displayDetail(for: cat),
                    detail: "朋友聚会或宴请，从容拉长节拍",
                    isSelected: store.settings.selectedPlanID == Plan.dinner.id
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.settings.selectedPlanID = Plan.dinner.id
                        store.normalizeAndSaveSettings()
                    }
                }

                PlanSelectionCard(
                    title: "自定义",
                    badge: store.settings.customPlan.displayDetail(for: cat),
                    detail: "自定建议停杯线与预计时长",
                    isSelected: store.settings.selectedPlanID == "custom"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.settings.selectedPlanID = "custom"
                        store.normalizeAndSaveSettings()
                    }
                }
            }

            if store.settings.selectedPlanID == "custom" {
                customSettingsCard
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var customSettingsCard: some View {
        let cat = store.settings.selectedBeverageCategory
        return VStack(spacing: 14) {
            SettingStepper(
                title: "建议停杯线",
                value: cat.formatPhysical(from: store.settings.softLimit),
                range: 1...20,
                step: 1,
                valueBinding: Binding(
                    get: { Int(store.settings.softLimit.rounded()) },
                    set: { store.settings.softLimit = Double($0) }
                )
            )
            SettingStepper(
                title: "严格警戒线",
                value: cat.formatPhysical(from: store.settings.hardLimit),
                range: Int(store.settings.softLimit.rounded())...25,
                step: 1,
                valueBinding: Binding(
                    get: { Int(store.settings.hardLimit.rounded()) },
                    set: { store.settings.hardLimit = Double($0) }
                )
            )
            SettingStepper(
                title: "预定时长",
                value: Format.minutes(store.settings.plannedMinutes),
                range: 30...360,
                step: 15,
                valueBinding: Bindable(store).settings.plannedMinutes
            )
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.faint, lineWidth: 1))
        .onChange(of: store.settings) { _, _ in
            store.normalizeAndSaveSettings()
        }
    }

    // 真正开始饮酒的唯一主操作入口
    private var startSessionSection: some View {
        let plan = store.settings.selectedPlan
        let cat = store.settings.selectedBeverageCategory
        return VStack(spacing: 8) {
            FillButton(title: "开启今晚 · \(plan.name)", color: Theme.gold) {
                store.start(plan, category: cat)
            }
            Text("首条提醒 30 分钟 · 越线后每 10 分钟强提醒")
                .font(.caption2)
                .foregroundStyle(Theme.mute)
        }
        .padding(.top, 4)
    }

    // 独立解耦的提醒设置区块
    private var settingsAndPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("提醒音效与偏好")
                .font(.system(.subheadline, design: .serif).weight(.medium))
                .foregroundStyle(Theme.cream)

            VStack(alignment: .leading, spacing: 14) {
                soundPickerSection

                Button {
                    store.scheduleTestNotification()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bell.badge.waveform.fill")
                            .font(.caption)
                        Text("测试 5 秒后通知与声音")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(Theme.gold)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.gold.opacity(0.12)))
                }
                .buttonStyle(.plain)

                Divider().background(Theme.faint)

                Toggle(isOn: Bindable(store).settings.estimateWhenSilent) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("未回应时自动按节奏推测")
                            .foregroundStyle(Theme.cream)
                        Text("酒桌不方便拿手机时，保持智能节拍并在界面清晰标明推测")
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
            }
            .padding(18)
            .background(CardChrome())
        }
    }

    private var soundPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("主动提醒铃声")
                    .foregroundStyle(Theme.cream)
                Spacer()
                Text("点击可试听")
                    .font(.caption2)
                    .foregroundStyle(Theme.mute)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(NotificationSoundOption.allCases) { opt in
                        let isSelected = store.settings.notificationSound == opt
                        Button {
                            store.settings.notificationSound = opt
                            store.previewSound(opt)
                            store.normalizeAndSaveSettings()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: isSelected ? "speaker.wave.2.fill" : "play.circle")
                                    .font(.caption)
                                Text(opt.displayName)
                                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? Theme.gold.opacity(0.2) : Theme.raised))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Theme.gold : Theme.faint, lineWidth: 1))
                            .foregroundStyle(isSelected ? Theme.gold : Theme.cream)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
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
        Text("标准杯基于世界卫生组织约 14 克纯乙醇换算。本应用提供自律提醒，无法测算实际血液酒精浓度，酒后严禁驾车。")
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

                    // 切换酒种菜单
                    Menu {
                        ForEach(BeverageCategory.allCases) { cat in
                            Button {
                                store.switchBeverageCategory(cat)
                            } label: {
                                Label(cat.name, systemImage: cat.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(store.active?.beverageCategory.name ?? "啤酒")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9))
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.gold.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.raised))
                    }

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

    // 双环腕表表盘：外环时间，内环杯量
    private func watchDial(_ snap: PaceSnapshot, session: Session) -> some View {
        let soft = max(session.softLimit, 1.0)
        let hard = max(session.hardLimit, session.softLimit)
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

            // 中心大字数据：通俗现实物理量 + 标准杯双轨显示
            VStack(spacing: 2) {
                if snap.estimatedUnits > 0 {
                    Text(isEstimatedOnly ? "节 奏 推 测" : "含 推 测")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(3)
                        .foregroundStyle(Theme.gold)
                } else {
                    Text("当 前 摄 入")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(3)
                        .foregroundStyle(Theme.mute)
                }

                // 大字：现实物理量
                Text(snap.physicalText)
                    .font(.system(size: 42, weight: .light, design: .serif))
                    .foregroundStyle(Theme.cream)
                    .contentTransition(.numericText())

                // 小字：对应酒品目标进度
                let softPhysical = session.beverageCategory.formatPhysical(from: session.softLimit)
                Text("\(snap.physicalText) / 建议 \(softPhysical)")
                    .font(.caption2)
                    .foregroundStyle(Theme.mute)
                    .padding(.top, 2)
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

            if snap.intensity == .over {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .font(.caption2)
                    Text("持续强提醒中 · 每 10 分钟一次直到收杯")
                        .font(.caption.bold())
                }
                .foregroundStyle(Theme.wine)
                .padding(.top, 4)
            } else if let next = snap.nextPrompt {
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

                // 核心 +1 (支持所选酒种快速记一份)
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
                    Text("记 1 \(store.active?.beverageCategory.unitName ?? "份")")
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
                    text: "\(drink.name) · \(drink.detail)",
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
        // 列出被节奏推测纳入的节点，展示清晰的人话语义，绝不显示 0.44、0.82 这类碎数
        for prompt in session.prompts where prompt.reply == nil && prompt.at <= store.now {
            let cat = session.beverageCategory
            let text = prompt.semanticText ?? "◌ 节奏推测 · 约 \(cat.formatPhysical(from: prompt.projectedUnits))"
            items.append(
                LogLine(
                    id: prompt.id,
                    at: prompt.at,
                    text: text,
                    color: prompt.level == .over ? Theme.wine : Theme.gold.opacity(0.85)
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
                Text("记录这一份")
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
                            Text("同上一份：\(lastDrink.name)")
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
            TextField("酒品名称，如精酿IPA", text: $customName)
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
                    Text("酒精度 ABV")
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
                    .font(.caption)
                    .foregroundStyle(Theme.gold)
                Spacer()
                Button("添加这杯") {
                    store.logCustom(name: customName, volumeMl: customVolume, abv: customAbv, at: targetLogTime)
                    dismiss()
                }
                .font(.subheadline.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.gold))
                .foregroundStyle(Theme.bg)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.raised))
    }
}

// MARK: - Plan Selection Card

struct PlanSelectionCard: View {
    let title: String
    let badge: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(.title3, design: .serif).weight(.medium))
                            .foregroundStyle(isSelected ? Theme.gold : Theme.cream)
                        Text(badge)
                            .font(.subheadline)
                            .foregroundStyle(isSelected ? Theme.cream : Theme.mute)
                    }
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Theme.mute.opacity(0.85))
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.gold : Theme.mute.opacity(0.35))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Theme.raised : Theme.surface.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Theme.gold : Theme.faint, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CardChrome: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Theme.raised)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Theme.faint, lineWidth: 1)
            )
    }
}

struct HistoryRow: View {
    let session: Session
    let onDelete: () -> Void

    var body: some View {
        let outcome = session.outcome(at: session.endedAt ?? Date())
        let cat = session.beverageCategory

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.planName)
                        .font(.headline)
                        .foregroundStyle(Theme.cream)
                    Text("·")
                        .foregroundStyle(Theme.mute)
                    Text(cat.name)
                        .font(.caption)
                        .foregroundStyle(Theme.gold)
                    Text("·")
                        .foregroundStyle(Theme.mute)
                    Text(Format.day(session.startedAt))
                        .font(.caption)
                        .foregroundStyle(Theme.mute)
                }
                Text("\(cat.formatPhysical(from: session.units(at: session.endedAt ?? Date()))) · \(Format.units(session.units(at: session.endedAt ?? Date()))) 标准杯 · 时长 \(Format.minutes(Int(session.duration / 60)))")
                    .font(.caption)
                    .foregroundStyle(Theme.mute)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(outcome.title)
                    .font(.caption.bold())
                    .foregroundStyle(outcome == .crossed ? Theme.wine : Theme.sage)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(Theme.mute.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
    }
}

struct SummarySheet: View {
    let session: Session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let outcome = session.outcome(at: session.endedAt ?? Date())
        let cat = session.beverageCategory
        let units = session.units(at: session.endedAt ?? Date())

        VStack(spacing: 20) {
            Capsule()
                .fill(Theme.mute.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 10)

            VStack(spacing: 6) {
                Text(outcome.title)
                    .font(.system(size: 32, weight: .light, design: .serif))
                    .foregroundStyle(Theme.cream)
                Text(outcome.detail)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.mute)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                HStack {
                    Text("主要酒饮")
                    Spacer()
                    Text(cat.name)
                        .foregroundStyle(Theme.gold)
                }
                HStack {
                    Text("实际摄入总量")
                    Spacer()
                    Text("\(cat.formatPhysical(from: units)) · \(Format.units(units)) 标准杯")
                        .foregroundStyle(Theme.cream)
                }
                HStack {
                    Text("饮酒时长")
                    Spacer()
                    Text(Format.minutes(Int(session.duration / 60)))
                        .foregroundStyle(Theme.cream)
                }
                HStack {
                    Text("喝水记录")
                    Spacer()
                    Text("\(session.waters.count) 杯")
                        .foregroundStyle(Theme.water)
                }
            }
            .font(.subheadline)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.raised))
            .padding(.horizontal, 24)

            Spacer()

            FillButton(title: "知道了", color: Theme.gold) {
                dismiss()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
}

struct SettingStepper: View {
    let title: String
    let value: String
    let range: ClosedRange<Int>
    let step: Int
    @Binding var valueBinding: Int

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(Theme.cream)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.gold)
            Stepper("", value: $valueBinding, in: range, step: step)
                .labelsHidden()
        }
    }
}

struct FillButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .serif))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 16).fill(color))
                .foregroundStyle(Theme.bg)
        }
        .buttonStyle(.plain)
    }
}

struct CupMark: View {
    var body: some View {
        Image(systemName: "wineglass")
            .font(.system(size: 28, weight: .light))
            .foregroundStyle(Theme.gold)
    }
}

struct LogLine: Identifiable {
    let id: UUID
    let at: Date
    let text: String
    let color: Color
}
