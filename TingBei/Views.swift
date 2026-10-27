import SwiftUI
import UIKit

// MARK: - 多主题美学系统 (停杯 2.0：六大名表与东方雅集主题)

struct ThemePalette: Sendable {
    let bg: Color
    let raised: Color
    let surface: Color
    let cream: Color
    let mute: Color
    let faint: Color
    let gold: Color
    let goldBright: Color
    let wine: Color
    let sage: Color
    let water: Color
    let ink: Color
    let isLight: Bool
}

@MainActor
@Observable
final class ThemeState {
    static let shared = ThemeState()
    var current: AppTheme = .obsidianGold
}

@MainActor
enum Theme {
    static var current: AppTheme {
        ThemeState.shared.current
    }

    static func apply(_ theme: AppTheme) {
        if ThemeState.shared.current != theme {
            ThemeState.shared.current = theme
        }
    }

    static func palette(for theme: AppTheme) -> ThemePalette {
        switch theme {
        case .obsidianGold:
            // 1. 曜石黑金 · 朗格夜宴 (德系 18K 香槟蜜金与德国银夹板)
            let creamBase = Color(red: 0.945, green: 0.918, blue: 0.871)
            return ThemePalette(
                bg: Color(red: 0.039, green: 0.035, blue: 0.031),       // 纯正黑曜石 #0A0908
                raised: Color(red: 0.086, green: 0.078, blue: 0.071),   // 德国银暖灰黑夹板 #161412
                surface: Color(red: 0.133, green: 0.122, blue: 0.110),  // 日内瓦条纹夹板槽 #221F1C
                cream: creamBase,                                       // 银白刻度 #F1EAE0
                mute: creamBase.opacity(0.54),
                faint: creamBase.opacity(0.11),
                gold: Color(red: 0.784, green: 0.643, blue: 0.431),     // 朗格 18K 香槟蜜金 Honey Gold #C8A46E
                goldBright: Color(red: 0.902, green: 0.776, blue: 0.565), // 抛光蜜金高光 #E6C690
                wine: Color(red: 0.776, green: 0.231, blue: 0.204),     // 机芯红宝石轴承色 #C63B34
                sage: Color(red: 0.545, green: 0.698, blue: 0.529),     // 翡翠鼠尾草绿
                water: Color(red: 0.365, green: 0.576, blue: 0.808),    // 德系烤蓝钢螺丝色 #5D93CE
                ink: Color(red: 0.050, green: 0.040, blue: 0.030),
                isLight: false
            )

        case .celadonJade:
            // 2. 汝窑天青 · 宋韵流觞 (真正故宫宋代汝窑「雨过天青云破处」淡雅粉青玛瑙釉)
            let inkBase = Color(red: 0.149, green: 0.208, blue: 0.200)  // 汝窑香灰胎铁足深黛墨 #263533
            return ThemePalette(
                bg: Color(red: 0.843, green: 0.886, blue: 0.878),       // 雨过天青淡雾釉底 #D7E2E0
                raised: Color(red: 0.918, green: 0.945, blue: 0.939),   // 凝脂天青月白浮雕釉面 #EAF1EF
                surface: Color(red: 0.776, green: 0.835, blue: 0.824),  // 弦纹凹槽积釉天青 #C6D5D2
                cream: inkBase,                                         // 香灰胎深黛墨
                mute: inkBase.opacity(0.55),
                faint: inkBase.opacity(0.11),
                gold: Color(red: 0.259, green: 0.467, blue: 0.455),     // 秘色深天青碧玉 #427774
                goldBright: Color(red: 0.337, green: 0.557, blue: 0.541), // 温润玛瑙青釉高光 #568E8A
                wine: Color(red: 0.698, green: 0.290, blue: 0.255),     // 宋画矿物暗朱砂印泥 #B24A41
                sage: Color(red: 0.290, green: 0.506, blue: 0.424),     // 龙泉梅子青 #4A816C
                water: Color(red: 0.267, green: 0.486, blue: 0.596),    // 影青湖水蓝 #447C98
                ink: Color(red: 0.945, green: 0.969, blue: 0.965),      // 月白釉反白字
                isLight: true
            )

        case .burgundyCellar:
            // 3. 微醺酒庄 · 勃艮第夜 (法国烘烤橡木桶、陈年黑皮诺与干邑玫瑰金)
            let creamBase = Color(red: 0.961, green: 0.918, blue: 0.890)
            return ThemePalette(
                bg: Color(red: 0.071, green: 0.031, blue: 0.035),       // 百年地下酒窖深褐红 #120809
                raised: Color(red: 0.129, green: 0.059, blue: 0.067),   // 法国烘烤橡木桶暗酒红 #210F11
                surface: Color(red: 0.192, green: 0.090, blue: 0.102),  // 陈年黑皮诺丝绒酒液 #31171A
                cream: creamBase,                                       // 酒标羊皮纸暖白 #F5EAE3
                mute: creamBase.opacity(0.55),
                faint: creamBase.opacity(0.12),
                gold: Color(red: 0.824, green: 0.565, blue: 0.439),     // 干邑琥珀 18K 玫瑰金 #D29070
                goldBright: Color(red: 0.929, green: 0.710, blue: 0.588), // 烛光玫瑰金 #EDB596
                wine: Color(red: 0.855, green: 0.235, blue: 0.282),     // 醒酒器红宝石光 #DA3C48
                sage: Color(red: 0.518, green: 0.686, blue: 0.541),     // 葡萄庄园鼠尾草绿 #84AF8A
                water: Color(red: 0.490, green: 0.698, blue: 0.878),    // 冰桶晶蓝
                ink: Color(red: 0.090, green: 0.030, blue: 0.038),
                isLight: false
            )

        case .midnightSapphire:
            // 4. 深海蓝盘 · 皇家午夜 (瑞士鹦鹉螺孔雀蓝太阳纹与 950 铂金冷银)
            let creamBase = Color(red: 0.925, green: 0.949, blue: 0.976)
            return ThemePalette(
                bg: Color(red: 0.027, green: 0.051, blue: 0.086),       // 深海海沟午夜蓝 #070D16
                raised: Color(red: 0.059, green: 0.102, blue: 0.165),   // 鹦鹉螺孔雀蓝灰盘面 #0F1A2A
                surface: Color(red: 0.098, green: 0.161, blue: 0.247),  // 日内瓦拉丝蓝钢 #19293F
                cream: creamBase,                                       // 950 铂金冷银白 #ECF2F9
                mute: creamBase.opacity(0.55),
                faint: creamBase.opacity(0.12),
                gold: Color(red: 0.447, green: 0.682, blue: 0.855),     // Super-LumiNova 冰川蓝铂金 #72AEDA
                goldBright: Color(red: 0.678, green: 0.851, blue: 0.969), // 高光铂金冰蓝 #ADD9F7
                wine: Color(red: 0.886, green: 0.325, blue: 0.263),     // 深潜减压阀信号橙红 #E25343
                sage: Color(red: 0.410, green: 0.765, blue: 0.635),     // 极光薄荷绿
                water: Color(red: 0.340, green: 0.780, blue: 0.965),    // 深海活水蓝
                ink: Color(red: 0.024, green: 0.050, blue: 0.095),
                isLight: false
            )

        case .enamelIvory:
            // 5. 大明火珐琅 · 日内瓦白瓷 (800°C 大明火白珐琅、乌黑烤漆与 290°C 淬火宝玑烤蓝钢)
            let inkBase = Color(red: 0.106, green: 0.094, blue: 0.082)  // 大明火黑珐琅烤漆浓墨 #1B1815
            return ThemePalette(
                bg: Color(red: 0.961, green: 0.949, blue: 0.925),       // 800°C 大明火暖象牙瓷白 #F5F2EC
                raised: Color(red: 0.996, green: 0.992, blue: 0.984),   // 纯白抛光珐琅盘面 #FEFDFA
                surface: Color(red: 0.914, green: 0.894, blue: 0.855),  // 日内瓦沙金内圈槽 #E9E4DA
                cream: inkBase,                                         // 乌黑烤漆字墨
                mute: inkBase.opacity(0.55),
                faint: inkBase.opacity(0.10),
                gold: Color(red: 0.620, green: 0.416, blue: 0.188),     // 宝玑古典皇室黄铜金 #9E6A30
                goldBright: Color(red: 0.737, green: 0.506, blue: 0.243), // 18K 玫瑰古铜金 #BC813E
                wine: Color(red: 0.753, green: 0.196, blue: 0.161),     // 日内瓦火漆封印红 #C03229
                sage: Color(red: 0.220, green: 0.502, blue: 0.345),     // 古典庄园绿 #388058
                water: Color(red: 0.125, green: 0.369, blue: 0.620),    // 290°C 淬火宝玑烤蓝钢 #205E9E
                ink: Color(red: 0.996, green: 0.992, blue: 0.984),      // 主按钮瓷白反白字
                isLight: true
            )

        case .xuanPaperInk:
            // 6. 宣纸水墨 · 兰亭雅集 (泾县陈年古法生宣、徽州松烟浓墨、书画古泥金与西泠朱砂印)
            let inkBase = Color(red: 0.122, green: 0.118, blue: 0.110)  // 徽州松烟浓墨 #1F1E1C
            return ThemePalette(
                bg: Color(red: 0.937, green: 0.922, blue: 0.886),       // 泾县陈年古法生宣米白 #EFEBE2
                raised: Color(red: 0.976, green: 0.969, blue: 0.945),   // 云母洒金净皮宣 #F9F7F1
                surface: Color(red: 0.878, green: 0.859, blue: 0.816),  // 端砚淡墨水痕灰 #E0DBD0
                cream: inkBase,                                         // 徽州松烟浓墨
                mute: inkBase.opacity(0.56),
                faint: inkBase.opacity(0.11),
                gold: Color(red: 0.451, green: 0.365, blue: 0.247),     // 书画古泥金 / 乌金铜镇纸色 #735D3F
                goldBright: Color(red: 0.565, green: 0.463, blue: 0.322), // 宣纸洒金铜色 #907652
                wine: Color(red: 0.737, green: 0.204, blue: 0.169),     // 西泠八宝印泥朱砂红 #BC342B
                sage: Color(red: 0.282, green: 0.471, blue: 0.384),     // 宋画花青石绿 #487862
                water: Color(red: 0.227, green: 0.416, blue: 0.533),    // 敦煌花青水蓝 #3A6A88
                ink: Color(red: 0.976, green: 0.969, blue: 0.945),      // 宣纸反白字
                isLight: true
            )
        }
    }

    private static var p: ThemePalette {
        palette(for: current)
    }

    static var bg: Color { p.bg }
    static var raised: Color { p.raised }
    static var surface: Color { p.surface }
    static var cream: Color { p.cream }
    static var mute: Color { p.mute }
    static var faint: Color { p.faint }
    static var gold: Color { p.gold }
    static var goldBright: Color { p.goldBright }
    static var wine: Color { p.wine }
    static var sage: Color { p.sage }
    static var water: Color { p.water }
    static var ink: Color { p.ink }
    static var isLight: Bool { p.isLight }
    static var colorScheme: ColorScheme { p.isLight ? .light : .dark }

    static var borderSubtle: Color {
        isLight ? gold.opacity(0.18) : Color.white.opacity(0.07)
    }

    static var cardShadow: Color {
        isLight ? gold.opacity(0.12) : Color.black.opacity(0.50)
    }

    static var dialShadow: Color {
        isLight ? gold.opacity(0.18) : Color.black.opacity(0.65)
    }

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
        if isLight {
            return LinearGradient(
                colors: [
                    goldBright.opacity(0.42),
                    gold.opacity(0.18),
                    Color.white.opacity(0.75),
                    gold.opacity(0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
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
        if isLight {
            return LinearGradient(
                colors: [
                    gold.opacity(0.24),
                    gold.opacity(0.08),
                    goldBright.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color.white.opacity(0.16),
                Color.white.opacity(0.03),
                gold.opacity(0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var ringSafeGradient: LinearGradient {
        if isLight {
            return LinearGradient(
                colors: [gold, goldBright],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [cream, goldBright],
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

            // 全局顶部悬浮胶囊提示（带高光倒角）
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
                        .fill(Theme.raised.opacity(0.96))
                        .shadow(color: Theme.cardShadow, radius: 16, y: 6)
                )
                .overlay(Capsule().stroke(Theme.bezelGradient, lineWidth: 1))
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.smooth(duration: 0.35), value: store.active != nil)
        .animation(.smooth(duration: 0.28), value: store.toast)
        .animation(.smooth(duration: 0.32), value: Theme.current)
        .preferredColorScheme(Theme.colorScheme)
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
        .onAppear {
            Theme.apply(store.settings.selectedTheme)
            store.sceneAppeared()
        }
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
                .preferredColorScheme(Theme.colorScheme)
        }
    }
}

// MARK: - Night Background (环境呼吸氛围光)

struct NightBackground: View {
    var cue: Cue?

    var body: some View {
        let heat = heat(for: cue)
        let topGoldAlpha = Theme.isLight ? (0.10 * (1 - heat) + 0.02) : (0.14 * (1 - heat) + 0.03)
        let topWineAlpha = Theme.isLight ? (0.22 * heat) : (0.38 * heat)
        ZStack {
            Theme.bg
            RadialGradient(
                colors: [
                    Theme.gold.opacity(topGoldAlpha),
                    Theme.wine.opacity(topWineAlpha),
                    .clear,
                ],
                center: .top,
                startRadius: 5,
                endRadius: 540
            )
            RadialGradient(
                colors: [
                    Theme.gold.opacity(Theme.isLight ? 0.04 : 0.05),
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
    @State private var showingThemeGallery = false

    var body: some View {
        @Bindable var store = store
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                editorialHeader
                vesselGallerySection
                horologyPlanSection
                launchCrownSection
                themeCarouselSection
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
        .sheet(isPresented: $showingThemeGallery) {
            ThemeGallerySheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
                .preferredColorScheme(Theme.colorScheme)
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

                HStack(spacing: 8) {
                    // 快捷主题表盘入口徽章
                    Button {
                        showingThemeGallery = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "swatchpalette.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.goldBright)
                            Text(store.settings.selectedTheme.name)
                                .font(.system(size: 11, weight: .medium, design: .serif))
                                .foregroundStyle(Theme.cream)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.raised)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.subtleCardStroke, lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)

                    // 个人历史节制勋章
                    let nonEmpty = store.history.filter { $0.outcome(at: $0.endedAt ?? Date()) != .empty }
                    if !nonEmpty.isEmpty {
                        let withinCount = nonEmpty.filter { $0.outcome(at: $0.endedAt ?? Date()) != .crossed }.count
                        let rate = Int((Double(withinCount) / Double(nonEmpty.count) * 100).rounded())
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(rate)%")
                                .font(.system(size: 16, weight: .regular, design: .serif).monospacedDigit())
                                .foregroundStyle(Theme.goldBright)
                            Text("收杯率")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.mute)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.raised)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.subtleCardStroke, lineWidth: 1))
                        )
                    }
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
                                .stroke(isSelected ? Theme.gold : Theme.borderSubtle, lineWidth: isSelected ? 1.2 : 0.8)
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

    // 4.5 表盘与席间主题雅集橱窗（一键切换深浅名表与东方雅集主题）
    private var themeCarouselSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Text("表盘与席间主题")
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.cream)
                    Text(store.settings.selectedTheme.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.gold)
                }
                Spacer()
                Button {
                    showingThemeGallery = true
                } label: {
                    HStack(spacing: 3) {
                        Text("品鉴全部 6 款")
                            .font(.system(size: 10, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(Theme.gold)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(AppTheme.allCases) { theme in
                        let isSelected = store.settings.selectedTheme == theme
                        let pal = Theme.palette(for: theme)
                        Button {
                            withAnimation(.smooth(duration: 0.3)) {
                                store.selectTheme(theme)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                ThemeMiniDialBadge(theme: theme, size: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(theme.name)
                                            .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium, design: .serif))
                                            .foregroundStyle(pal.cream)
                                        if theme.isLight {
                                            Text(theme == .celadonJade ? "青釉" : "浅色")
                                                .font(.system(size: 8, weight: .bold))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Capsule().fill(pal.gold.opacity(0.16)))
                                                .foregroundStyle(pal.gold)
                                        }
                                    }
                                    Text(theme.dialStyle.displayName)
                                        .font(.system(size: 9.5))
                                        .foregroundStyle(pal.mute)
                                }

                                Circle()
                                    .fill(isSelected ? pal.goldBright : pal.faint)
                                    .frame(width: 6, height: 6)
                                    .padding(.leading, 2)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(pal.raised)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(
                                        isSelected ? pal.gold : (pal.isLight ? pal.gold.opacity(0.22) : Color.white.opacity(0.08)),
                                        lineWidth: isSelected ? 1.4 : 0.8
                                    )
                            )
                            .shadow(color: isSelected ? pal.gold.opacity(0.22) : .clear, radius: 8, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
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
    @State private var showingThemeGallery = false
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
                .preferredColorScheme(Theme.colorScheme)
        }
        .sheet(isPresented: $showingTimeline) {
            if let session = store.active {
                TimelineDrawerSheet(session: session)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.bg)
                    .preferredColorScheme(Theme.colorScheme)
            }
        }
        .sheet(isPresented: $showingThemeGallery) {
            ThemeGallerySheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
                .preferredColorScheme(Theme.colorScheme)
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

    // 1. 顶部腕表铭牌栏：左场景与酒器切换，右表盘主题切换与流逝时间
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

            HStack(spacing: 8) {
                // 席间实时换盘按钮
                Button {
                    showingThemeGallery = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "swatchpalette.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.goldBright)
                        Text(store.settings.selectedTheme.name)
                            .font(.system(size: 11, weight: .medium, design: .serif))
                            .foregroundStyle(Theme.cream)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Theme.raised)
                            .overlay(Capsule().stroke(Theme.borderSubtle, lineWidth: 0.8))
                    )
                }
                .buttonStyle(.plain)

                // 右侧：流逝时长 / 预定时长 精密读数
                HStack(spacing: 5) {
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
                        .overlay(Capsule().stroke(Theme.borderSubtle, lineWidth: 0.8))
                )
            }
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
                            Theme.tint(snap.cue).opacity(Theme.isLight ? 0.14 : 0.18),
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
                        colors: Theme.isLight
                            ? [Theme.raised, Theme.surface.opacity(0.75)]
                            : [Theme.surface.opacity(0.75), Theme.bg],
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
                .shadow(color: Theme.dialShadow, radius: 20, y: 10)

            // C. 主题定制精密腕表时标
            DialTicksView(style: Theme.current.dialStyle)
                .frame(width: 264, height: 264)

            // D. 外环：流逝时间纤细金轨 + 游标金针
            Circle()
                .stroke(Theme.gold.opacity(0.16), lineWidth: 1.5)
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
                        colors: [Theme.raised, Theme.bg.opacity(Theme.isLight ? 0.88 : 0.95)],
                        center: .center,
                        startRadius: 5,
                        endRadius: 88
                    )
                )
                .frame(width: 176, height: 176)
                .overlay(Circle().stroke(Theme.borderSubtle, lineWidth: 0.8))

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
                .shadow(color: Theme.cardShadow, radius: 16, y: 6)
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

// MARK: - 腕表精密绘图组件：分段式宝石刻度环与多流派名表时标

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

            // 2. 静默推测增量弧（呼吸虚线）
            if totalRatio > confirmedRatio {
                Circle()
                    .trim(from: confirmedRatio, to: totalRatio)
                    .stroke(
                        isOverSoft ? Theme.wine.opacity(0.75) : Theme.gold.opacity(0.82),
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
                                : Theme.ringSafeGradient),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.5), value: confirmedRatio)
            }
        }
    }
}

struct DialTicksView: View {
    var style: HorologyDialStyle = .geneva
    var primaryColor: Color? = nil
    var secondaryColor: Color? = nil

    var body: some View {
        let goldColor = primaryColor ?? Theme.gold
        let tickColor = secondaryColor ?? Theme.cream

        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2

            ZStack {
                switch style {
                case .geneva:
                    // 1. 曜石黑金 · 朗格双条形时标：48 枚次刻度 + 11 枚主金标 + 12 点位标志性双平行立体金条
                    Path { path in
                        for i in 0..<60 where i % 5 != 0 {
                            let angle = Double(i) * 6.0 * .pi / 180.0
                            let r1 = radius
                            let r2 = radius - 3.8
                            path.move(to: CGPoint(x: center.x + r1 * sin(angle), y: center.y - r1 * cos(angle)))
                            path.addLine(to: CGPoint(x: center.x + r2 * sin(angle), y: center.y - r2 * cos(angle)))
                        }
                    }
                    .stroke(tickColor.opacity(0.15), lineWidth: 0.75)

                    Path { path in
                        // 12 点位双条形平行立体金标
                        let offset = max(1.6, radius * 0.022)
                        let rTop = radius
                        let rBottom = radius - 9.5
                        path.move(to: CGPoint(x: center.x - offset, y: center.y - rTop))
                        path.addLine(to: CGPoint(x: center.x - offset, y: center.y - rBottom))
                        path.move(to: CGPoint(x: center.x + offset, y: center.y - rTop))
                        path.addLine(to: CGPoint(x: center.x + offset, y: center.y - rBottom))

                        // 其余 11 枚单条形金标
                        for i in stride(from: 5, to: 60, by: 5) {
                            let angle = Double(i) * 6.0 * .pi / 180.0
                            let r1 = radius
                            let r2 = radius - (i % 15 == 0 ? 9.0 : 7.5)
                            path.move(to: CGPoint(x: center.x + r1 * sin(angle), y: center.y - r1 * cos(angle)))
                            path.addLine(to: CGPoint(x: center.x + r2 * sin(angle), y: center.y - r2 * cos(angle)))
                        }
                    }
                    .stroke(goldColor.opacity(0.75), lineWidth: 1.5)

                case .ruKiln:
                    // 2. 汝窑天青 · 宋瓷弦纹开片盘：外内双道器物弦纹 + 隐约蝉翼冰裂开片纹 + 十二辰芝麻支钉玉珠
                    Circle()
                        .stroke(goldColor.opacity(0.26), lineWidth: 0.65)
                        .padding(1.5)
                    Circle()
                        .stroke(goldColor.opacity(0.16), lineWidth: 0.55)
                        .padding(6.0)

                    // 汝窑蝉翼冰裂纹（极淡雅的几何折线釉裂纹理，仅在盘缘与内圈隐现）
                    Path { path in
                        let crackAngles: [(Double, Double, Double)] = [
                            (22, 28, 19), (78, 71, 82), (138, 146, 134),
                            (205, 198, 210), (262, 269, 258), (318, 312, 324)
                        ]
                        for (a1, a2, a3) in crackAngles {
                            let rad1 = a1 * .pi / 180.0
                            let rad2 = a2 * .pi / 180.0
                            let rad3 = a3 * .pi / 180.0
                            let rOuter = radius - 2.0
                            let rMid = radius * 0.80
                            let rInner = radius * 0.62
                            path.move(to: CGPoint(x: center.x + rOuter * sin(rad1), y: center.y - rOuter * cos(rad1)))
                            path.addLine(to: CGPoint(x: center.x + rMid * sin(rad2), y: center.y - rMid * cos(rad2)))
                            path.addLine(to: CGPoint(x: center.x + rInner * sin(rad3), y: center.y - rInner * cos(rad3)))
                        }
                    }
                    .stroke(goldColor.opacity(0.11), lineWidth: 0.5)

                    // 十二辰汝瓷芝麻支钉痕与玉珠时标
                    Path { path in
                        for i in stride(from: 0, to: 60, by: 5) {
                            let angle = Double(i) * 6.0 * .pi / 180.0
                            let isCardinal = i % 15 == 0
                            let r = radius - 3.8
                            let pt = CGPoint(x: center.x + r * sin(angle), y: center.y - r * cos(angle))
                            if isCardinal {
                                // 四正时辰：微小芝麻梭形支钉点
                                let d: CGFloat = 3.6
                                path.addEllipse(in: CGRect(x: pt.x - d / 2, y: pt.y - d / 2, width: d, height: d))
                            } else {
                                let d: CGFloat = 2.2
                                path.addEllipse(in: CGRect(x: pt.x - d / 2, y: pt.y - d / 2, width: d, height: d))
                            }
                        }
                    }
                    .fill(goldColor.opacity(0.68))

                case .breguet:
                    // 3. 微醺酒庄 · 古典宝玑星芒盘：内外精细花边轨 + 48 枚玫瑰金微珠 + 12 枚古典四芒菱星时标
                    Circle()
                        .stroke(goldColor.opacity(0.24), lineWidth: 0.65)
                    Circle()
                        .stroke(goldColor.opacity(0.16), lineWidth: 0.55)
                        .padding(6.5)

                    Path { path in
                        for i in 0..<60 where i % 5 != 0 {
                            let angle = Double(i) * 6.0 * .pi / 180.0
                            let r = radius - 3.2
                            let pt = CGPoint(x: center.x + r * sin(angle), y: center.y - r * cos(angle))
                            path.addEllipse(in: CGRect(x: pt.x - 0.75, y: pt.y - 0.75, width: 1.5, height: 1.5))
                        }
                    }
                    .fill(tickColor.opacity(0.22))

                    Path { path in
                        for i in stride(from: 0, to: 60, by: 5) {
                            let angle = Double(i) * 6.0 * .pi / 180.0
                            let rCenter = radius - 3.4
                            let len: CGFloat = (i % 15 == 0) ? 3.8 : 2.6
                            let wid: CGFloat = (i % 15 == 0) ? 1.8 : 1.2
                            let sinA = sin(angle)
                            let cosA = cos(angle)
                            // 沿半径方向的菱形星芒四顶点
                            let top = CGPoint(x: center.x + (rCenter + len) * sinA, y: center.y - (rCenter + len) * cosA)
                            let bottom = CGPoint(x: center.x + (rCenter - len) * sinA, y: center.y - (rCenter - len) * cosA)
                            let left = CGPoint(x: center.x + rCenter * sinA - wid * cosA, y: center.y - rCenter * cosA - wid * sinA)
                            let right = CGPoint(x: center.x + rCenter * sinA + wid * cosA, y: center.y - rCenter * cosA + wid * sinA)
                            path.move(to: top)
                            path.addLine(to: right)
                            path.addLine(to: bottom)
                            path.addLine(to: left)
                            path.closeSubpath()
                        }
                    }
                    .fill(goldColor.opacity(0.82))

                case .chronograph:
                    // 4. 深海蓝盘 · 深潜夜光领航盘：60 格精密潜水刻度 + 12 点位倒三角夜光锚点 + 3/6/9 加粗夜光柱
                    Path { path in
                        for i in 0..<60 where i % 5 != 0 {
                            let angle = Double(i) * 6.0 * .pi / 180.0
                            let r1 = radius
                            let r2 = radius - 4.2
                            path.move(to: CGPoint(x: center.x + r1 * sin(angle), y: center.y - r1 * cos(angle)))
                            path.addLine(to: CGPoint(x: center.x + r2 * sin(angle), y: center.y - r2 * cos(angle)))
                        }
                    }
                    .stroke(tickColor.opacity(0.22), lineWidth: 0.85)

                    Path { path in
                        for i in stride(from: 5, to: 60, by: 5) where i % 15 != 0 {
                            let angle = Double(i) * 6.0 * .pi / 180.0
                            let r1 = radius
                            let r2 = radius - 7.5
                            path.move(to: CGPoint(x: center.x + r1 * sin(angle), y: center.y - r1 * cos(angle)))
                            path.addLine(to: CGPoint(x: center.x + r2 * sin(angle), y: center.y - r2 * cos(angle)))
                        }
                    }
                    .stroke(goldColor.opacity(0.68), lineWidth: 1.7)

                    // 3 / 6 / 9 点位加粗夜光领航条
                    Path { path in
                        for i in [15, 30, 45] {
                            let angle = Double(i) * 6.0 * .pi / 180.0
                            let r1 = radius
                            let r2 = radius - 9.8
                            path.move(to: CGPoint(x: center.x + r1 * sin(angle), y: center.y - r1 * cos(angle)))
                            path.addLine(to: CGPoint(x: center.x + r2 * sin(angle), y: center.y - r2 * cos(angle)))
                        }
                    }
                    .stroke(goldColor, style: StrokeStyle(lineWidth: 2.8, lineCap: .round))

                    // 12 点位瑞士潜水表标志性倒三角夜光锚点
                    Path { path in
                        let triHalfW = max(3.2, radius * 0.045)
                        let triH = max(6.5, radius * 0.085)
                        path.move(to: CGPoint(x: center.x - triHalfW, y: center.y - radius + 0.5))
                        path.addLine(to: CGPoint(x: center.x + triHalfW, y: center.y - radius + 0.5))
                        path.addLine(to: CGPoint(x: center.x, y: center.y - radius + triH))
                        path.closeSubpath()
                    }
                    .fill(goldColor)

                case .enamel:
                    // 5. 大明火珐琅 · 铁轨准星盘：经典双环铁轨分钟圈（每5格加粗枕木）+ 细若游丝的古典十字准星线
                    Circle()
                        .stroke(tickColor.opacity(0.32), lineWidth: 0.75)
                    Circle()
                        .stroke(tickColor.opacity(0.24), lineWidth: 0.65)
                        .padding(5.5)

                    // 古典天文台表 Sector Dial 十字准星细线（仅在盘缘轻触）
                    Path { path in
                        for i in [0, 15, 30, 45] {
                            let angle = Double(i) * 6.0 * .pi / 180.0
                            let r1 = radius - 5.5
                            let r2 = radius - 12.5
                            path.move(to: CGPoint(x: center.x + r1 * sin(angle), y: center.y - r1 * cos(angle)))
                            path.addLine(to: CGPoint(x: center.x + r2 * sin(angle), y: center.y - r2 * cos(angle)))
                        }
                    }
                    .stroke(goldColor.opacity(0.45), lineWidth: 0.75)

                    Path { path in
                        for i in 0..<60 where i % 5 != 0 {
                            let angle = Double(i) * 6.0 * .pi / 180.0
                            let r1 = radius
                            let r2 = radius - 5.5
                            path.move(to: CGPoint(x: center.x + r1 * sin(angle), y: center.y - r1 * cos(angle)))
                            path.addLine(to: CGPoint(x: center.x + r2 * sin(angle), y: center.y - r2 * cos(angle)))
                        }
                    }
                    .stroke(tickColor.opacity(0.22), lineWidth: 0.65)

                    Path { path in
                        for i in stride(from: 0, to: 60, by: 5) {
                            let angle = Double(i) * 6.0 * .pi / 180.0
                            let r1 = radius
                            let r2 = radius - 5.5
                            path.move(to: CGPoint(x: center.x + r1 * sin(angle), y: center.y - r1 * cos(angle)))
                            path.addLine(to: CGPoint(x: center.x + r2 * sin(angle), y: center.y - r2 * cos(angle)))
                        }
                    }
                    .stroke(goldColor.opacity(0.85), lineWidth: 1.5)

                case .xuanInk:
                    // 6. 宣纸水墨 · 宣纸乌丝十二辰：宋刻本乌丝外粗内细双边栏 + 十二辰竖向乌丝界格 + 12 点位微型朱砂方印
                    Circle()
                        .stroke(tickColor.opacity(0.32), lineWidth: 1.1)
                    Circle()
                        .stroke(tickColor.opacity(0.18), lineWidth: 0.55)
                        .padding(3.2)

                    // 十二辰乌丝墨线时标（除 12 点位留给朱砂印外）
                    Path { path in
                        for i in stride(from: 5, to: 60, by: 5) {
                            let angle = Double(i) * 6.0 * .pi / 180.0
                            let r1 = radius - 3.2
                            let r2 = radius - (i % 15 == 0 ? 10.0 : 7.2)
                            path.move(to: CGPoint(x: center.x + r1 * sin(angle), y: center.y - r1 * cos(angle)))
                            path.addLine(to: CGPoint(x: center.x + r2 * sin(angle), y: center.y - r2 * cos(angle)))
                        }
                    }
                    .stroke(tickColor.opacity(0.55), style: StrokeStyle(lineWidth: 1.25, lineCap: .round))

                    // 12 点位微型西泠朱砂方印章（子时印信）
                    let sealSize = max(4.2, radius * 0.055)
                    RoundedRectangle(cornerRadius: 0.8)
                        .fill(Theme.wine.opacity(0.85))
                        .frame(width: sealSize, height: sealSize)
                        .position(x: center.x, y: center.y - radius + 5.5 + sealSize / 2)
                }
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
                    .stroke(isSelected ? Theme.gold : Theme.borderSubtle, lineWidth: isSelected ? 1.2 : 0.8)
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
            Image(systemName: Theme.current.icon)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Theme.goldBright)
        }
    }
}

// MARK: - 主题雅集组件：微缩表盘徽章与名表主题品鉴抽屉

struct ThemeMiniDialBadge: View {
    let theme: AppTheme
    var size: CGFloat = 42

    var body: some View {
        let pal = Theme.palette(for: theme)
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: pal.isLight ? [pal.raised, pal.surface] : [pal.surface, pal.bg],
                        center: .center,
                        startRadius: 2,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(pal.gold.opacity(0.48), lineWidth: 1.0)
                )

            // 外环流逝金弧
            Circle()
                .trim(from: 0, to: 0.68)
                .stroke(pal.goldBright, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size * 0.78, height: size * 0.78)

            // 内环酒量弧
            Circle()
                .stroke(pal.faint, lineWidth: 2.6)
                .frame(width: size * 0.56, height: size * 0.56)

            Circle()
                .trim(from: 0, to: 0.52)
                .stroke(
                    LinearGradient(colors: [pal.gold, pal.wine], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size * 0.56, height: size * 0.56)

            Image(systemName: theme.icon)
                .font(.system(size: size * 0.25, weight: .medium))
                .foregroundStyle(pal.goldBright)
        }
    }
}

struct ThemeGallerySheet: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let currentTheme = store.settings.selectedTheme

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // 1. 顶部抬头
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("表盘与席间主题雅集")
                            .font(.system(size: 24, weight: .light, design: .serif))
                            .foregroundStyle(Theme.cream)
                        Text("涵盖 3 款温润淡雅浅色盘（汝窑 / 珐琅 / 宣纸）与 3 款深邃夜宴盘")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                    }
                    Spacer()
                    Button("完成") {
                        dismiss()
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Theme.surface))
                    .foregroundStyle(Theme.goldBright)
                    .buttonStyle(.plain)
                }
                .padding(.top, 22)

                // 2. 当前选中主题的实时微缩陀飞轮表盘预览卡
                liveDialPreviewBanner(for: currentTheme)

                // 3. 六大主题品鉴列表
                VStack(spacing: 12) {
                    ForEach(AppTheme.allCases) { theme in
                        themeDetailCard(theme, isSelected: currentTheme == theme)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
    }

    private func liveDialPreviewBanner(for theme: AppTheme) -> some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: Theme.isLight
                                ? [Theme.raised, Theme.surface.opacity(0.8)]
                                : [Theme.surface.opacity(0.85), Theme.bg],
                            center: .center,
                            startRadius: 5,
                            endRadius: 56
                        )
                    )
                    .frame(width: 112, height: 112)
                    .overlay(Circle().stroke(Theme.bezelGradient, lineWidth: 1.3))
                    .shadow(color: Theme.dialShadow, radius: 12, y: 5)

                DialTicksView(style: theme.dialStyle)
                    .frame(width: 102, height: 102)

                Circle()
                    .trim(from: 0, to: 0.62)
                    .stroke(Theme.goldBright, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 88, height: 88)

                SegmentedBeverageRing(
                    totalSegments: 6,
                    softSegments: 4,
                    confirmedRatio: 0.48,
                    totalRatio: 0.65,
                    isOverSoft: false,
                    isOverHard: false
                )
                .frame(width: 72, height: 72)

                VStack(spacing: 1) {
                    Text("微 醺")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(Theme.sage)
                    Text("2 两")
                        .font(.system(size: 16, weight: .light, design: .serif))
                        .foregroundStyle(Theme.cream)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("当前选用 · \(theme.name)")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.cream)
                    Text(theme.modeTag)
                        .font(.system(size: 9.5, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.gold.opacity(0.18)))
                        .foregroundStyle(Theme.goldBright)
                }

                Text("\(theme.subtitle) · \(theme.dialStyle.displayName)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.gold)

                Text(theme.poeticDescription)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.raised)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.bezelGradient, lineWidth: 1.2))
        )
    }

    private func themeDetailCard(_ theme: AppTheme, isSelected: Bool) -> some View {
        let pal = Theme.palette(for: theme)
        return Button {
            withAnimation(.smooth(duration: 0.3)) {
                store.selectTheme(theme)
            }
        } label: {
            HStack(spacing: 14) {
                ThemeMiniDialBadge(theme: theme, size: 50)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(theme.name)
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(pal.cream)

                        Text(theme.modeTag)
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(pal.gold.opacity(0.18)))
                            .foregroundStyle(pal.gold)

                        Text(theme.dialStyle.displayName)
                            .font(.system(size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(pal.surface))
                            .foregroundStyle(pal.mute)
                    }

                    Text(theme.poeticDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(pal.mute)
                        .lineLimit(2)

                    // 主题五色釉彩标本条
                    HStack(spacing: 6) {
                        colorDot(pal.bg, border: pal.gold.opacity(0.4))
                        colorDot(pal.surface, border: pal.gold.opacity(0.3))
                        colorDot(pal.gold, border: .clear)
                        colorDot(pal.wine, border: .clear)
                        colorDot(pal.sage, border: .clear)
                        colorDot(pal.cream, border: pal.gold.opacity(0.3))
                        Spacer()
                    }
                    .padding(.top, 2)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? pal.goldBright : pal.mute.opacity(0.45))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(pal.raised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ? pal.gold : (pal.isLight ? pal.gold.opacity(0.22) : Color.white.opacity(0.08)),
                        lineWidth: isSelected ? 1.5 : 0.8
                    )
            )
            .shadow(color: isSelected ? pal.gold.opacity(0.20) : .clear, radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func colorDot(_ color: Color, border: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 11, height: 11)
            .overlay(Circle().stroke(border, lineWidth: 0.6))
    }
}

struct LogLine: Identifiable {
    let id: UUID
    let at: Date
    let text: String
    let color: Color
    var promptID: UUID? = nil
}
