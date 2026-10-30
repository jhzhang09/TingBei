import SwiftUI

// MARK: - Home View (私人酒廊与机械拨盘台签)

struct HomeView: View {
    @Environment(SessionStore.self) private var store
    @State private var showSecretSignature = false
    @State private var showingPreferences = false
    @State private var showAllHistory = false
    @State private var showingThemeGallery = false
    @State private var confirmingClearEmpty = false

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
        .sheet(isPresented: $showingPreferences) {
            PreferencesSheet()
                // 内容约占大屏三分之二，默认 70% 高度贴合内容；小屏可上拉至全屏滚动
                .presentationDetents([.fraction(0.7), .large])
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
                        // 取《大学》「知止而后有定」，呼应「停杯」之名
                        Text("知止而后有定 · 席间节律")
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .tracking(2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(Theme.gold)
                    }
                }
                Spacer()

                // 主题入口统一放在下方「表盘与席间主题」区，刊头不再重复，避免挤压标题
                HStack(spacing: 8) {
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
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.mute)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.raised)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.subtleCardStroke, lineWidth: 1))
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("收杯率 \(rate)%")
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
                    .font(.system(size: 11, design: .monospaced))
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
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.mute)
                                    .lineLimit(1)
                                    // 窄屏两列卡片放不下完整规格时轻微缩字，避免把「标准杯」截成省略号
                                    .minimumScaleFactor(0.75)
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
                    .font(.system(size: 11))
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
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.mute)
                        Text(softPhysical)
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(Theme.goldBright)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider().frame(height: 24).background(Theme.faint)

                    VStack(alignment: .center, spacing: 2) {
                        Text("严格警戒线")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.mute)
                        Text(hardPhysical)
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(Theme.wine)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    Divider().frame(height: 24).background(Theme.faint)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("预定席间时长")
                            .font(.system(size: 11))
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
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.gold)
                    Text("节拍递进：首询 30m ➔ 巡航 25m ➔ 临线 20m ➔ 到线 15m ➔ 越界 10m 强催")
                        .font(.system(size: 11, design: .monospaced))
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
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.gold)
                }
                Spacer()
                Button {
                    showingThemeGallery = true
                } label: {
                    HStack(spacing: 3) {
                        Text("品鉴全部 6 款")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
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
                                                .font(.system(size: 11, weight: .bold))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Capsule().fill(pal.gold.opacity(0.16)))
                                                .foregroundStyle(pal.gold)
                                        }
                                    }
                                    Text(theme.dialStyle.displayName)
                                        .font(.system(size: 11))
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

    // 5. 声律与推测入口：与主题雅集一致，点按向上弹出抽屉
    private var preferencesConsoleSection: some View {
        Button {
            showingPreferences = true
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
                    Text("声律与推测")
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.cream)
                    Text("铃声：\(store.settings.notificationSound.displayName) · \(store.settings.estimateWhenSilent ? "未回应自动推测" : "仅手动记杯")\(store.settings.keepScreenOn ? " · 屏幕常亮" : "")")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.mute)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.gold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.raised)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.subtleCardStroke, lineWidth: 1))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                let emptyCount = store.history.filter(\.isEmptyRecord).count
                if emptyCount > 0 {
                    Button {
                        confirmingClearEmpty = true
                    } label: {
                        Text("清理空场")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog(
                        "清理 \(emptyCount) 场空场记录？",
                        isPresented: $confirmingClearEmpty,
                        titleVisibility: .visible
                    ) {
                        Button("清理", role: .destructive) {
                            withAnimation {
                                store.clearEmptyHistory()
                            }
                        }
                        Button("取消", role: .cancel) {}
                    } message: {
                        Text("仅删除未饮酒、也无推测杯数的场次，删除后无法恢复。")
                    }
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
