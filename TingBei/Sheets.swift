import SwiftUI
import Charts
import UniformTypeIdentifiers

// MARK: - 本场时间轴明细抽屉 (Timeline Drawer Sheet)

struct TimelineDrawerSheet: View {
    let session: Session
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private struct DrawerLine: Identifiable {
        let id: UUID
        let at: Date
        let text: String
        let color: Color
        var promptID: UUID? = nil
        var drinkID: UUID? = nil
        var waterID: UUID? = nil
    }

    var body: some View {
        let current = store.active ?? session
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("席间时间轴明细")
                        .font(.system(size: 22, weight: .light, design: .serif))
                        .foregroundStyle(Theme.cream)
                    Text("可随时撤销或逐条删除误记，也可逐条校准静默推测")
                        .font(.caption)
                        .foregroundStyle(Theme.mute)
                }
                Spacer()
                if !current.drinks.isEmpty || !current.waters.isEmpty {
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
                                } else if let drinkID = line.drinkID {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            store.deleteDrink(id: drinkID)
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundStyle(Theme.mute.opacity(0.65))
                                            .frame(minWidth: 44, minHeight: 34)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("删除这条饮酒记录")
                                } else if let waterID = line.waterID {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            store.deleteWater(id: waterID)
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundStyle(Theme.mute.opacity(0.65))
                                            .frame(minWidth: 44, minHeight: 34)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("删除这条喝水记录")
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

    private func buildLines() -> [DrawerLine] {
        guard let currentSession = store.active else { return [] }
        var items: [DrawerLine] = []
        for drink in currentSession.drinks {
            items.append(DrawerLine(id: drink.id, at: drink.at, text: "\(drink.name) · \(drink.detail)", color: Theme.cream, drinkID: drink.id))
        }
        for water in currentSession.waters {
            items.append(DrawerLine(id: water.id, at: water.at, text: "💧 喝了一杯水", color: Theme.water, waterID: water.id))
        }
        for prompt in currentSession.prompts where prompt.reply == nil && prompt.at <= store.now {
            let cat = currentSession.beverageCategory
            let text = prompt.semanticText ?? "◌ 节奏推测 · 约 \(cat.formatPhysical(from: prompt.projectedUnits))"
            items.append(DrawerLine(id: prompt.id, at: prompt.at, text: text, color: prompt.level == .over ? Theme.wine : Theme.gold, promptID: prompt.id))
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
    @State private var customCategory: BeverageCategory = .beer
    @State private var saveAsPreset = true
    @State private var minutesAgo: Int = 0
    @State private var initializedCategory = false

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
        .onAppear {
            guard !initializedCategory else { return }
            initializedCategory = true
            customCategory = store.active?.beverageCategory ?? store.settings.selectedBeverageCategory
        }
    }

    private var presetGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !store.settings.savedPresets.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("我的常喝")
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundStyle(Theme.goldBright)
                        Spacer()
                        Text("自选保存的惯常酒单")
                            .font(.caption2)
                            .foregroundStyle(Theme.mute)
                    }
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.settings.savedPresets) { preset in
                            ZStack(alignment: .topTrailing) {
                                Button {
                                    store.logDrink(preset: preset, at: targetLogTime)
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(preset.name)
                                            .font(.system(.title3, design: .serif))
                                            .lineLimit(1)
                                        Text(preset.detail)
                                            .font(.subheadline)
                                            .foregroundStyle(Theme.mute)
                                            .lineLimit(1)
                                        HStack(spacing: 4) {
                                            Text(preset.resolvedCategory.name)
                                                .font(.caption2)
                                                .foregroundStyle(Theme.mute)
                                            Text("·")
                                                .foregroundStyle(Theme.mute)
                                            Text("约 \(Format.units(preset.standardDrinks)) 杯")
                                                .font(.caption)
                                                .foregroundStyle(Theme.gold)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Theme.raised)
                                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.gold.opacity(0.32), lineWidth: 1))
                                    )
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Theme.cream)

                                Button {
                                    withAnimation {
                                        store.deleteSavedPreset(id: preset.id)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Theme.mute.opacity(0.7))
                                        .padding(10)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("移除常喝 \(preset.name)")
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                if !store.settings.savedPresets.isEmpty {
                    Text("内置酒单")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.mute)
                }
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
        }
    }

    private var customDrinkForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("酒品名称，如精酿 IPA / 威士忌", text: $customName)
                .textFieldStyle(.plain)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                .foregroundStyle(Theme.cream)

            VStack(alignment: .leading, spacing: 8) {
                Text("所属酒种（用于统计分布）")
                    .font(.caption)
                    .foregroundStyle(Theme.mute)
                HStack(spacing: 8) {
                    ForEach(BeverageCategory.allCases) { cat in
                        let selected = customCategory == cat
                        Button {
                            customCategory = cat
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 11))
                                Text(cat == .custom ? "其他" : cat.name)
                                    .font(.caption.weight(selected ? .semibold : .regular))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(selected ? Theme.gold : Theme.surface))
                            .foregroundStyle(selected ? Theme.ink : Theme.cream)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

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

            Toggle(isOn: $saveAsPreset) {
                Text("收藏至「我的常喝」，下次一点即记")
                    .font(.caption)
                    .foregroundStyle(Theme.cream)
            }
            .tint(Theme.gold)

            let calcGrams = customVolume * (customAbv / 100.0) * 0.8
            let calcUnits = calcGrams / Pace.gramsPerStandard

            HStack {
                Text("折合约 \(Format.units(calcUnits)) 标准杯")
                    .font(.caption)
                    .foregroundStyle(Theme.gold)
                Spacer()
                Button("记录这杯") {
                    store.logCustom(
                        name: customName,
                        volumeMl: customVolume,
                        abv: customAbv,
                        category: customCategory,
                        saveToPresets: saveAsPreset,
                        at: targetLogTime
                    )
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
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var feeling: FeelingTag?
    @State private var noteText = ""
    @State private var initializedReview = false
    @State private var isEditing = false
    @State private var addingDrink = false
    @State private var selectedAddPresetID: String = Pace.presets[0].id
    @State private var addItemTime: Date = Date()

    private struct SummaryEvent: Identifiable {
        let id: String
        let at: Date
        let order: Int
        let title: String
        let badge: String?
        let color: Color
        var drinkID: UUID? = nil
        var waterID: UUID? = nil
    }

    private var liveSession: Session {
        if let archived = store.history.first(where: { $0.id == session.id }) {
            return archived
        }
        if let rev = store.review, rev.id == session.id {
            return rev
        }
        return session
    }

    private var isArchived: Bool {
        store.history.contains { $0.id == session.id }
    }

    var body: some View {
        let current = liveSession
        let end = current.endedAt ?? Date()
        let outcome = current.outcome(at: end)
        let cat = current.beverageCategory
        let units = current.units(at: end)
        let confirmed = current.confirmedUnits(at: end)
        let estimated = current.estimatedUnits(at: end)
        let confirmedBreakdown = current.beverageBreakdown(at: end, includeEstimated: false)
        let isMixed = confirmedBreakdown.count > 1
        let events = buildEvents(session: current, end: end, outcome: outcome, category: cat)

        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        Text("席 间 复 盘")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(3)
                            .foregroundStyle(Theme.gold)
                        Spacer()
                    }
                    .overlay(alignment: .trailing) {
                        if isArchived {
                            Button(isEditing ? "完成修正" : "修正记录") {
                                withAnimation(.smooth(duration: 0.22)) {
                                    isEditing.toggle()
                                    if isEditing {
                                        addItemTime = end
                                    } else {
                                        addingDrink = false
                                    }
                                }
                            }
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(isEditing ? Theme.gold : Theme.surface))
                            .foregroundStyle(isEditing ? Theme.ink : Theme.goldBright)
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 26)

                    Text(outcome.title)
                        .font(.system(size: 34, weight: .light, design: .serif))
                        .foregroundStyle(Theme.cream)

                    Text(outcome.detail)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.mute)
                        .padding(.horizontal, 28)
                }

                // 事后修正面板（仅归档手帐开启编辑时展开）
                if isArchived && isEditing {
                    archivedEditSection(current: current, end: end)
                        .padding(.horizontal, 24)
                }

                // 本场节奏曲线：实际（含推测）对照方案节奏，横轴显示真实时刻
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
                    PaceCurveChart(session: current)
                        .frame(height: 155)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Theme.raised)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.subtleCardStroke, lineWidth: 1))
                )
                .padding(.horizontal, 24)

                // 核心统计卡片
                VStack(spacing: 14) {
                    HStack {
                        Text(isMixed ? "酒水构成" : "主要酒器")
                            .foregroundStyle(Theme.mute)
                        Spacer()
                        if isMixed {
                            Text(current.formattedMixSummary(at: end))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.goldBright)
                                .multilineTextAlignment(.trailing)
                        } else {
                            Text("\(cat.name)（\(current.planName)）")
                                .foregroundStyle(Theme.goldBright)
                        }
                    }
                    Divider().background(Theme.faint)
                    HStack {
                        Text("起止时间")
                            .foregroundStyle(Theme.mute)
                        Spacer()
                        Text(Format.sessionDayAndRange(start: current.startedAt, end: end))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Theme.cream)
                    }
                    Divider().background(Theme.faint)
                    HStack {
                        Text(estimated > 0.05 ? "本场累计（含推测）" : "实际摄入总量")
                            .foregroundStyle(Theme.mute)
                        Spacer()
                        if isMixed {
                            Text("\(Format.units(units)) 标准杯 · 约 \(Int(round(units * Pace.gramsPerStandard)))g 乙醇")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.cream)
                        } else {
                            Text("\(cat.formatPhysical(from: units)) · \(Format.units(units)) 标准杯")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.cream)
                        }
                    }
                    if estimated > 0.05 {
                        HStack {
                            Text("其中：确认 / 节奏推测")
                                .font(.caption)
                                .foregroundStyle(Theme.mute)
                            Spacer()
                            Text(isMixed
                                 ? "\(Format.units(confirmed)) / \(Format.units(estimated)) 标准杯"
                                 : "\(cat.formatPhysical(from: confirmed)) / \(cat.formatPhysical(from: estimated))")
                                .font(.caption)
                                .foregroundStyle(Theme.gold)
                        }
                    }
                    Divider().background(Theme.faint)
                    HStack {
                        Text("席间时长")
                            .foregroundStyle(Theme.mute)
                        Spacer()
                        Text(Format.minutes(Int(current.duration / 60)))
                            .foregroundStyle(Theme.cream)
                    }
                    Divider().background(Theme.faint)
                    HStack {
                        Text("代谢补水")
                            .foregroundStyle(Theme.mute)
                        Spacer()
                        Text("\(current.waters.count) 杯水")
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

                // 今朝体感与随笔（支持刚收杯和次日回看时补记）
                feelingAndNoteCard(current: current)
                    .padding(.horizontal, 24)

                // 本场饮水与记杯时刻明细（精确到 HH:mm）
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("本场饮水与记杯明细")
                            .font(.system(size: 15, weight: .medium, design: .serif))
                            .foregroundStyle(Theme.cream)
                        Spacer()
                        Text("共 \(current.drinks.count) 杯酒 · \(current.waters.count) 杯水")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            HStack(alignment: .center, spacing: 10) {
                                Text(clockLabel(for: event.at, start: current.startedAt))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(Theme.mute)
                                    .frame(minWidth: 44, alignment: .leading)

                                Circle()
                                    .fill(event.color)
                                    .frame(width: 6, height: 6)

                                Text(event.title)
                                    .font(.subheadline)
                                    .foregroundStyle(event.color)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)

                                Spacer(minLength: 8)

                                if let badge = event.badge {
                                    Text(badge)
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(Theme.mute)
                                }

                                if isArchived && isEditing {
                                    if let drinkID = event.drinkID {
                                        Button(role: .destructive) {
                                            var updated = current
                                            updated.drinks.removeAll { $0.id == drinkID }
                                            for i in 0..<updated.prompts.count where updated.prompts[i].drinkID == drinkID {
                                                updated.prompts[i].reply = nil
                                                updated.prompts[i].drinkID = nil
                                            }
                                            store.updateArchivedSession(updated)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundStyle(Theme.wine)
                                                .frame(minWidth: 32, minHeight: 32)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("删除这条饮酒记录")
                                    } else if let waterID = event.waterID {
                                        Button(role: .destructive) {
                                            var updated = current
                                            updated.waters.removeAll { $0.id == waterID }
                                            store.updateArchivedSession(updated)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundStyle(Theme.wine)
                                                .frame(minWidth: 32, minHeight: 32)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("删除这条喝水记录")
                                    }
                                }
                            }
                            .padding(.vertical, 9)

                            if index < events.count - 1 {
                                Divider().background(Theme.faint.opacity(0.6))
                            }
                        }
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Theme.raised)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.subtleCardStroke, lineWidth: 1))
                )
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 16)
        }
        .onAppear {
            guard !initializedReview else { return }
            initializedReview = true
            let current = liveSession
            feeling = current.feeling
            noteText = current.note ?? ""
            addItemTime = current.endedAt ?? current.startedAt
            selectedAddPresetID = store.settings.savedPresets.first?.id ?? Pace.presets[0].id
        }
        .onDisappear {
            let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
            let savedTrimmed = (liveSession.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != savedTrimmed || feeling != liveSession.feeling {
                store.updateSessionReview(sessionID: liveSession.id, feeling: feeling, note: noteText)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                FillButton(title: "收妥归档", color: Theme.gold) {
                    store.updateSessionReview(sessionID: liveSession.id, feeling: feeling, note: noteText)
                    dismiss()
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
            .background(
                LinearGradient(
                    colors: [Theme.bg.opacity(0), Theme.bg.opacity(0.95), Theme.bg],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private func feelingAndNoteCard(current: Session) -> some View {
        let savedTrimmed = (current.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let currentTrimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteDirty = savedTrimmed != currentTrimmed

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("喝后体感与随笔")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.cream)
                Spacer()
                Text("次日回看亦可补记")
                    .font(.caption2)
                    .foregroundStyle(Theme.mute)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FeelingTag.allCases) { tag in
                        let selected = feeling == tag
                        Button {
                            feeling = selected ? nil : tag
                            store.updateSessionReview(sessionID: current.id, feeling: feeling, note: noteText)
                            store.triggerHaptic(.soft)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tag.icon)
                                    .font(.system(size: 11))
                                Text(tag.title)
                                    .font(.caption.weight(selected ? .semibold : .regular))
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(selected ? Theme.gold : Theme.surface))
                            .foregroundStyle(selected ? Theme.ink : Theme.cream)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("记一句：配了什么菜、次日精神如何…", text: $noteText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Theme.surface))
                    .foregroundStyle(Theme.cream)
                    .onSubmit {
                        store.updateSessionReview(sessionID: current.id, feeling: feeling, note: noteText)
                    }

                if noteDirty {
                    Button("保存") {
                        store.updateSessionReview(sessionID: current.id, feeling: feeling, note: noteText)
                        store.triggerHaptic(.soft)
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.gold))
                    .foregroundStyle(Theme.ink)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.raised)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.subtleCardStroke, lineWidth: 1))
        )
    }

    private func archivedEditSection(current: Session, end: Date) -> some View {
        let cat = current.beverageCategory
        let softCount = min(cat.maxSoftPhysicalCount, max(1, Int(round(cat.physicalValue(from: current.softLimit)))))
        let hardCount = min(cat.maxHardPhysicalCount, max(softCount, Int(round(cat.physicalValue(from: current.hardLimit)))))
        let savedIDs = Set(store.settings.savedPresets.map(\.id))
        let allPresets = store.settings.savedPresets + Pace.presets.filter { !savedIDs.contains($0.id) }
        let pickedPreset = allPresets.first(where: { $0.id == selectedAddPresetID }) ?? Pace.presets[0]
        let now = Date()
        let safeEnd = max(current.startedAt, end)
        let maxEndBound = max(current.startedAt, now)
        let spansMidnight = !Calendar.current.isDate(current.startedAt, inSameDayAs: safeEnd)

        return VStack(alignment: .leading, spacing: 14) {
            Text("修正手帐与补记")
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundStyle(Theme.goldBright)

            VStack(spacing: 10) {
                DatePicker(
                    "开席时间",
                    selection: Binding(
                        get: { current.startedAt },
                        set: { nextStart in
                            var updated = current
                            updated.startedAt = min(nextStart, updated.endedAt ?? nextStart)
                            store.updateArchivedSession(updated)
                        }
                    ),
                    in: ...safeEnd,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .font(.caption)
                .foregroundStyle(Theme.cream)

                DatePicker(
                    "收杯时间",
                    selection: Binding(
                        get: { min(safeEnd, maxEndBound) },
                        set: { nextEnd in
                            var updated = current
                            updated.endedAt = max(updated.startedAt, min(nextEnd, maxEndBound))
                            store.updateArchivedSession(updated)
                        }
                    ),
                    in: current.startedAt...maxEndBound,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .font(.caption)
                .foregroundStyle(Theme.cream)

                Divider().background(Theme.faint)

                SettingStepper(
                    title: "建议停杯线",
                    value: "\(softCount) \(cat.unitName)",
                    range: 1...cat.maxSoftPhysicalCount,
                    step: 1,
                    valueBinding: Binding(
                        get: { softCount },
                        set: { nextSoft in
                            var updated = current
                            updated.softLimit = Double(nextSoft) * cat.standardUnitsPerUnit
                            if updated.hardLimit < updated.softLimit {
                                updated.hardLimit = updated.softLimit
                            }
                            store.updateArchivedSession(updated)
                        }
                    )
                )

                SettingStepper(
                    title: "严格警戒线",
                    value: "\(hardCount) \(cat.unitName)",
                    range: softCount...cat.maxHardPhysicalCount,
                    step: 1,
                    valueBinding: Binding(
                        get: { hardCount },
                        set: { nextHard in
                            var updated = current
                            updated.hardLimit = Double(nextHard) * cat.standardUnitsPerUnit
                            store.updateArchivedSession(updated)
                        }
                    )
                )
            }

            Divider().background(Theme.faint)

            HStack(spacing: 10) {
                Button {
                    withAnimation {
                        addingDrink.toggle()
                        addItemTime = min(max(addItemTime, current.startedAt), safeEnd)
                    }
                } label: {
                    Label(addingDrink ? "收起补酒" : "补记一杯酒", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.gold.opacity(0.16)))
                        .foregroundStyle(Theme.goldBright)
                }
                .buttonStyle(.plain)

                Button {
                    var updated = current
                    let clampedTime = min(max(addItemTime, current.startedAt), safeEnd)
                    updated.waters.append(WaterLog(id: UUID(), at: clampedTime, createdAt: .now))
                    store.updateArchivedSession(updated)
                } label: {
                    Label("补记一杯水", systemImage: "drop.fill")
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.water.opacity(0.16)))
                        .foregroundStyle(Theme.water)
                }
                .buttonStyle(.plain)
            }

            if addingDrink {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(allPresets) { preset in
                                let isChosen = preset.id == pickedPreset.id
                                Button {
                                    selectedAddPresetID = preset.id
                                } label: {
                                    Text("\(preset.name) · \(preset.detail)")
                                        .font(.caption2.weight(isChosen ? .semibold : .regular))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(isChosen ? Theme.gold : Theme.surface))
                                        .foregroundStyle(isChosen ? Theme.ink : Theme.cream)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    DatePicker(
                        "饮用时刻",
                        selection: $addItemTime,
                        in: current.startedAt...safeEnd,
                        displayedComponents: spansMidnight ? [.date, .hourAndMinute] : [.hourAndMinute]
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.cream)

                    Button("确认补入此杯（\(pickedPreset.name)）") {
                        var updated = current
                        let clampedTime = min(max(addItemTime, current.startedAt), safeEnd)
                        updated.drinks.append(
                            DrinkLog(
                                id: UUID(),
                                presetID: pickedPreset.id,
                                name: pickedPreset.name,
                                detail: pickedPreset.detail,
                                grams: pickedPreset.grams,
                                at: clampedTime,
                                createdAt: .now,
                                category: pickedPreset.resolvedCategory
                            )
                        )
                        store.updateArchivedSession(updated)
                        addingDrink = false
                    }
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Theme.gold))
                    .foregroundStyle(Theme.ink)
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.raised)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.gold.opacity(0.45), lineWidth: 1))
        )
    }

    private func clockLabel(for date: Date, start: Date) -> String {
        if Calendar.current.isDate(date, inSameDayAs: start) {
            return Format.shortTime(date)
        }
        return "次日 \(Format.shortTime(date))"
    }

    private func buildEvents(session: Session, end: Date, outcome: Outcome, category: BeverageCategory) -> [SummaryEvent] {
        var list: [SummaryEvent] = [
            SummaryEvent(
                id: "start",
                at: session.startedAt,
                order: 0,
                title: "开席 · \(session.planName)",
                badge: nil,
                color: Theme.gold
            )
        ]

        for drink in session.drinks {
            list.append(
                SummaryEvent(
                    id: "drink_\(drink.id.uuidString)",
                    at: drink.at,
                    order: 1,
                    title: "\(drink.name) · \(drink.detail)",
                    badge: "\(Format.units(drink.grams / Pace.gramsPerStandard)) 标准杯",
                    color: Theme.cream,
                    drinkID: drink.id
                )
            )
        }

        for water in session.waters {
            list.append(
                SummaryEvent(
                    id: "water_\(water.id.uuidString)",
                    at: water.at,
                    order: 1,
                    title: "💧 喝了一杯水",
                    badge: nil,
                    color: Theme.water,
                    waterID: water.id
                )
            )
        }

        if session.estimateWhenSilent {
            for prompt in session.prompts where prompt.reply == nil && prompt.at <= end {
                list.append(
                    SummaryEvent(
                        id: "prompt_\(prompt.id.uuidString)",
                        at: prompt.at,
                        order: 1,
                        title: "◌ 节奏推测（未回复）",
                        badge: "+\(category.formatPhysical(from: prompt.estimate))",
                        color: prompt.level == .over ? Theme.wine : Theme.gold.opacity(0.85)
                    )
                )
            }
        }

        if end.timeIntervalSince(session.startedAt) >= 5 {
            list.append(
                SummaryEvent(
                    id: "end",
                    at: end,
                    order: 2,
                    title: "收杯结席 · \(outcome.title)",
                    badge: nil,
                    color: outcome == .crossed ? Theme.wine : Theme.sage
                )
            )
        }

        return list.sorted { lhs, rhs in
            if lhs.at == rhs.at {
                return lhs.order < rhs.order
            }
            return lhs.at < rhs.at
        }
    }
}

// MARK: - 复盘节奏曲线

/// 以本场酒种的物理单位绘制累计杯量（确认 + 推测）随真实时刻的阶梯曲线，
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

            if abs(hard - soft) < 0.01 {
                RuleMark(y: .value("上限", hard))
                    .foregroundStyle(Theme.wine.opacity(0.75))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, alignment: .leading) {
                        Text("建议 / 上限 \(cat.formatPhysical(from: session.softLimit))")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.wine)
                    }
            } else {
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
                    .annotation(position: .top, alignment: .trailing) {
                        Text("上限 \(cat.formatPhysical(from: session.hardLimit))")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.wine)
                    }
            }
        }
        .chartYScale(domain: 0...max(yMax, 1))
        .chartXScale(domain: 0...max(total / 60, planMinutes))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Theme.faint)
                AxisValueLabel {
                    if let minute = value.as(Double.self) {
                        Text(Format.shortTime(session.startedAt.addingTimeInterval(minute * 60)))
                            .font(.system(size: 11).monospacedDigit())
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
struct TingBeiBackupDocument: FileDocument, Sendable {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct PreferencesSheet: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showingExporter = false
    @State private var exportDocument = TingBeiBackupDocument()
    @State private var showingImporter = false
    @State private var pendingImport: SavedState?
    @State private var showingImportModeDialog = false
    @State private var backupErrorMessage: String?

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        @Bindable var store = store
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("声律与偏好")
                            .font(.system(size: 24, weight: .light, design: .serif))
                            .foregroundStyle(Theme.cream)
                        Text("提醒音色 · 静默推测 · 备份恢复")
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

                // 2. 席间习惯与每周参考预算
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
                        Divider().background(Theme.faint).padding(.leading, 16)
                        SettingStepper(
                            title: "每周参考上限（手账统计对照）",
                            value: "\(Int(round(store.settings.weeklyBudgetUnits))) 标准杯",
                            range: 2...60,
                            step: 1,
                            valueBinding: Binding(
                                get: { Int(round(store.settings.weeklyBudgetUnits)) },
                                set: { next in
                                    store.settings.weeklyBudgetUnits = Double(next)
                                    store.normalizeAndSaveSettings()
                                }
                            )
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Theme.raised)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.subtleCardStroke, lineWidth: 1))
                    )
                }

                // 3. 手帐备份与恢复（通过系统文件选择器直存 iCloud Drive）
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("手帐备份与恢复", hint: "可存至 iCloud Drive")
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Button {
                                do {
                                    let data = try store.exportBackupData()
                                    exportDocument = TingBeiBackupDocument(data: data)
                                    showingExporter = true
                                } catch {
                                    backupErrorMessage = "生成备份失败：\(error.localizedDescription)"
                                }
                            } label: {
                                Label("导出备份", systemImage: "square.and.arrow.up")
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(RoundedRectangle(cornerRadius: 13).fill(Theme.gold.opacity(0.14)))
                                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.gold.opacity(0.4), lineWidth: 0.8))
                                    .foregroundStyle(Theme.goldBright)
                            }
                            .buttonStyle(.plain)

                            Button {
                                showingImporter = true
                            } label: {
                                Label("从备份恢复", systemImage: "square.and.arrow.down")
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(RoundedRectangle(cornerRadius: 13).fill(Theme.surface))
                                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.subtleCardStroke, lineWidth: 0.8))
                                    .foregroundStyle(Theme.cream)
                            }
                            .buttonStyle(.plain)
                        }

                        Text("当前已存 \(store.history.count) 场手帐与 \(store.settings.savedPresets.count) 款常喝。导出时在系统「文件」弹窗选择 iCloud Drive，重装或换机即可一键合并找回。")
                            .font(.caption2)
                            .foregroundStyle(Theme.mute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
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
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: defaultBackupFilename()
        ) { result in
            if case let .failure(error) = result {
                backupErrorMessage = "导出未完成：\(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                let didAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccess { url.stopAccessingSecurityScopedResource() }
                }
                do {
                    let data = try Data(contentsOf: url)
                    pendingImport = try store.decodeBackupData(data)
                    showingImportModeDialog = true
                } catch {
                    backupErrorMessage = "无法读取该备份文件，请确认它是停杯导出的 JSON 文件。"
                }
            case let .failure(error):
                backupErrorMessage = "选择文件失败：\(error.localizedDescription)"
            }
        }
        .confirmationDialog(
            importDialogTitle,
            isPresented: $showingImportModeDialog,
            titleVisibility: .visible
        ) {
            if let incoming = pendingImport {
                Button("智能合并（保留现有并去重补全）") {
                    store.importBackupState(incoming, mode: .merge)
                    pendingImport = nil
                }
                Button("覆盖恢复（替换现有设置与手帐）", role: .destructive) {
                    store.importBackupState(incoming, mode: .replace)
                    pendingImport = nil
                }
            }
            Button("取消", role: .cancel) {
                pendingImport = nil
            }
        } message: {
            Text("合并模式会按场次唯一标识去重，保留更完整的笔记与体感。")
        }
        .alert(
            "备份提示",
            isPresented: Binding(
                get: { backupErrorMessage != nil },
                set: { if !$0 { backupErrorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) { backupErrorMessage = nil }
        } message: {
            Text(backupErrorMessage ?? "")
        }
    }

    private var importDialogTitle: String {
        guard let incoming = pendingImport else { return "恢复手帐备份" }
        return "读取到 \(incoming.history.count) 场手帐记录，请选择恢复方式"
    }

    private func defaultBackupFilename() -> String {
        let dayText = Date.now.formatted(.iso8601.year().month().day())
        return "停杯手帐备份_\(dayText)"
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

// MARK: - 席间实时微调抽屉（档位、时长、推测、声律与常亮）

struct SessionSettingsSheet: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var softPhysical: Int = 3
    @State private var hardPhysical: Int = 4
    @State private var plannedMinutes: Int = 120
    @State private var estimateWhenSilent: Bool = true
    @State private var initialized = false

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        @Bindable var store = store
        ScrollView(showsIndicators: false) {
            if let session = store.active {
                let cat = session.beverageCategory
                let softStd = Double(softPhysical) * cat.standardUnitsPerUnit
                let hardStd = Double(hardPhysical) * cat.standardUnitsPerUnit

                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("席间实时微调")
                                .font(.system(size: 24, weight: .light, design: .serif))
                                .foregroundStyle(Theme.cream)
                            Text("按 \(cat.name)（\(cat.unitName)）即时重排提醒与表盘刻度")
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

                    // 1. 本场节拍线与静默推测
                    VStack(alignment: .leading, spacing: 12) {
                        Text("本场节拍线（\(session.planName)）")
                            .font(.system(size: 15, weight: .medium, design: .serif))
                            .foregroundStyle(Theme.cream)

                        VStack(spacing: 12) {
                            SettingStepper(
                                title: "建议停杯线",
                                value: "\(softPhysical) \(cat.unitName)（\(Format.units(softStd))杯）",
                                range: 1...cat.maxSoftPhysicalCount,
                                step: 1,
                                valueBinding: Binding(
                                    get: { softPhysical },
                                    set: { next in
                                        softPhysical = min(cat.maxSoftPhysicalCount, max(1, next))
                                        if hardPhysical < softPhysical {
                                            hardPhysical = softPhysical
                                        }
                                    }
                                )
                            )

                            Divider().background(Theme.faint)

                            SettingStepper(
                                title: "严格警戒线",
                                value: "\(hardPhysical) \(cat.unitName)（\(Format.units(hardStd))杯）",
                                range: softPhysical...cat.maxHardPhysicalCount,
                                step: 1,
                                valueBinding: Binding(
                                    get: { hardPhysical },
                                    set: { next in
                                        hardPhysical = min(cat.maxHardPhysicalCount, max(softPhysical, next))
                                    }
                                )
                            )

                            Divider().background(Theme.faint)

                            SettingStepper(
                                title: "预定时长",
                                value: Format.minutes(plannedMinutes),
                                range: 30...360,
                                step: 15,
                                valueBinding: $plannedMinutes
                            )

                            Divider().background(Theme.faint)

                            Toggle(isOn: $estimateWhenSilent) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("未回应时按节奏推测")
                                        .font(.system(size: 14, design: .serif))
                                        .foregroundStyle(Theme.cream)
                                    Text("关闭后只统计主动确认的杯数")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.mute)
                                }
                            }
                            .tint(Theme.gold)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Theme.raised)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.subtleCardStroke, lineWidth: 1))
                        )

                        FillButton(title: "应用本场调整", color: Theme.gold) {
                            store.updateActiveSession(
                                softLimit: softStd,
                                hardLimit: hardStd,
                                plannedMinutes: plannedMinutes,
                                estimateWhenSilent: estimateWhenSilent
                            )
                            dismiss()
                        }
                    }

                    // 2. 席间表盘常亮（即时生效）
                    VStack(alignment: .leading, spacing: 10) {
                        Text("座钟与屏幕")
                            .font(.system(size: 15, weight: .medium, design: .serif))
                            .foregroundStyle(Theme.cream)

                        Toggle(isOn: $store.settings.keepScreenOn) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("席间表盘常亮")
                                    .font(.system(size: 15, design: .serif))
                                    .foregroundStyle(Theme.cream)
                                Text("把手机立在桌上当座钟时开启")
                                    .font(.caption)
                                    .foregroundStyle(Theme.mute)
                            }
                        }
                        .tint(Theme.gold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Theme.raised)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.subtleCardStroke, lineWidth: 1))
                        )
                    }

                    // 3. 提醒音色（点按试听并即时保存）
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("提醒音色")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                                .foregroundStyle(Theme.cream)
                            Spacer()
                            Text("点按即试听并生效")
                                .font(.caption)
                                .foregroundStyle(Theme.mute)
                        }

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(NotificationSoundOption.allCases) { opt in
                                let isSelected = store.settings.notificationSound == opt
                                Button {
                                    store.settings.notificationSound = opt
                                    store.previewSound(opt)
                                    store.normalizeAndSaveSettings()
                                    store.reschedule()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: isSelected ? "speaker.wave.2.fill" : "play.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(isSelected ? Theme.goldBright : Theme.mute)
                                        Text(opt.displayName)
                                            .font(.system(size: 14, weight: isSelected ? .semibold : .regular, design: .serif))
                                            .foregroundStyle(Theme.cream)
                                        Spacer(minLength: 0)
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(Theme.goldBright)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .frame(height: 48)
                                    .background(
                                        RoundedRectangle(cornerRadius: 13)
                                            .fill(Theme.raised)
                                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(isSelected ? Theme.gold : Theme.faint, lineWidth: isSelected ? 1.2 : 0.9))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            guard !initialized, let session = store.active else { return }
            initialized = true
            let cat = session.beverageCategory
            let softCount = min(cat.maxSoftPhysicalCount, max(1, Int(round(cat.physicalValue(from: session.softLimit)))))
            let hardCount = min(cat.maxHardPhysicalCount, max(softCount, Int(round(cat.physicalValue(from: session.hardLimit)))))
            softPhysical = softCount
            hardPhysical = hardCount
            plannedMinutes = min(360, max(30, session.plannedMinutes))
            estimateWhenSilent = session.estimateWhenSilent
        }
        .onChange(of: store.settings.keepScreenOn) { _, _ in
            store.normalizeAndSaveSettings()
        }
    }
}

// MARK: - 席间手账统计概览抽屉

struct JournalStatsSheet: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var scope = 0
    @State private var monthOffset = 0
    @State private var selectedDay: Date?

    private enum DayStatus {
        case future
        case dry
        case within
        case crossed
    }

    var body: some View {
        let now = Date()
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let sessions = store.history.filter { session in
            let end = session.endedAt ?? now
            guard session.outcome(at: end) != .empty else { return false }
            return scope == 0 ? session.startedAt >= cutoff : true
        }

        let count = sessions.count
        let withinCount = sessions.filter { $0.outcome(at: $0.endedAt ?? now) == .within }.count
        let touchedCount = sessions.filter { $0.outcome(at: $0.endedAt ?? now) == .touched }.count
        let crossedCount = sessions.filter { $0.outcome(at: $0.endedAt ?? now) == .crossed }.count
        let keepRate = count > 0 ? Int((Double(withinCount + touchedCount) / Double(count) * 100).rounded()) : 0

        let totalUnits = sessions.reduce(0.0) { $0 + $1.units(at: $1.endedAt ?? now) }
        let avgUnits = count > 0 ? totalUnits / Double(count) : 0
        let avgMinutes = count > 0 ? Int((sessions.reduce(0.0) { $0 + $1.duration } / Double(count) / 60).rounded()) : 0
        let totalDrinks = sessions.reduce(0) { $0 + $1.drinks.count }
        let totalWaters = sessions.reduce(0) { $0 + $1.waters.count }

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("手账统计概览")
                            .font(.system(size: 24, weight: .light, design: .serif))
                            .foregroundStyle(Theme.cream)
                        Text("清醒日历 · 周度参考 · 混合酒水实算")
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

                // 本周参考对照卡
                weeklyBudgetCard(now: now)

                // 本月清醒日历（Dry Days）
                dryCalendarCard(now: now)

                Picker("统计区间", selection: $scope) {
                    Text("近 30 天").tag(0)
                    Text("全部手账").tag(1)
                }
                .pickerStyle(.segmented)

                if sessions.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "wineglass")
                            .font(.title2)
                            .foregroundStyle(Theme.mute)
                        Text(scope == 0 ? "近 30 天暂无饮酒记录" : "手账里暂无饮酒记录")
                            .font(.subheadline)
                            .foregroundStyle(Theme.cream)
                        if scope == 0 && !store.history.isEmpty {
                            Text("可切换至「全部手账」查看更早的场次。")
                                .font(.caption)
                                .foregroundStyle(Theme.mute)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.raised)
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.subtleCardStroke, lineWidth: 1))
                    )
                } else {
                    // 1. 守线收杯率与结果分布条
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("守线收杯率")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                                .foregroundStyle(Theme.cream)
                            Spacer()
                            Text("\(keepRate)%")
                                .font(.system(size: 26, weight: .light, design: .serif).monospacedDigit())
                                .foregroundStyle(Theme.goldBright)
                        }

                        GeometryReader { geo in
                            let w = max(geo.size.width, 1)
                            HStack(spacing: 2) {
                                if withinCount > 0 {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Theme.sage)
                                        .frame(width: w * CGFloat(withinCount) / CGFloat(count))
                                }
                                if touchedCount > 0 {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Theme.gold)
                                        .frame(width: w * CGFloat(touchedCount) / CGFloat(count))
                                }
                                if crossedCount > 0 {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Theme.wine)
                                        .frame(width: w * CGFloat(crossedCount) / CGFloat(count))
                                }
                            }
                        }
                        .frame(height: 10)

                        HStack(spacing: 14) {
                            outcomeLegend(color: Theme.sage, label: "收在线内", count: withinCount)
                            outcomeLegend(color: Theme.gold, label: "到线就收", count: touchedCount)
                            outcomeLegend(color: Theme.wine, label: "越过线了", count: crossedCount)
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.raised)
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.bezelGradient, lineWidth: 1))
                    )

                    // 2. 四宫格核心指标
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        statCard(title: "开席场次", value: "\(count) 场", subtitle: "累计 \(Format.units(totalUnits)) 标准杯")
                        statCard(title: "场均酒量", value: "\(Format.units(avgUnits)) 杯", subtitle: "WHO 14g 标准杯")
                        statCard(title: "场均时长", value: Format.minutes(avgMinutes), subtitle: "从开席至收杯")
                        statCard(title: "代谢补水", value: "\(totalWaters) 杯", subtitle: totalDrinks > 0 ? "水酒比 \(totalWaters):\(totalDrinks)" : "席间主动补水")
                    }

                    // 3. 酒种真实摄入分布（按每场内实际每杯酒归类拆分）
                    categoryBreakdownCard(sessions: sessions, now: now)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
    }

    private func weeklyBudgetCard(now: Date) -> some View {
        var mondayCalendar = Calendar.current
        mondayCalendar.firstWeekday = 2
        let weekInterval = mondayCalendar.dateInterval(of: .weekOfYear, for: now)
        let weekStart = weekInterval?.start ?? now
        let weekEnd = weekInterval?.end ?? now

        let weekSessions = store.history.filter { session in
            let end = session.endedAt ?? now
            guard session.outcome(at: end) != .empty else { return false }
            return session.startedAt >= weekStart && session.startedAt < weekEnd
        }
        let weekUnits = weekSessions.reduce(0.0) { $0 + $1.units(at: $1.endedAt ?? now) }
        let budget = max(1.0, store.settings.weeklyBudgetUnits)
        let ratio = min(1.0, weekUnits / budget)
        let isOver = weekUnits > budget + 0.001
        let isNear = !isOver && ratio >= 0.8

        let barColor: Color = isOver ? Theme.wine : (isNear ? Theme.caution : Theme.sage)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("本周摄入对照")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.cream)
                Spacer()
                Text("\(Format.units(weekUnits)) / \(Format.units(budget)) 标准杯")
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundStyle(isOver ? Theme.wine : Theme.goldBright)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.faint)
                    Capsule()
                        .fill(barColor)
                        .frame(width: weekUnits > 0.01 ? max(8, geo.size.width * ratio) : 0)
                }
            }
            .frame(height: 8)

            HStack {
                Text("本周共 \(weekSessions.count) 场 · 约 \(Int(round(weekUnits * Pace.gramsPerStandard)))g 纯乙醇")
                    .font(.caption2)
                    .foregroundStyle(Theme.mute)
                Spacer()
                Text(isOver ? "已高于每周参考线" : "可在「偏好设置」调节参考线")
                    .font(.caption2)
                    .foregroundStyle(isOver ? Theme.wine : Theme.mute)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.raised)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.subtleCardStroke, lineWidth: 1))
        )
    }

    private func dryCalendarCard(now: Date) -> some View {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)
        let targetMonth = cal.date(byAdding: .month, value: monthOffset, to: now) ?? now
        let monthComponents = cal.dateComponents([.year, .month], from: targetMonth)
        let firstOfMonth = cal.date(from: monthComponents) ?? now
        let dayCount = cal.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let weekdayOfFirst = cal.component(.weekday, from: firstOfMonth)
        let leadingBlank = (weekdayOfFirst + 5) % 7 // 周一为首列

        let dates: [Date] = (0..<dayCount).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: firstOfMonth)
        }

        let monthEnd = cal.date(byAdding: .day, value: dayCount, to: firstOfMonth) ?? now
        let monthSessions = store.history.filter { session in
            let end = session.endedAt ?? now
            guard session.outcome(at: end) != .empty else { return false }
            return session.startedAt >= firstOfMonth && session.startedAt < monthEnd
        }

        let sessionsByDay = Dictionary(grouping: monthSessions) { cal.startOfDay(for: $0.startedAt) }

        var dryDays = 0
        var drinkDays = 0
        for d in dates {
            let dayStart = cal.startOfDay(for: d)
            guard dayStart <= todayStart else { continue }
            if (sessionsByDay[dayStart]?.isEmpty ?? true) {
                dryDays += 1
            } else {
                drinkDays += 1
            }
        }

        let weekdayHeaders = ["一", "二", "三", "四", "五", "六", "日"]

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Format.monthTitle(firstOfMonth))
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.cream)
                    Text("清醒无酒 \(dryDays) 天 · 饮酒 \(drinkDays) 天")
                        .font(.caption)
                        .foregroundStyle(Theme.gold)
                }
                Spacer()
                HStack(spacing: 6) {
                    Button {
                        withAnimation(.smooth(duration: 0.2)) {
                            monthOffset -= 1
                            selectedDay = nil
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.cream)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Theme.surface))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("上一月")

                    Button {
                        withAnimation(.smooth(duration: 0.2)) {
                            monthOffset = min(0, monthOffset + 1)
                            selectedDay = nil
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(monthOffset < 0 ? Theme.cream : Theme.mute.opacity(0.35))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Theme.surface))
                    }
                    .buttonStyle(.plain)
                    .disabled(monthOffset >= 0)
                    .accessibilityLabel("下一月")
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(weekdayHeaders, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.mute)
                        .frame(maxWidth: .infinity)
                }

                ForEach(0..<leadingBlank, id: \.self) { idx in
                    Color.clear
                        .frame(height: 30)
                        .id("blank_\(idx)")
                }

                ForEach(dates, id: \.self) { date in
                    let dayStart = cal.startOfDay(for: date)
                    let daySessions = sessionsByDay[dayStart] ?? []
                    let status: DayStatus = {
                        if dayStart > todayStart { return .future }
                        if daySessions.isEmpty { return .dry }
                        if daySessions.contains(where: { $0.outcome(at: $0.endedAt ?? now) == .crossed }) {
                            return .crossed
                        }
                        return .within
                    }()
                    let isToday = cal.isDate(dayStart, inSameDayAs: todayStart)
                    let isSelected = selectedDay.map { cal.isDate($0, inSameDayAs: dayStart) } ?? false
                    let dayNum = cal.component(.day, from: date)

                    Button {
                        if status != .future {
                            selectedDay = isSelected ? nil : dayStart
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(dayFillColor(for: status))
                                .frame(width: 28, height: 28)
                            if isSelected || isToday {
                                Circle()
                                    .stroke(isSelected ? Theme.goldBright : Theme.gold.opacity(0.6), lineWidth: isSelected ? 1.6 : 1.0)
                                    .frame(width: 28, height: 28)
                            }
                            Text("\(dayNum)")
                                .font(.system(size: 11, weight: isToday ? .semibold : .regular).monospacedDigit())
                                .foregroundStyle(dayTextColor(for: status))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(status == .future)
                }
            }

            HStack(spacing: 14) {
                calendarLegend(color: Theme.surface, label: "清醒无酒")
                calendarLegend(color: Theme.sage.opacity(0.45), label: "守线收杯")
                calendarLegend(color: Theme.wine.opacity(0.55), label: "越过上限")
            }
            .padding(.top, 2)

            if let selected = selectedDay, let daySessions = sessionsByDay[selected] {
                let dayUnits = daySessions.reduce(0.0) { $0 + $1.units(at: $1.endedAt ?? now) }
                let hasCrossed = daySessions.contains { $0.outcome(at: $0.endedAt ?? now) == .crossed }
                HStack {
                    Text("\(Format.monthDay(selected)) · \(daySessions.count) 场 · 约 \(Format.units(dayUnits)) 标准杯")
                        .font(.caption)
                        .foregroundStyle(Theme.cream)
                    Spacer()
                    Text(hasCrossed ? "有越线场次" : "均守在线内")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(hasCrossed ? Theme.wine : Theme.sage)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
            } else if let selected = selectedDay {
                HStack {
                    Text("\(Format.monthDay(selected)) · 清醒无酒")
                        .font(.caption)
                        .foregroundStyle(Theme.sage)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.raised)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.subtleCardStroke, lineWidth: 1))
        )
    }

    private func dayFillColor(for status: DayStatus) -> Color {
        switch status {
        case .future: return .clear
        case .dry: return Theme.surface
        case .within: return Theme.sage.opacity(0.32)
        case .crossed: return Theme.wine.opacity(0.38)
        }
    }

    private func dayTextColor(for status: DayStatus) -> Color {
        switch status {
        case .future: return Theme.mute.opacity(0.35)
        case .dry: return Theme.mute
        case .within: return Theme.cream
        case .crossed: return Theme.cream
        }
    }

    private func calendarLegend(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Theme.subtleCardStroke, lineWidth: 0.6))
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.mute)
        }
    }

    private func categoryBreakdownCard(sessions: [Session], now: Date) -> some View {
        var unitBuckets: [BeverageCategory: Double] = [:]
        var drinkCountBuckets: [BeverageCategory: Int] = [:]

        for session in sessions {
            let end = session.endedAt ?? now
            for item in session.beverageBreakdown(at: end, includeEstimated: true) {
                unitBuckets[item.category, default: 0] += item.totalUnits
                drinkCountBuckets[item.category, default: 0] += item.drinkCount
            }
        }

        let grandTotalUnits = max(0.001, unitBuckets.values.reduce(0, +))
        let breakdown = unitBuckets.compactMap { cat, units -> CategoryStat? in
            guard units > 0.01 else { return nil }
            return CategoryStat(
                category: cat,
                units: units,
                drinkCount: drinkCountBuckets[cat] ?? 0
            )
        }.sorted { $0.units > $1.units }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("酒种摄入构成")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.cream)
                Spacer()
                Text("按每杯实际酒种拆分")
                    .font(.caption2)
                    .foregroundStyle(Theme.mute)
            }

            ForEach(breakdown) { item in
                let cat = item.category
                let ratio = item.units / grandTotalUnits
                let physicalDesc = cat.formatPhysical(from: item.units)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: cat.icon)
                                .font(.caption)
                                .foregroundStyle(Theme.gold)
                            Text(cat.name)
                                .font(.subheadline)
                                .foregroundStyle(Theme.cream)
                        }
                        Spacer()
                        Text("\(Format.units(item.units)) 标准杯 (\(physicalDesc)) · \(Int((ratio * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.mute)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.faint)
                            Capsule()
                                .fill(Theme.gold.opacity(0.85))
                                .frame(width: max(6, geo.size.width * ratio))
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.raised)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.subtleCardStroke, lineWidth: 1))
        )
    }

    private struct CategoryStat: Identifiable {
        var id: String { category.id }
        let category: BeverageCategory
        let units: Double
        let drinkCount: Int
    }

    private func outcomeLegend(color: Color, label: String, count: Int) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text("\(label) \(count)")
                .font(.caption)
                .foregroundStyle(Theme.mute)
        }
    }

    private func statCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.mute)
            Text(value)
                .font(.system(size: 20, weight: .light, design: .serif).monospacedDigit())
                .foregroundStyle(Theme.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(Theme.gold)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.raised)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.subtleCardStroke, lineWidth: 1))
        )
    }
}

