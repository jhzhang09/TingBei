import SwiftUI
import Charts

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
                        // 样式放进 label：修饰在 Button 外时只有文字本身可点
                        Button {
                            minutesAgo = min
                        } label: {
                            Text(min == 0 ? "刚才" : "\(min)分钟前")
                                .font(.caption.weight(minutesAgo == min ? .semibold : .regular))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(minutesAgo == min ? Theme.gold : Theme.raised))
                                .foregroundStyle(minutesAgo == min ? Theme.ink : (disabled ? Theme.mute.opacity(0.3) : Theme.cream))
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(disabled)
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

            // 本场节奏曲线：实际（含推测）对照方案节奏，帮助下次定线
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("本场节奏")
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.cream)
                    Spacer()
                    Text("实线 实际 · 虚线 方案")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.mute)
                }
                PaceCurveChart(session: session)
                    .frame(height: 150)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.raised)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.subtleCardStroke, lineWidth: 1))
            )
            .padding(.horizontal, 24)

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

// MARK: - 复盘节奏曲线

/// 以本场酒种的物理单位绘制累计杯量（确认 + 推测）随时间的阶梯曲线，
/// 叠加方案节奏（预定时长内匀速到达建议线）与建议线 / 上限两条横线。
struct PaceCurveChart: View {
    let session: Session

    private struct Point: Identifiable {
        let id: Int
        let minute: Double
        let value: Double
    }

    var body: some View {
        let cat = session.beverageCategory
        let end = session.endedAt ?? Date()
        let total = max(60, end.timeIntervalSince(session.startedAt))
        // 约 48 个采样点足以表现阶梯变化，不随时长线性膨胀
        let step = max(60, total / 48)
        let samples = Array(stride(from: 0.0, to: total, by: step)) + [total]
        let points = samples.enumerated().map { index, offset in
            Point(
                id: index,
                minute: offset / 60,
                value: cat.physicalValue(from: session.units(at: session.startedAt.addingTimeInterval(offset)))
            )
        }
        let soft = cat.physicalValue(from: session.softLimit)
        let hard = cat.physicalValue(from: session.hardLimit)
        let planMinutes = session.plannedSeconds / 60
        let yMax = max(hard, points.map(\.value).max() ?? 0) * 1.15

        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("分钟", point.minute),
                    y: .value("杯量", point.value),
                    series: .value("类型", "实际")
                )
                .interpolationMethod(.stepEnd)
                .foregroundStyle(Theme.gold)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            LineMark(x: .value("分钟", 0.0), y: .value("杯量", 0.0), series: .value("类型", "方案"))
                .foregroundStyle(Theme.mute)
                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
            LineMark(x: .value("分钟", planMinutes), y: .value("杯量", soft), series: .value("类型", "方案"))
                .foregroundStyle(Theme.mute)
                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))

            RuleMark(y: .value("建议线", soft))
                .foregroundStyle(Theme.caution.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .annotation(position: .top, alignment: .leading) {
                    Text("建议线 \(cat.formatPhysical(from: session.softLimit))")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.caution)
                }
            RuleMark(y: .value("上限", hard))
                .foregroundStyle(Theme.wine.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .annotation(position: .top, alignment: .leading) {
                    Text("上限 \(cat.formatPhysical(from: session.hardLimit))")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.wine)
                }
        }
        .chartYScale(domain: 0...max(yMax, 1))
        .chartXScale(domain: 0...max(total / 60, planMinutes))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Theme.faint)
                AxisValueLabel {
                    if let minute = value.as(Double.self) {
                        Text(Format.hm(minute * 60))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.mute)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Theme.faint)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(Format.units(amount))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.mute)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("本场节奏曲线")
        .accessibilityValue("结束时约 \(cat.formatPhysical(from: session.units(at: end)))，建议线 \(cat.formatPhysical(from: session.softLimit))")
    }
}

// MARK: - 声律与推测设置抽屉

/// 与主题雅集抽屉同款的向上弹出抽屉：首页只留一行入口，设置项在抽屉里一屏看全，不必在首页向下展开再滑动。
struct PreferencesSheet: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        @Bindable var store = store
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("声律与推测")
                            .font(.system(size: 24, weight: .light, design: .serif))
                            .foregroundStyle(Theme.cream)
                        Text("提醒音色 · 静默推测 · 表盘常亮")
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

                // 1. 提醒音色：两列器物卡，点按即试听
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("提醒音色", hint: "点按即可试听")
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(NotificationSoundOption.allCases) { opt in
                            soundTile(opt, isSelected: store.settings.notificationSound == opt)
                        }
                    }
                    Button {
                        store.scheduleTestNotification()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bell.badge.waveform.fill")
                            Text("发送 5 秒后锁屏测试通知")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.goldBright)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.gold.opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.35), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }

                // 2. 席间习惯：两个开关同卡
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("席间习惯", hint: nil)
                    VStack(spacing: 0) {
                        preferenceToggle(
                            isOn: $store.settings.estimateWhenSilent,
                            title: "未回应时按节奏推测",
                            detail: "酒桌不便看手机时自动推进节拍，盘中以虚线显示，可随时一键消除"
                        )
                        Divider().background(Theme.faint).padding(.leading, 16)
                        preferenceToggle(
                            isOn: $store.settings.keepScreenOn,
                            title: "席间表盘常亮",
                            detail: "把手机立在桌上当座钟时开启"
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Theme.raised)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.subtleCardStroke, lineWidth: 1))
                    )
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
        .onChange(of: store.settings.estimateWhenSilent) { _, _ in
            store.normalizeAndSaveSettings()
        }
        .onChange(of: store.settings.keepScreenOn) { _, _ in
            store.normalizeAndSaveSettings()
        }
    }

    private func sectionTitle(_ title: String, hint: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundStyle(Theme.cream)
            Spacer()
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(Theme.mute)
            }
        }
    }

    private func soundTile(_ opt: NotificationSoundOption, isSelected: Bool) -> some View {
        Button {
            store.settings.notificationSound = opt
            store.previewSound(opt)
            store.normalizeAndSaveSettings()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.gold.opacity(0.22) : Theme.surface)
                        .frame(width: 34, height: 34)
                    Image(systemName: isSelected ? "speaker.wave.2.fill" : "play.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(isSelected ? Theme.goldBright : Theme.mute)
                }
                Text(opt.displayName)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular, design: .serif))
                    .foregroundStyle(isSelected ? Theme.cream : Theme.cream.opacity(0.85))
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.goldBright)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.raised)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Theme.gold : Theme.faint, lineWidth: isSelected ? 1.2 : 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func preferenceToggle(isOn: Binding<Bool>, title: String, detail: String) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(Theme.cream)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Theme.gold)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - 主题雅集抽屉

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
                        Text("清昼三款：汝窑 · 界画 · 宣纸；夜宴三款：玄漆 · 琥珀 · 霁蓝")
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
                        .font(.system(size: 11, weight: .semibold))
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
                        .font(.system(size: 11, weight: .semibold))
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
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(pal.gold.opacity(0.18)))
                            .foregroundStyle(pal.gold)

                        Text(theme.dialStyle.displayName)
                            .font(.system(size: 11))
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
