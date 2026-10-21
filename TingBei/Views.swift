import SwiftUI
import UIKit

enum Theme {
    static let bg = Color(red: 0.078, green: 0.055, blue: 0.039)
    static let raised = Color(red: 0.16, green: 0.11, blue: 0.082)
    static let surface = Color(red: 0.22, green: 0.15, blue: 0.11)
    static let cream = Color(red: 0.96, green: 0.91, blue: 0.84)
    static let mute = Color(red: 0.96, green: 0.91, blue: 0.84).opacity(0.64)
    static let faint = Color(red: 0.96, green: 0.91, blue: 0.84).opacity(0.14)
    static let amber = Color(red: 0.91, green: 0.63, blue: 0.28)
    static let wine = Color(red: 0.74, green: 0.28, blue: 0.22)
    static let sage = Color(red: 0.66, green: 0.73, blue: 0.52)
    static let water = Color(red: 0.45, green: 0.72, blue: 0.88)
    static let ink = Color(red: 0.11, green: 0.07, blue: 0.05)

    static func tint(_ cue: Cue) -> Color {
        switch cue {
        case .calm, .settle:
            sage
        case .hurried, .near:
            amber
        case .due, .over:
            wine
        }
    }
}

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
        .tint(Theme.amber)
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

struct NightBackground: View {
    var cue: Cue?

    var body: some View {
        let heat = heat(for: cue)
        ZStack {
            Theme.bg
            RadialGradient(
                colors: [
                    Theme.amber.opacity(0.20 * (1 - heat) + 0.04),
                    Theme.wine.opacity(0.48 * heat),
                    .clear,
                ],
                center: .top,
                startRadius: 8,
                endRadius: 540
            )
        }
        .ignoresSafeArea()
        .animation(.smooth(duration: 0.5), value: cue)
    }

    private func heat(for cue: Cue?) -> Double {
        switch cue {
        case nil, .calm:
            0
        case .settle:
            0.12
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

struct HomeView: View {
    @Environment(SessionStore.self) private var store
    @State private var isCustomExpanded = false

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                VStack(spacing: 12) {
                    PlanCard(plan: .light) { store.start(.light) }
                    PlanCard(plan: .dinner) { store.start(.dinner) }
                }
                customSection
                if !store.history.isEmpty {
                    historySection
                }
                footnote
                signatureBadge
                if store.saveFailed {
                    Text("这场记录没能写进手机。")
                        .font(.footnote)
                        .foregroundStyle(Theme.wine)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                CupMark()
                Text("停杯")
                    .font(.system(size: 40, weight: .light, design: .serif))
                    .foregroundStyle(Theme.cream)
            }
            Text("开喝之后，按你设定的标准杯、杯间间隔和时间，逐步提醒你节奏与收杯。")
                .font(.body)
                .foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
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
                        Text("自定义目标")
                            .font(.system(.title3, design: .serif))
                            .foregroundStyle(Theme.cream)
                        Text("\(store.settings.softLimit) 标准杯 · \(Format.minutes(store.settings.plannedMinutes)) · 间隔 \(store.settings.minIntervalMinutes) 分钟")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                    }
                    Spacer()
                    Image(systemName: isCustomExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Theme.amber)
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
                    title: "两杯至少间隔",
                    value: "\(store.settings.minIntervalMinutes) 分钟",
                    range: 10...90,
                    step: 5,
                    valueBinding: Bindable(store).settings.minIntervalMinutes
                )
                Toggle(isOn: Bindable(store).settings.keepScreenOn) {
                    Text("开喝后屏幕不自动锁屏")
                        .foregroundStyle(Theme.cream)
                }
                .tint(Theme.amber)

                FillButton(title: "按此目标开始", color: Theme.amber) {
                    store.start(store.settings.plan)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("历史记录")
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
        Text("一个标准杯按 14 克乙醇（纯酒精）计算：啤酒 330ml 约 0.9 杯，500ml 约 1.3 杯，白酒一两约 1.5 杯。本应用旨在提醒节奏，不能用于评测酒精浓度，严禁酒后驾车。")
            .font(.footnote)
            .foregroundStyle(Theme.mute)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var signatureBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(store.signatureStatus.daysRemaining != nil && store.signatureStatus.daysRemaining! > 1 ? Theme.sage : Theme.amber)
                .frame(width: 6, height: 6)
            Text(store.signatureStatus.displayText)
                .font(.caption2)
                .foregroundStyle(Theme.mute)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(Theme.raised))
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 2)
    }
}

struct SessionView: View {
    @Environment(SessionStore.self) private var store
    @State private var showingDrinks = false
    @State private var confirmingEnd = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 22)
                .padding(.top, 8)
            ScrollView {
                VStack(spacing: 16) {
                    if let snap = store.snapshot, let session = store.active {
                        metricDashboard(snap, session: session)
                        cooldownAndHydrationBanner(snap)
                        cueCard(snap)
                        if store.notificationPermission == .denied {
                            notificationNotice
                        }
                        if let next = Pace.plannedCues(session: session, now: store.now).first {
                            HStack(spacing: 6) {
                                Image(systemName: "bell.badge")
                                    .font(.caption2)
                                Text("下次预排提醒 · \(Format.until(next.at, now: store.now)) · \(next.title)")
                                    .font(.footnote)
                            }
                            .foregroundStyle(Theme.mute)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        sessionLogs(session)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            actions
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 6)
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
            Text("结束后将停止锁屏与定时提醒。记录将留存在本机历史中。")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.snapshot?.title ?? "停杯")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Theme.cream)
                if let session = store.active {
                    Text("目标 \(session.softLimit) 标准杯 · 限时 \(Format.minutes(session.plannedMinutes)) · 间隔 \(session.minIntervalMinutes) 分")
                        .font(.caption)
                        .foregroundStyle(Theme.mute)
                }
            }
            Spacer()
            Button("结束") { confirmingEnd = true }
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.cream)
        }
    }

    private func metricDashboard(_ snap: PaceSnapshot, session: Session) -> some View {
        VStack(spacing: 12) {
            ZStack {
                let soft = Double(max(session.softLimit, 1))
                let progress = min(1.0, snap.standardDrinks / soft)
                let tint = Theme.tint(snap.cue)

                // Background track
                Circle()
                    .stroke(Theme.faint, lineWidth: 14)

                // Main progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.4), value: progress)

                // Overflow indicator if exceeded soft limit
                if snap.standardDrinks > soft {
                    let hard = Double(max(session.hardLimit, session.softLimit + 1))
                    let overflowRatio = min(1.0, (snap.standardDrinks - soft) / (hard - soft))
                    Circle()
                        .trim(from: 0, to: overflowRatio * 0.99)
                        .stroke(Theme.wine, style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [4, 6]))
                        .rotationEffect(.degrees(-90))
                        .scaleEffect(1.12)
                }

                // Center information
                VStack(spacing: 4) {
                    Text(Format.units(snap.standardDrinks))
                        .font(.system(size: 56, weight: .light, design: .serif))
                        .foregroundStyle(Theme.cream)
                        .contentTransition(.numericText())
                    Text("/ \(session.softLimit) 标准杯")
                        .font(.subheadline)
                        .foregroundStyle(Theme.mute)
                    HStack(spacing: 8) {
                        Text("酒 \(snap.drinkCount) 次")
                        Text("·")
                        Text("水 \(snap.waterCount) 次")
                            .foregroundStyle(snap.waterCount > 0 ? Theme.water : Theme.mute)
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.mute)
                }
            }
            .frame(width: 220, height: 220)
            .padding(.vertical, 8)

            // Secondary stats bar
            HStack(spacing: 18) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(Theme.mute)
                    Text("已喝 \(Format.clock(snap.elapsed))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.cream)
                }
                Text("·").foregroundStyle(Theme.mute)
                HStack(spacing: 6) {
                    Image(systemName: "hourglass")
                        .font(.caption)
                        .foregroundStyle(Theme.mute)
                    Text("预定 \(Format.minutes(session.plannedMinutes))")
                        .font(.subheadline)
                        .foregroundStyle(Theme.mute)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.raised))
        }
    }

    private func cooldownAndHydrationBanner(_ snap: PaceSnapshot) -> some View {
        VStack(spacing: 8) {
            if snap.isTooFast {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.wine)
                        .symbolEffect(.pulse)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("上两杯喝得太急")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.cream)
                        Text("建议先停歇约 \(snap.waitMinutes) 分钟，喝口水缓一缓。")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                    }
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.wine.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.wine.opacity(0.4), lineWidth: 1)
                )
            } else if snap.cooldownRemaining > 0 && snap.drinkCount > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "drop.degreesign")
                        .font(.title3)
                        .foregroundStyle(Theme.sage)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("杯间建议缓冲中 · 距下一杯还剩 \(Format.clock(snap.cooldownRemaining))")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.cream)
                        Text("不急着续杯，给身体一点代谢时间，先喝口水。")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                    }
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.sage.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.sage.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    private func cueCard(_ snap: PaceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.tint(snap.cue))
                    .frame(width: 8, height: 8)
                Text(snap.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.cream)
            }
            Text(snap.message)
                .font(.body)
                .foregroundStyle(Theme.cream)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.tint(snap.cue).opacity(snap.cue == .over || snap.cue == .due ? 0.22 : 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.tint(snap.cue).opacity(0.6), lineWidth: 1)
        )
        .id(store.bannerPulse)
    }

    private var notificationNotice: some View {
        Button {
            store.openNotificationSettings()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bell.slash")
                Text("通知未授权。锁屏时无法及时提醒节奏，点此前往设置开启。")
                    .font(.footnote)
            }
            .foregroundStyle(Theme.amber)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.amber.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private func sessionLogs(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("本次明细")
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Theme.cream)
                Spacer()
                if !session.drinks.isEmpty || !session.waters.isEmpty {
                    Button("撤销上一条") { store.undoLast() }
                        .font(.footnote)
                        .foregroundStyle(Theme.mute)
                }
            }
            if session.drinks.isEmpty && session.waters.isEmpty {
                Text("暂无记录。喝下第一口时请点击「记一杯」。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.mute)
            } else {
                ForEach(lines(session)) { line in
                    HStack(alignment: .firstTextBaseline) {
                        Text(Format.shortTime(line.at))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Theme.mute)
                            .frame(width: 56, alignment: .leading)
                        Text(line.text)
                            .font(.body)
                            .foregroundStyle(line.isWater ? Theme.water : Theme.cream)
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if let toast = store.toast {
                Text(toast)
                    .font(.footnote)
                    .foregroundStyle(Theme.sage)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if store.snapshot?.cue == .over {
                FillButton(title: "我停了 · 结束本场", color: Theme.wine, foreground: Theme.cream) {
                    store.end()
                }
                HoldButton(title: "按住再记一杯", subtitle: "按住约两秒以确认") {
                    showingDrinks = true
                }
                Button("喝了水") { store.logWater() }
                    .font(.body)
                    .foregroundStyle(Theme.water)
                    .frame(minHeight: 36)
            } else {
                HStack(spacing: 10) {
                    OutlineButton(title: "喝了水", systemImage: "drop.fill", foreground: Theme.water) {
                        store.logWater()
                    }
                    FillButton(title: "记一杯", systemImage: "plus", color: Theme.amber) {
                        showingDrinks = true
                    }
                }
                if store.snapshot?.cue == .due {
                    Button("已到目标，结束这场") { confirmingEnd = true }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.wine)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
    }

    private func lines(_ session: Session) -> [LogLine] {
        let drinks = session.drinks.map { drink in
            LogLine(
                id: drink.id,
                at: drink.at,
                text: "\(drink.name) \(drink.detail) · \(Format.units(drink.grams / Pace.gramsPerStandard)) 标准杯",
                isWater: false
            )
        }
        let waters = session.waters.map { water in
            LogLine(id: water.id, at: water.at, text: "💧 喝了水", isWater: true)
        }
        return (drinks + waters).sorted { $0.at > $1.at }
    }
}

struct DrinkSheet: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var tab = 0
    @State private var customName = ""
    @State private var customVolume: Double = 330
    @State private var customAbv: Double = 5.0

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("记录这杯")
                    .font(.system(size: 28, weight: .light, design: .serif))
                    .foregroundStyle(Theme.cream)
                Spacer()
                Picker("类型", selection: $tab) {
                    Text("预设酒类").tag(0)
                    Text("自选规格").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            .padding(.top, 12)

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
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Pace.presets) { preset in
                    Button {
                        store.log(preset)
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
                                .foregroundStyle(Theme.amber)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.raised)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.cream)
                }
            }
            Text("按常见酒精度折算：啤酒约4~5%，红酒约12~13%，白酒按50度估算。")
                .font(.footnote)
                .foregroundStyle(Theme.mute)
        }
    }

    private var customDrinkForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("酒品名称（可选）")
                    .font(.caption)
                    .foregroundStyle(Theme.mute)
                TextField("如：精酿 IPA、单一麦芽威士忌", text: $customName)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.raised))
                    .foregroundStyle(Theme.cream)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("容量")
                        .foregroundStyle(Theme.mute)
                    Spacer()
                    Text("\(Int(customVolume)) ml")
                        .foregroundStyle(Theme.cream)
                        .font(.body.monospacedDigit())
                }
                Slider(value: $customVolume, in: 20...1000, step: 10)
                    .tint(Theme.amber)
                HStack(spacing: 8) {
                    ForEach([50, 150, 330, 500], id: \.self) { ml in
                        Button("\(ml)ml") { customVolume = Double(ml) }
                            .font(.caption2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.raised))
                            .foregroundStyle(customVolume == Double(ml) ? Theme.amber : Theme.mute)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("酒精度 (ABV)")
                        .foregroundStyle(Theme.mute)
                    Spacer()
                    Text(String(format: "%.1f %%", customAbv))
                        .foregroundStyle(Theme.cream)
                        .font(.body.monospacedDigit())
                }
                Slider(value: $customAbv, in: 1...65, step: 0.5)
                    .tint(Theme.amber)
                HStack(spacing: 8) {
                    ForEach([4.5, 12.0, 40.0, 52.0], id: \.self) { abv in
                        Button(String(format: "%.1f%%", abv)) { customAbv = abv }
                            .font(.caption2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.raised))
                            .foregroundStyle(customAbv == abv ? Theme.amber : Theme.mute)
                    }
                }
            }

            let calcGrams = customVolume * (customAbv / 100.0) * 0.8
            let calcUnits = calcGrams / Pace.gramsPerStandard

            HStack {
                Text("折合约 \(Format.units(calcUnits)) 标准杯")
                    .font(.headline)
                    .foregroundStyle(Theme.amber)
                Spacer()
                Text("纯酒精约 \(Int(calcGrams))g")
                    .font(.caption)
                    .foregroundStyle(Theme.mute)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.raised))

            FillButton(title: "记录这一杯", color: Theme.amber) {
                store.logCustom(name: customName, volumeMl: customVolume, abv: customAbv)
                dismiss()
            }
        }
    }
}

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
                statRow(title: "持续时长", value: Format.clock(session.duration))
                Divider().background(Theme.faint)
                statRow(title: "总摄入量", value: "\(Format.units(session.standardDrinks)) 标准杯 (\(session.drinks.count) 次)")
                Divider().background(Theme.faint)
                statRow(title: "补水次数", value: "\(session.waters.count) 次")
            }
            .padding(18)
            .background(CardChrome())

            if session.waters.count >= session.drinks.count && !session.drinks.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.water)
                    Text("今晚水喝得很及时，给身体留足了恢复缓冲。")
                        .font(.footnote)
                        .foregroundStyle(Theme.cream)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.water.opacity(0.12)))
            }

            Spacer()
            FillButton(title: "完成", color: Theme.amber) {
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

struct PlanCard: View {
    let plan: Plan
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.system(.title2, design: .serif))
                        .foregroundStyle(Theme.cream)
                    Text(plan.detail)
                        .font(.subheadline)
                        .foregroundStyle(Theme.mute)
                    Text("警戒线 \(plan.hardLimit) · 两杯至少隔 \(plan.minIntervalMinutes) 分钟")
                        .font(.caption)
                        .foregroundStyle(Theme.mute)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(Theme.amber)
            }
            .padding(18)
            .background(CardChrome())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(plan.name)，\(plan.detail)")
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
                Text("\(Format.clock(session.duration)) · \(Format.units(session.standardDrinks)) 标准杯")
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
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(foreground)
            .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct OutlineButton: View {
    var title: String
    var systemImage: String?
    var foreground: Color = Theme.cream
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
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(foreground)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.faint, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct HoldButton: View {
    var title: String
    var subtitle: String
    var action: () -> Void
    @State private var holding = false

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
            Text(holding ? "继续按住确认..." : subtitle)
                .font(.caption)
                .opacity(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .foregroundStyle(Theme.cream)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.wine.opacity(0.22))
            GeometryReader { geo in
                Rectangle()
                    .fill(Theme.wine)
                    .frame(width: holding ? geo.size.width : 0)
                    .animation(holding ? .linear(duration: 1.4) : .easeOut(duration: 0.15), value: holding)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.wine.opacity(0.8), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onLongPressGesture(minimumDuration: 1.4, maximumDistance: 44) {
            holding = false
            action()
        } onPressingChanged: { pressing in
            holding = pressing
        }
        .accessibilityHint("按住大约两秒才会打开记杯")
    }
}

struct CupMark: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.amber, lineWidth: 1.5)
            Image(systemName: "wineglass")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Theme.cream)
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}

private struct LogLine: Identifiable {
    var id: UUID
    var at: Date
    var text: String
    var isWater: Bool
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
