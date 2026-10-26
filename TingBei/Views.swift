import SwiftUI
import UIKit

// MARK: - Theme (停杯 2.0：朗格黑金精密腕表与私人酒廊美学)

enum Theme {
    static let bg = Color(red: 0.035, green: 0.03, blue: 0.026)        // 深邃曜石黑 #090807
    static let raised = Color(red: 0.09, green: 0.08, blue: 0.07)      // 丝绒暗金底 #171412
    static let surface = Color(red: 0.135, green: 0.12, blue: 0.105)   // 机械夹板灰金 #221E1B
    static let cream = Color(red: 0.95, green: 0.92, blue: 0.87)       // 象牙银白 #F2EBE0
    static let mute = Color(red: 0.94, green: 0.90, blue: 0.84).opacity(0.54)
    static let faint = Color(red: 0.94, green: 0.90, blue: 0.84).opacity(0.11)
    static let gold = Color(red: 0.83, green: 0.70, blue: 0.47)        // 朗格香槟金 #D4B278
    static let goldBright = Color(red: 0.95, green: 0.85, blue: 0.65)  // 高光亮香槟金
    static let wine = Color(red: 0.82, green: 0.27, blue: 0.23)        // 波尔多红宝石 #D1453B
    static let sage = Color(red: 0.56, green: 0.71, blue: 0.54)        // 翡翠鼠尾草绿
    static let water = Color(red: 0.44, green: 0.72, blue: 0.92)       // 蓝宝石冰水色
    static let ink = Color(red: 0.05, green: 0.04, blue: 0.03)

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

    static var bezelGradient: LinearGradient {
        LinearGradient(
            colors: [
                goldBright.opacity(0.45),
                gold.opacity(0.15),
                Color.white.opacity(0.04),
                gold.opacity(0.28)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var subtleCardStroke: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.16),
                Color.white.opacity(0.03),
                gold.opacity(0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Root View

struct RootView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var store = store
        ZStack(alignment: .top) {
            NightBackground(cue: store.snapshot?.cue)
            if store.active != nil {
                SessionView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                HomeView()
                    .transition(.opacity)
            }

            // 全局顶部黑金悬浮胶囊提示（带高光倒角）
            if let toast = store.toast {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle")
                        .font(.caption2.bold())
                        .foregroundStyle(Theme.goldBright)
                    Text(toast)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.cream)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Theme.surface.opacity(0.96))
                        .shadow(color: .black.opacity(0.55), radius: 16, y: 6)
                )
                .overlay(Capsule().stroke(Theme.bezelGradient, lineWidth: 1))
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.smooth(duration: 0.35), value: store.active != nil)
        .animation(.smooth(duration: 0.28), value: store.toast)
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
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
        }
    }
}

// MARK: - Night Background (环境呼吸氛围光)

struct NightBackground: View {
    var cue: Cue?

    var body: some View {
        let heat = heat(for: cue)
        ZStack {
            Theme.bg
            RadialGradient(
                colors: [
                    Theme.gold.opacity(0.14 * (1 - heat) + 0.03),
                    Theme.wine.opacity(0.38 * heat),
                    .clear,
                ],
                center: .top,
                startRadius: 5,
                endRadius: 540
            )
            RadialGradient(
                colors: [
                    Theme.gold.opacity(0.05),
                    .clear,
                ],
                center: .bottom,
                startRadius: 20,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
        .animation(.smooth(duration: 0.8), value: cue)
    }

    private func heat(for cue: Cue?) -> Double {
        switch cue {
        case nil, .calm: 0
        case .settle: 0.12
        case .hurried: 0.38
        case .near: 0.55
        case .due: 0.78
        case .over: 1.0
        }
    }
}

// MARK: - Home View (私人酒廊与机械拨盘台签)

struct HomeView: View {
    @Environment(SessionStore.self) private var store
    @State private var showSecretSignature = false
    @State private var isPreferencesExpanded = false
    @State private var showAllHistory = false

    var body: some View {
        @Bindable var store = store
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                editorialHeader
                vesselGallerySection
                horologyPlanSection
                launchCrownSection
                preferencesConsoleSection
                if !store.history.isEmpty {
                    sommelierJournalSection
                }
                legalFootnote
                if showSecretSignature || (store.signatureStatus.daysRemaining != nil && store.signatureStatus.daysRemaining! <= 2) {
                    signatureBadge
                }
                if store.saveFailed {
                    Text("本地记录暂未写入成功，请检查存储空间。")
                        .font(.footnote)
                        .foregroundStyle(Theme.wine)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
    }

    // 1. 杂志刊头式极简抬头
    private var editorialHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                HStack(spacing: 12) {
                    HorologyEmblem()
                        .onLongPressGesture(minimumDuration: 1.5) {
                            withAnimation {
                                showSecretSignature.toggle()
                            }
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("停 杯")
                            .font(.system(size: 34, weight: .light, design: .serif))
                            .foregroundStyle(Theme.cream)
                        Text("MINDFUL PACING · 席间节律副驾")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .tracking(2.0)
                            .foregroundStyle(Theme.gold)
                    }
                }
                Spacer()
                // 个人历史节制勋章
                let nonEmpty = store.history.filter { $0.outcome(at: $0.endedAt ?? Date()) != .empty }
                if !nonEmpty.isEmpty {
                    let withinCount = nonEmpty.filter { $0.outcome(at: $0.endedAt ?? Date()) != .crossed }.count
                    let rate = Int((Double(withinCount) / Double(nonEmpty.count) * 100).rounded())
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(rate)%")
                            .font(.system(size: 18, weight: .regular, design: .serif).monospacedDigit())
                            .foregroundStyle(Theme.goldBright)
                        Text("历史收杯率")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.mute)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.raised)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.subtleCardStroke, lineWidth: 1))
                    )
                }
            }

            Text("懂得节制，方得从容。开席后放下手机，系统随酒意自动递增提醒密度。")
                .font(.caption)
                .foregroundStyle(Theme.mute)
                .padding(.top, 2)
        }
    }

    // 2. 酒器橱窗矩阵（2x2 金属倒角器物卡）
    private var vesselGallerySection: some View {
        let period = Format.sessionPeriodPrompt(at: store.now)
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(period.question)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.cream)
                Spacer()
                Text("WHO 14g 乙醇基准折算")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.mute)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(BeverageCategory.allCases) { cat in
                    let isSelected = store.settings.selectedBeverageCategory == cat
                    Button {
                        let oldCat = store.settings.selectedBeverageCategory
                        if oldCat != cat {
                            let softCount = max(1, Int(oldCat.physicalValue(from: store.settings.softLimit).rounded()))
                            let hardCount = max(softCount, Int(oldCat.physicalValue(from: store.settings.hardLimit).rounded()))
                            withAnimation(.smooth(duration: 0.22)) {
                                store.settings.selectedBeverageCategory = cat
                                store.settings.softLimit = Double(softCount) * cat.standardUnitsPerUnit
                                store.settings.hardLimit = Double(hardCount) * cat.standardUnitsPerUnit
                                store.normalizeAndSaveSettings()
                            }
                            store.triggerHaptic(.soft)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Theme.gold.opacity(0.22) : Theme.surface)
                                    .frame(width: 36, height: 36)
                                Image(systemName: cat.icon)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(isSelected ? Theme.goldBright : Theme.mute)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(cat.name)
                                        .font(.system(size: 15, weight: isSelected ? .semibold : .regular, design: .serif))
                                        .foregroundStyle(isSelected ? Theme.cream : Theme.cream.opacity(0.85))
                                    Text("(\(cat.unitName))")
                                        .font(.system(size: 11))
                                        .foregroundStyle(isSelected ? Theme.gold : Theme.mute)
                                }
                                Text(cat.specSubtitle)
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(Theme.mute)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    isSelected
                                        ? LinearGradient(colors: [Theme.surface, Theme.raised], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(colors: [Theme.raised.opacity(0.75), Theme.raised.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? Theme.gold : Color.white.opacity(0.06), lineWidth: isSelected ? 1.2 : 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // 3. 三联式机械档位方案盘 + 实时节拍时间轴预览
    private var horologyPlanSection: some View {
        let cat = store.settings.selectedBeverageCategory
        let activePlan = store.settings.selectedPlan
        let softPhysical = cat.formatPhysical(from: activePlan.softLimit)
        let hardPhysical = cat.formatPhysical(from: activePlan.hardLimit)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("席间节拍档位")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.cream)
                Spacer()
                Text("可随时在席间动态调整")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.mute)
            }

            // 三联横向档位卡
            HStack(spacing: 10) {
                PlanDialTile(
                    title: "小酌",
                    subtitle: "微醺怡情",
                    metric: Plan.light.displayDetail(for: cat),
                    isSelected: store.settings.selectedPlanID == Plan.light.id
                ) {
                    withAnimation(.smooth(duration: 0.22)) {
                        store.settings.selectedPlanID = Plan.light.id
                        store.normalizeAndSaveSettings()
                    }
                    store.triggerHaptic(.soft)
                }

                PlanDialTile(
                    title: "聚餐",
                    subtitle: "欢聚畅饮",
                    metric: Plan.dinner.displayDetail(for: cat),
                    isSelected: store.settings.selectedPlanID == Plan.dinner.id
                ) {
                    withAnimation(.smooth(duration: 0.22)) {
                        store.settings.selectedPlanID = Plan.dinner.id
                        store.normalizeAndSaveSettings()
                    }
                    store.triggerHaptic(.soft)
                }

                PlanDialTile(
                    title: "自定义",
                    subtitle: "专属刻度",
                    metric: store.settings.customPlan.displayDetail(for: cat),
                    isSelected: store.settings.selectedPlanID == "custom"
                ) {
                    withAnimation(.smooth(duration: 0.22)) {
                        store.settings.selectedPlanID = "custom"
                        store.normalizeAndSaveSettings()
                    }
                    store.triggerHaptic(.soft)
                }
            }

            // 选中方案的机械刻度预览条（直观解释这套逻辑是怎么运作的）
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("建议停杯线")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.mute)
                        Text(softPhysical)
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(Theme.goldBright)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider().frame(height: 24).background(Theme.faint)

                    VStack(alignment: .center, spacing: 2) {
                        Text("严格警戒线")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.mute)
                        Text(hardPhysical)
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(Theme.wine)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    Divider().frame(height: 24).background(Theme.faint)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("预定席间时长")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.mute)
                        Text(Format.minutes(activePlan.plannedMinutes))
                            .font(.system(size: 15, weight: .medium, design: .serif))
                            .foregroundStyle(Theme.cream)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // 渐进提醒阶梯示意轨迹
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.gold)
                    Text("节拍递进：首询 30m ➔ 巡航 25m ➔ 临线 20m ➔ 到线 15m ➔ 越界 10m 强催")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.mute)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)

                if store.settings.selectedPlanID == "custom" {
                    Divider().background(Theme.faint)
                    customSettingsSliders
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.raised)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.subtleCardStroke, lineWidth: 1))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var customSettingsSliders: some View {
        let cat = store.settings.selectedBeverageCategory
        let softPhysicalCount = max(1, Int(cat.physicalValue(from: store.settings.softLimit).rounded()))
        let hardPhysicalCount = max(softPhysicalCount, Int(cat.physicalValue(from: store.settings.hardLimit).rounded()))

        return VStack(spacing: 12) {
            SettingStepper(
                title: "调整建议停杯线",
                value: "\(softPhysicalCount) \(cat.unitName)",
                range: 1...20,
                step: 1,
                valueBinding: Binding(
                    get: { softPhysicalCount },
                    set: { newCount in
                        let newSoft = Double(newCount) * cat.standardUnitsPerUnit
                        store.settings.softLimit = newSoft
                        if store.settings.hardLimit < newSoft {
                            store.settings.hardLimit = newSoft
                        }
                    }
                )
            )
            SettingStepper(
                title: "调整严格警戒线",
                value: "\(hardPhysicalCount) \(cat.unitName)",
                range: softPhysicalCount...25,
                step: 1,
                valueBinding: Binding(
                    get: { hardPhysicalCount },
                    set: { newCount in
                        store.settings.hardLimit = Double(newCount) * cat.standardUnitsPerUnit
                    }
                )
            )
            SettingStepper(
                title: "调整预定时长",
                value: Format.minutes(store.settings.plannedMinutes),
                range: 30...360,
                step: 15,
                valueBinding: Bindable(store).settings.plannedMinutes
            )
        }
        .onChange(of: store.settings) { _, _ in
            store.normalizeAndSaveSettings()
        }
    }

    // 4. 皇家表冠级启动按钮
    private var launchCrownSection: some View {
        let plan = store.settings.selectedPlan
        let cat = store.settings.selectedBeverageCategory
        let period = Format.sessionPeriodPrompt(at: store.now)

        return Button {
            store.start(plan, category: cat)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("\(period.actionPrefix) · \(plan.name)（\(cat.name)）")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .tracking(1)
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [Theme.goldBright, Theme.gold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                }
                .shadow(color: Theme.gold.opacity(0.28), radius: 14, y: 6)
            )
        }
        .buttonStyle(.plain)
    }

    // 5. 一体式折叠声学与偏好控制台（同容器展开，消除独立卡片位移重影）
    private var preferencesConsoleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPreferencesExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.surface)
                            .frame(width: 32, height: 32)
                        Image(systemName: "bell.and.waves.left.and.right.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.gold)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("声学提醒与静默推测设置")
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundStyle(Theme.cream)
                        Text("铃声：\(store.settings.notificationSound.displayName) · \(store.settings.estimateWhenSilent ? "未回应自动推测" : "仅手动记杯")\(store.settings.keepScreenOn ? " · 屏幕常亮" : "")")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.mute)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.gold)
                        .rotationEffect(.degrees(isPreferencesExpanded ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isPreferencesExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider().background(Theme.faint)

                    soundPickerSection

                    Button {
                        store.scheduleTestNotification()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bell.badge.waveform.fill")
                                .font(.caption)
                            Text("发送 5 秒后锁屏测试通知")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(Theme.goldBright)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.gold.opacity(0.14)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.gold.opacity(0.35), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)

                    Divider().background(Theme.faint)

                    Toggle(isOn: Bindable(store).settings.estimateWhenSilent) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("未回应时自动按节奏推测")
                                .font(.subheadline)
                                .foregroundStyle(Theme.cream)
                            Text("酒桌不便看手机时自动推进节拍，盘中虚线显示并可随时一键消除")
                                .font(.caption2)
                                .foregroundStyle(Theme.mute)
                        }
                    }
                    .tint(Theme.gold)

                    Toggle(isOn: Bindable(store).settings.keepScreenOn) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("席间保持表盘常亮")
                                .font(.subheadline)
                                .foregroundStyle(Theme.cream)
                            Text("适合将手机置于桌面充当腕表座钟时开启")
                                .font(.caption2)
                                .foregroundStyle(Theme.mute)
                        }
                    }
                    .tint(Theme.gold)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .padding(.top, 2)
                .onChange(of: store.settings.estimateWhenSilent) { _, _ in
                    store.normalizeAndSaveSettings()
                }
                .onChange(of: store.settings.keepScreenOn) { _, _ in
                    store.normalizeAndSaveSettings()
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.raised)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.subtleCardStroke, lineWidth: 1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var soundPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("主动提醒定制音色")
                    .font(.subheadline)
                    .foregroundStyle(Theme.cream)
                Spacer()
                Text("点按即刻试听")
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
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? Theme.gold.opacity(0.22) : Theme.surface))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Theme.gold : Theme.faint, lineWidth: 1))
                            .foregroundStyle(isSelected ? Theme.goldBright : Theme.cream)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // 6. 侍酒师式历史手账
    private var sommelierJournalSection: some View {
        let allReversed = Array(store.history.reversed())
        let displayed = showAllHistory ? allReversed : Array(allReversed.prefix(4))

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("席间手账")
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.cream)
                Spacer()
                if store.history.contains(where: { $0.drinks.isEmpty }) {
                    Button("清理空场") {
                        withAnimation {
                            store.clearEmptyHistory()
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.mute)
                }
            }

            VStack(spacing: 8) {
                ForEach(displayed) { session in
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

                if allReversed.count > 4 {
                    Button {
                        withAnimation(.smooth(duration: 0.22)) {
                            showAllHistory.toggle()
                        }
                    } label: {
                        Text(showAllHistory ? "收起较早手账" : "查看全部 \(allReversed.count) 场记录")
                            .font(.caption)
                            .foregroundStyle(Theme.gold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var legalFootnote: some View {
        Text("基于 WHO 14 克纯乙醇标准杯模型推算。本品仅作席间节律辅助，不可作为血液酒精浓度或驾驶依据。")
            .font(.system(size: 11))
            .foregroundStyle(Theme.mute.opacity(0.65))
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

// MARK: - Session View (停杯 2.0：一屏定焦陀飞轮级腕表座舱)

struct SessionView: View {
    @Environment(SessionStore.self) private var store
    @State private var showingDrinks = false
    @State private var showingTimeline = false
    @State private var confirmingEnd = false

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            if let snap = store.snapshot, let session = store.active {
                // 1. 顶部腕表铭牌栏
                horologyTopBar(snap, session: session)
                    .padding(.horizontal, 22)
                    .padding(.top, 8)

                Spacer(minLength: 4)

                // 2. 核心同轴机械双轨表盘（Co-Axial Horology Dial）
                coAxialWatchDial(snap, session: session)

                Spacer(minLength: 4)

                // 3. 动态节律导引与待校准胶囊区
                rhythmTelemetryCard(snap, session: session)
                    .padding(.horizontal, 22)

                Spacer(minLength: 10)

                // 4. 底部机械表冠级操作船坞（Tactile Crown Dock）
                tactileCrownDock(snap, session: session)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $showingDrinks) {
            DrinkSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
        }
        .sheet(isPresented: $showingTimeline) {
            if let session = store.active {
                TimelineDrawerSheet(session: session)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.bg)
            }
        }
        .confirmationDialog(
            "收杯结席？",
            isPresented: Binding(
                get: { confirmingEnd || store.confirmingEndFromDeepLink },
                set: { val in
                    confirmingEnd = val
                    store.confirmingEndFromDeepLink = val
                }
            ),
            titleVisibility: .visible
        ) {
            Button("收杯并生成复盘", role: .destructive) { store.end() }
            Button("继续席间守护", role: .cancel) {}
        } message: {
            Text("结束后将停止后续排期提醒，并为您生成本场饮酒节律复盘。")
        }
    }

    // 1. 顶部腕表铭牌栏：左场景与酒器切换，右流逝时间与水酒平衡
    private func horologyTopBar(_ snap: PaceSnapshot, session: Session) -> some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Text(session.planName)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.goldBright)

                Text("·")
                    .foregroundStyle(Theme.mute)

                Menu {
                    ForEach(BeverageCategory.allCases) { cat in
                        Button {
                            store.switchBeverageCategory(cat)
                        } label: {
                            Label("\(cat.name)（按\(cat.unitName)计量）", systemImage: cat.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: session.beverageCategory.icon)
                            .font(.system(size: 10))
                        Text(session.beverageCategory.name)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(Theme.cream)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Theme.surface)
                            .overlay(Capsule().stroke(Theme.subtleCardStroke, lineWidth: 1))
                    )
                }
            }

            Spacer()

            // 右侧：流逝时长 / 预定时长 精密读数
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.gold)
                Text("\(Format.hm(snap.elapsed)) / \(Format.hm(snap.planned))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.cream)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Theme.raised)
                    .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 0.8))
            )
        }
    }

    // 2. 同轴双轨机械腕表表盘（Sunburst 放射纹 + 分段式宝石刻度弧 + 副表盘）
    private func coAxialWatchDial(_ snap: PaceSnapshot, session: Session) -> some View {
        let cat = session.beverageCategory
        let soft = max(session.softLimit, 1.0)
        let hard = max(session.hardLimit, session.softLimit)
        let timeProgress = min(1.0, snap.elapsed / session.plannedSeconds)

        // 计算分段刻度数量（按物理单位分段，如 3 两建议 / 4 两上限 -> 4 段，限制在 4...16 段之间以保证机械美感）
        let rawHardSegments = Int(round(cat.physicalValue(from: hard)))
        let totalSegments = min(16, max(4, rawHardSegments))
        let softSegments = max(1, Int(round(Double(totalSegments) * (soft / hard))))

        let confirmedRatio = min(1.0, snap.confirmedUnits / hard)
        let totalRatio = min(1.0, snap.units / hard)
        let isEstimatedOnly = snap.confirmedUnits == 0 && snap.estimatedUnits > 0

        return ZStack {
            // A. 外层环境呼吸柔光圈
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Theme.tint(snap.cue).opacity(0.18),
                            Theme.gold.opacity(0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: 60,
                        endRadius: 155
                    )
                )
                .frame(width: 300, height: 300)

            // B. 金属倒角外固定表圈 (Outer Bezel Rim)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.surface.opacity(0.75), Theme.bg],
                        center: .center,
                        startRadius: 10,
                        endRadius: 138
                    )
                )
                .frame(width: 276, height: 276)
                .overlay(
                    Circle()
                        .stroke(Theme.bezelGradient, lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.65), radius: 20, y: 10)

            // C. 60 枚精密蚀刻日内瓦时标
            DialTicksView()
                .frame(width: 264, height: 264)

            // D. 外环：流逝时间纤细金轨 + 游标金针
            Circle()
                .stroke(Theme.gold.opacity(0.14), lineWidth: 1.5)
                .frame(width: 242, height: 242)

            Circle()
                .trim(from: 0, to: timeProgress)
                .stroke(
                    LinearGradient(colors: [Theme.gold.opacity(0.5), Theme.goldBright], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 242, height: 242)
                .animation(.smooth(duration: 0.5), value: timeProgress)

            // 外环游标发光针尖
            let timeAngle = Angle.degrees(timeProgress * 360 - 90)
            Circle()
                .fill(Theme.goldBright)
                .frame(width: 6, height: 6)
                .shadow(color: Theme.goldBright, radius: 4)
                .offset(x: 121 * cos(timeAngle.radians), y: 121 * sin(timeAngle.radians))

            // E. 内环：分段式宝石刻度轨（Segmented Horology Ring）
            SegmentedBeverageRing(
                totalSegments: totalSegments,
                softSegments: softSegments,
                confirmedRatio: confirmedRatio,
                totalRatio: totalRatio,
                isOverSoft: snap.units >= soft - 0.001,
                isOverHard: snap.units >= hard - 0.001
            )
            .frame(width: 206, height: 206)

            // F. 建议停杯线黄金锚点标记
            let softRatio = min(1.0, soft / hard)
            let softAngle = Angle.degrees(softRatio * 360 - 90)
            ZStack {
                Circle()
                    .fill(Theme.gold.opacity(0.32))
                    .frame(width: 14, height: 14)
                Circle()
                    .fill(Theme.goldBright)
                    .frame(width: 6, height: 6)
            }
            .offset(x: 103 * cos(softAngle.radians), y: 103 * sin(softAngle.radians))

            // G. 内表盘放射纹核心读数区（Central Guilloché Sub-dial）
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.raised, Theme.bg.opacity(0.95)],
                        center: .center,
                        startRadius: 5,
                        endRadius: 88
                    )
                )
                .frame(width: 176, height: 176)
                .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 0.8))

            VStack(spacing: 4) {
                // 顶部：微醺意境铭牌
                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.tint(snap.cue))
                        .frame(width: 5, height: 5)
                    Text(snap.poeticPhase)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.5)
                        .foregroundStyle(Theme.tint(snap.cue))
                }

                // 中央：超大号衬线体物理摄入量
                Text(snap.physicalText)
                    .font(.system(size: 44, weight: .light, design: .serif))
                    .foregroundStyle(Theme.cream)
                    .contentTransition(.numericText())
                    .padding(.vertical, 1)

                // 确认 vs 推测 精密拆分标签
                if snap.estimatedUnits > 0.05 {
                    Text(isEstimatedOnly ? "◌ 静默推测 · 待确认" : "实记 \(cat.formatPhysical(from: snap.confirmedUnits)) + 推测 \(cat.formatPhysical(from: snap.estimatedUnits))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.gold)
                } else {
                    let softPhysical = cat.formatPhysical(from: session.softLimit)
                    Text("建议线 \(softPhysical) · \(Format.units(snap.units)) 标准杯")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.mute)
                }

                // 底部微型副表盘（Sub-dial）：距上一杯间隔 & 水酒代谢比
                HStack(spacing: 10) {
                    if let since = snap.sinceLastDrink {
                        HStack(spacing: 3) {
                            Image(systemName: "hourglass")
                                .font(.system(size: 8))
                            Text("距上杯 \(max(1, Int(since / 60)))m")
                                .font(.system(size: 9.5, design: .monospaced))
                        }
                        .foregroundStyle(snap.isTooFast ? Theme.goldBright : Theme.mute)
                    } else {
                        Text("尚未记杯")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.mute.opacity(0.7))
                    }

                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(Theme.faint)

                    HStack(spacing: 2) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 8))
                        Text("\(snap.waterCount) 水")
                            .font(.system(size: 9.5, design: .monospaced))
                    }
                    .foregroundStyle(Theme.water)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.surface.opacity(0.7)))
                .padding(.top, 4)
            }
        }
        .frame(width: 286, height: 286)
    }

    // 3. 动态节律导引与待校准一体式仪器卡
    private func rhythmTelemetryCard(_ snap: PaceSnapshot, session: Session) -> some View {
        VStack(spacing: 10) {
            // 主状态与下次提醒倒计时
            VStack(spacing: 6) {
                HStack(alignment: .center) {
                    Text(snap.title)
                        .font(.system(size: 19, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.cream)

                    Spacer()

                    // 右侧：下次提醒倒计时胶囊
                    if snap.intensity == .over {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                            Text("每 10 分钟强提醒")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Theme.wine)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.wine.opacity(0.16)))
                    } else if let next = snap.nextPrompt {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 9))
                            Text("\(Format.shortTime(next.at)) · \(Format.until(next.at, now: store.now))")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                        }
                        .foregroundStyle(Theme.goldBright)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.gold.opacity(0.14)))
                    }
                }

                Text(snap.message)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mute)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.raised)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.subtleCardStroke, lineWidth: 1))
            )

            // 若存在未回复的静默推测提醒，直接内嵌高优先级一键校准条
            if let pending = snap.pendingPrompt {
                let defaultPreset = store.defaultPresetForCurrentSession()
                HStack(spacing: 10) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.goldBright)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(Format.shortTime(pending.at)) 节拍询问：喝了吗？")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.cream)
                        Text("已暂按节奏计入虚线刻度")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.mute)
                    }
                    Spacer()
                    Button {
                        withAnimation {
                            store.handlePromptReply(promptID: pending.id, reply: .skipped)
                        }
                    } label: {
                        Text("还没喝")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Theme.surface))
                            .foregroundStyle(Theme.cream)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation {
                            store.handlePromptReply(promptID: pending.id, reply: .drank)
                        }
                    } label: {
                        Text("喝了\(defaultPreset.name)")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Theme.gold))
                            .foregroundStyle(Theme.ink)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.45), lineWidth: 1))
                )
            } else if store.notificationPermission == .denied {
                Button {
                    store.openNotificationSettings()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.slash.fill")
                        Text("通知权限未开启，锁屏时无法主动提醒，点此开启")
                            .font(.caption)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(Theme.goldBright)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.gold.opacity(0.14)))
                }
                .buttonStyle(.plain)
            }

            // 底部轻量时间轴入口栏（替代原先冗长杂乱的流水账列表）
            HStack {
                Button {
                    showingTimeline = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.indent")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.gold)
                        if let latest = lines(session).first {
                            Text("最新：\(Format.shortTime(latest.at)) \(latest.text)")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.mute)
                                .lineLimit(1)
                        } else {
                            Text("本场时间轴明细（暂无记录）")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.mute)
                        }
                        Image(systemName: "chevron.up")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.mute)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if !session.drinks.isEmpty || !session.waters.isEmpty {
                    Button {
                        withAnimation {
                            store.undoLast()
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 10))
                            Text("撤销")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(Theme.gold)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
        }
    }

    // 4. 底部机械表冠级操作船坞：点按中央直接记 1 份默认酒饮，右侧附带换酒/补记小按钮
    private func tactileCrownDock(_ snap: PaceSnapshot, session: Session) -> some View {
        let cat = session.beverageCategory
        let defaultDrink = store.defaultPresetForCurrentSession()

        return HStack(alignment: .center, spacing: 14) {
            // 左侧：喝水缓冲（急饮时高亮提示可折抵冷却）
            Button {
                store.logWater()
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Theme.raised)
                            .frame(width: 54, height: 54)
                            .overlay(
                                Circle()
                                    .stroke(snap.isTooFast ? Theme.water : Theme.water.opacity(0.35), lineWidth: snap.isTooFast ? 1.5 : 1)
                            )
                        Image(systemName: "drop.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.water)
                    }
                    Text(snap.isTooFast ? "喝水缓5m" : "喝了水")
                        .font(.system(size: 10, weight: snap.isTooFast ? .semibold : .regular))
                        .foregroundStyle(snap.isTooFast ? Theme.water : Theme.mute)
                }
            }
            .buttonStyle(.plain)

            // 中央主表冠按钮：轻点直接记 1 份当前默认酒饮（零弹窗阻断），下方附带「换酒 / 补记时间」副键
            VStack(spacing: 6) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        store.logDrink()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("记 1 \(cat.unitName)\(cat.name)")
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                            Text(defaultDrink.detail)
                                .font(.system(size: 9.5))
                                .opacity(0.8)
                        }
                    }
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.goldBright, Theme.gold],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Theme.gold.opacity(0.3), radius: 10, y: 4)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showingDrinks = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 9))
                        Text("选其它酒 / 回溯补记时间")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(Theme.gold)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)

            // 右侧：收杯结席
            Button {
                confirmingEnd = true
            } label: {
                VStack(spacing: 4) {
                    let isUrgent = snap.intensity == .over || snap.intensity == .due
                    ZStack {
                        Circle()
                            .fill(isUrgent ? Theme.wine : Theme.surface)
                            .frame(width: 54, height: 54)
                            .overlay(
                                Circle()
                                    .stroke(isUrgent ? Theme.wine : Theme.gold.opacity(0.45), lineWidth: 1.2)
                            )
                        Text("收")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundStyle(isUrgent ? Theme.cream : Theme.goldBright)
                    }
                    Text("我收杯了")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.mute)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Theme.raised.opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(Theme.bezelGradient, lineWidth: 1))
                .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
        )
    }

    fileprivate func lines(_ session: Session) -> [LogLine] {
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
        for prompt in session.prompts where prompt.reply == nil && prompt.at <= store.now {
            let cat = session.beverageCategory
            let text = prompt.semanticText ?? "◌ 节奏推测 · 约 \(cat.formatPhysical(from: prompt.projectedUnits))"
            items.append(
                LogLine(
                    id: prompt.id,
                    at: prompt.at,
                    text: text,
                    color: prompt.level == .over ? Theme.wine : Theme.gold.opacity(0.85),
                    promptID: prompt.id
                )
            )
        }

        return items.sorted { $0.at > $1.at }
    }
}

// MARK: - 腕表精密绘图组件：分段式宝石刻度环与日内瓦时标

struct SegmentedBeverageRing: View {
    let totalSegments: Int
    let softSegments: Int
    let confirmedRatio: Double
    let totalRatio: Double
    let isOverSoft: Bool
    let isOverHard: Bool

    var body: some View {
        ZStack {
            // 1. 底层分段槽位（安全段 vs 警戒段）
            ForEach(0..<totalSegments, id: \.self) { index in
                let gap = 0.008
                let segSpan = 1.0 / Double(totalSegments)
                let start = Double(index) * segSpan + gap / 2
                let end = Double(index + 1) * segSpan - gap / 2
                let isDangerZone = index >= softSegments

                Circle()
                    .trim(from: start, to: end)
                    .stroke(
                        isDangerZone ? Theme.wine.opacity(0.24) : Theme.faint,
                        style: StrokeStyle(lineWidth: 7, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
            }

            // 2. 静默推测增量弧（琥珀金呼吸虚线）
            if totalRatio > confirmedRatio {
                Circle()
                    .trim(from: confirmedRatio, to: totalRatio)
                    .stroke(
                        isOverSoft ? Theme.wine.opacity(0.75) : Theme.gold.opacity(0.8),
                        style: StrokeStyle(lineWidth: 7, lineCap: .butt, dash: [5, 4])
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.5), value: totalRatio)
            }

            // 3. 已确认饮酒实心弧（带高光渐变）
            if confirmedRatio > 0 {
                Circle()
                    .trim(from: 0, to: confirmedRatio)
                    .stroke(
                        isOverHard
                            ? LinearGradient(colors: [Theme.gold, Theme.wine], startPoint: .top, endPoint: .bottom)
                            : (isOverSoft
                                ? LinearGradient(colors: [Theme.goldBright, Theme.wine.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [Theme.cream, Theme.goldBright], startPoint: .topLeading, endPoint: .bottomTrailing)),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.5), value: confirmedRatio)
            }
        }
    }
}

struct DialTicksView: View {
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2
            ZStack {
                // 次刻度细线
                Path { path in
                    for i in 0..<60 where i % 5 != 0 {
                        let angle = Double(i) * 6.0 * .pi / 180.0
                        let r1 = radius
                        let r2 = radius - 4
                        path.move(to: CGPoint(x: center.x + r1 * sin(angle), y: center.y - r1 * cos(angle)))
                        path.addLine(to: CGPoint(x: center.x + r2 * sin(angle), y: center.y - r2 * cos(angle)))
                    }
                }
                .stroke(Theme.cream.opacity(0.14), lineWidth: 0.8)

                // 12 枚主香槟金时标
                Path { path in
                    for i in stride(from: 0, to: 60, by: 5) {
                        let angle = Double(i) * 6.0 * .pi / 180.0
                        let r1 = radius
                        let r2 = radius - 8
                        path.move(to: CGPoint(x: center.x + r1 * sin(angle), y: center.y - r1 * cos(angle)))
                        path.addLine(to: CGPoint(x: center.x + r2 * sin(angle), y: center.y - r2 * cos(angle)))
                    }
                }
                .stroke(Theme.gold.opacity(0.55), lineWidth: 1.4)
            }
        }
    }
}

// MARK: - 本场时间轴明细抽屉 (Timeline Drawer Sheet)

struct TimelineDrawerSheet: View {
    let session: Session
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("席间时间轴明细")
                        .font(.system(size: 22, weight: .light, design: .serif))
                        .foregroundStyle(Theme.cream)
                    Text("可随时撤销误记，或逐条校准静默推测")
                        .font(.caption)
                        .foregroundStyle(Theme.mute)
                }
                Spacer()
                if !session.drinks.isEmpty || !session.waters.isEmpty {
                    Button {
                        withAnimation {
                            store.undoLast()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("撤销上一条")
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.surface))
                        .foregroundStyle(Theme.gold)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 20)

            ScrollView(showsIndicators: false) {
                let allLines = buildLines()
                if allLines.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "hourglass")
                            .font(.title2)
                            .foregroundStyle(Theme.mute)
                        Text("尚无饮酒或喝水记录")
                            .font(.subheadline)
                            .foregroundStyle(Theme.mute)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    VStack(spacing: 10) {
                        ForEach(allLines) { line in
                            HStack(alignment: .center, spacing: 10) {
                                Text(Format.shortTime(line.at))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(Theme.mute)
                                    .frame(width: 46, alignment: .leading)

                                Circle()
                                    .fill(line.color)
                                    .frame(width: 6, height: 6)

                                Text(line.text)
                                    .font(.subheadline)
                                    .foregroundStyle(line.color)

                                Spacer()

                                if let pid = line.promptID {
                                    HStack(spacing: 6) {
                                        Button {
                                            withAnimation {
                                                store.handlePromptReply(promptID: pid, reply: .skipped)
                                            }
                                        } label: {
                                            Text("没喝")
                                                .font(.caption2)
                                                .padding(.horizontal, 9)
                                                .padding(.vertical, 4)
                                                .background(Capsule().fill(Theme.surface))
                                                .foregroundStyle(Theme.mute)
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            withAnimation {
                                                store.handlePromptReply(promptID: pid, reply: .drank)
                                            }
                                        } label: {
                                            Text("确认")
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 9)
                                                .padding(.vertical, 4)
                                                .background(Capsule().fill(Theme.gold))
                                                .foregroundStyle(Theme.ink)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.raised))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
    }

    private func buildLines() -> [LogLine] {
        guard let currentSession = store.active else { return [] }
        var items: [LogLine] = []
        for drink in currentSession.drinks {
            items.append(LogLine(id: drink.id, at: drink.at, text: "\(drink.name) · \(drink.detail)", color: Theme.cream))
        }
        for water in currentSession.waters {
            items.append(LogLine(id: water.id, at: water.at, text: "💧 喝了一杯水", color: Theme.water))
        }
        for prompt in currentSession.prompts where prompt.reply == nil && prompt.at <= store.now {
            let cat = currentSession.beverageCategory
            let text = prompt.semanticText ?? "◌ 节奏推测 · 约 \(cat.formatPhysical(from: prompt.projectedUnits))"
            items.append(LogLine(id: prompt.id, at: prompt.at, text: text, color: prompt.level == .over ? Theme.wine : Theme.gold, promptID: prompt.id))
        }
        return items.sorted { $0.at > $1.at }
    }
}

// MARK: - Drink Sheet (换酒与回溯补记时间抽屉)

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
        let raw = Date.now.addingTimeInterval(-Double(minutesAgo * 60))
        if let start = store.active?.startedAt {
            return max(start, raw)
        }
        return raw
    }

    var body: some View {
        let elapsedMinutes = Int((store.active?.duration ?? 0) / 60)
        let quickDrink = store.active?.drinks.last?.preset ?? store.defaultPresetForCurrentSession()
        let isRepeat = store.active?.drinks.last != nil

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("选酒与回溯补记")
                        .font(.system(size: 24, weight: .light, design: .serif))
                        .foregroundStyle(Theme.cream)
                    Spacer()
                    Picker("类型", selection: $tab) {
                        Text("预设酒饮").tag(0)
                        Text("自选度数").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
                .padding(.top, 22)

                // 时间回溯快捷选择器
                HStack(spacing: 8) {
                    Text("饮用时间:")
                        .font(.caption)
                        .foregroundStyle(Theme.mute)
                    ForEach([0, 10, 20, 30], id: \.self) { min in
                        let disabled = min > 0 && elapsedMinutes < min
                        Button(min == 0 ? "刚才" : "\(min)分钟前") {
                            minutesAgo = min
                        }
                        .disabled(disabled)
                        .font(.caption2.weight(minutesAgo == min ? .semibold : .regular))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(minutesAgo == min ? Theme.gold : Theme.raised))
                        .foregroundStyle(minutesAgo == min ? Theme.ink : (disabled ? Theme.mute.opacity(0.3) : Theme.cream))
                    }
                }

                // 置顶首选快捷大卡片
                Button {
                    store.logDrink(preset: quickDrink, at: targetLogTime)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isRepeat ? "同上一份：\(quickDrink.name)" : "当前首选：\(quickDrink.name)")
                                .font(.headline)
                                .foregroundStyle(Theme.cream)
                            Text("\(quickDrink.detail) · 约 \(Format.units(quickDrink.grams / Pace.gramsPerStandard)) 标准杯")
                                .font(.caption)
                                .foregroundStyle(Theme.gold)
                        }
                        Spacer()
                        Image(systemName: isRepeat ? "arrow.clockwise.circle.fill" : "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.goldBright)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.gold.opacity(0.14)))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.gold.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(.plain)

                if tab == 0 {
                    presetGrid
                } else {
                    customDrinkForm
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
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
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Theme.raised)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.subtleCardStroke, lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.cream)
            }
        }
    }

    private var customDrinkForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("酒品名称，如精酿 IPA / 威士忌", text: $customName)
                .textFieldStyle(.plain)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                .foregroundStyle(Theme.cream)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("单杯容量")
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
                Button("记录这杯") {
                    store.logCustom(name: customName, volumeMl: customVolume, abv: customAbv, at: targetLogTime)
                    dismiss()
                }
                .font(.subheadline.bold())
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Capsule().fill(Theme.gold))
                .foregroundStyle(Theme.ink)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.raised)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.subtleCardStroke, lineWidth: 1))
        )
    }
}

// MARK: - 通用精密 UI 组件

struct PlanDialTile: View {
    let title: String
    let subtitle: String
    let metric: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(isSelected ? Theme.goldBright : Theme.cream)
                    Spacer(minLength: 0)
                    Circle()
                        .fill(isSelected ? Theme.goldBright : Theme.faint)
                        .frame(width: 6, height: 6)
                }

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.mute)

                Text(metric)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(isSelected ? Theme.cream : Theme.mute)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.top, 2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? LinearGradient(colors: [Theme.surface, Theme.raised], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Theme.raised.opacity(0.65), Theme.raised.opacity(0.45)], startPoint: .top, endPoint: .bottom)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Theme.gold : Color.white.opacity(0.06), lineWidth: isSelected ? 1.2 : 0.8)
            )
        }
        .buttonStyle(.plain)
    }
}

struct HistoryRow: View {
    let session: Session
    let onDelete: () -> Void

    var body: some View {
        let end = session.endedAt ?? Date()
        let outcome = session.outcome(at: end)
        let cat = session.beverageCategory
        let totalUnits = session.units(at: end)
        let estimatedUnits = session.estimatedUnits(at: end)
        let estimateTag = estimatedUnits > 0.05 ? " (含推测)" : ""

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.planName)
                        .font(.system(size: 15, weight: .medium, design: .serif))
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
                Text("\(cat.formatPhysical(from: totalUnits))\(estimateTag) · \(Format.units(totalUnits)) 标准杯 · 时长 \(Format.minutes(Int(session.duration / 60)))")
                    .font(.caption2)
                    .foregroundStyle(Theme.mute)
            }
            Spacer()
            HStack(spacing: 12) {
                Text(outcome.title)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill((outcome == .crossed ? Theme.wine : Theme.sage).opacity(0.15)))
                    .foregroundStyle(outcome == .crossed ? Theme.wine : Theme.sage)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(Theme.mute.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.raised)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.subtleCardStroke, lineWidth: 1))
        )
    }
}

struct SummarySheet: View {
    let session: Session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let end = session.endedAt ?? Date()
        let outcome = session.outcome(at: end)
        let cat = session.beverageCategory
        let units = session.units(at: end)
        let confirmed = session.confirmedUnits(at: end)
        let estimated = session.estimatedUnits(at: end)

        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text("席 间 复 盘")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Theme.gold)
                    .padding(.top, 28)

                Text(outcome.title)
                    .font(.system(size: 34, weight: .light, design: .serif))
                    .foregroundStyle(Theme.cream)

                Text(outcome.detail)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.mute)
                    .padding(.horizontal, 28)
            }

            VStack(spacing: 14) {
                HStack {
                    Text("主要酒器")
                        .foregroundStyle(Theme.mute)
                    Spacer()
                    Text("\(cat.name)（\(session.planName)）")
                        .foregroundStyle(Theme.goldBright)
                }
                Divider().background(Theme.faint)
                HStack {
                    Text(estimated > 0.05 ? "本场累计（含推测）" : "实际摄入总量")
                        .foregroundStyle(Theme.mute)
                    Spacer()
                    Text("\(cat.formatPhysical(from: units)) · \(Format.units(units)) 标准杯")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.cream)
                }
                if estimated > 0.05 {
                    HStack {
                        Text("其中：确认 / 节奏推测")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                        Spacer()
                        Text("\(cat.formatPhysical(from: confirmed)) / \(cat.formatPhysical(from: estimated))")
                            .font(.caption)
                            .foregroundStyle(Theme.gold)
                    }
                }
                Divider().background(Theme.faint)
                HStack {
                    Text("席间时长")
                        .foregroundStyle(Theme.mute)
                    Spacer()
                    Text(Format.minutes(Int(session.duration / 60)))
                        .foregroundStyle(Theme.cream)
                }
                Divider().background(Theme.faint)
                HStack {
                    Text("代谢补水")
                        .foregroundStyle(Theme.mute)
                    Spacer()
                    Text("\(session.waters.count) 杯水")
                        .foregroundStyle(Theme.water)
                }
            }
            .font(.subheadline)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.raised)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.bezelGradient, lineWidth: 1))
            )
            .padding(.horizontal, 24)

            Spacer()

            FillButton(title: "收妥归档", color: Theme.gold) {
                dismiss()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
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
                .font(.caption)
                .foregroundStyle(Theme.cream)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.goldBright)
            Stepper("", value: $valueBinding, in: range, step: step)
                .labelsHidden()
                .scaleEffect(0.88)
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
                .foregroundStyle(Theme.ink)
        }
        .buttonStyle(.plain)
    }
}

struct HorologyEmblem: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.raised)
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(Theme.bezelGradient, lineWidth: 1.2))
            Image(systemName: "wineglass")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Theme.goldBright)
        }
    }
}

struct LogLine: Identifiable {
    let id: UUID
    let at: Date
    let text: String
    let color: Color
    var promptID: UUID? = nil
}
