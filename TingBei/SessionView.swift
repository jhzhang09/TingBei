import SwiftUI

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
                    // 自绘表盘对 VoiceOver 合并为一个元素，直接读出当前量、建议线与状态
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("本场饮酒量")
                    .accessibilityValue("约 \(snap.physicalText)，建议线 \(session.beverageCategory.formatPhysical(from: session.softLimit))，\(snap.title)")

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
                            .font(.system(size: 11))
                        Text(session.beverageCategory.name)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
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
                            .font(.system(size: 11))
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
                        .font(.system(size: 11))
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
                        .font(.system(size: 11, weight: .semibold))
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
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.gold)
                } else {
                    let softPhysical = cat.formatPhysical(from: session.softLimit)
                    Text("建议线 \(softPhysical)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.mute)
                }

                // 底部微型副表盘（Sub-dial）：距上一杯间隔 & 水酒代谢比
                HStack(spacing: 10) {
                    if let since = snap.sinceLastDrink {
                        HStack(spacing: 3) {
                            Image(systemName: "hourglass")
                                .font(.system(size: 11))
                            Text("距上杯 \(max(1, Int(since / 60)))m")
                                .font(.system(size: 11, design: .monospaced))
                        }
                        .foregroundStyle(snap.isTooFast ? Theme.goldBright : Theme.mute)
                    } else {
                        Text("尚未记杯")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.mute.opacity(0.7))
                    }

                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(Theme.faint)

                    HStack(spacing: 2) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 11))
                        Text("\(snap.waterCount) 水")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .foregroundStyle(Theme.water)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.surface.opacity(0.7)))
                .padding(.top, 4)
            }

            // H. 该停档：朱砂印章盖在表盘右上——到线「当止」，越线「停杯」
            if snap.intensity >= .due {
                CinnabarSeal(text: snap.intensity == .over ? "停杯" : "当止")
                    .offset(x: 100, y: -104)
                    .transition(.scale(scale: 1.8).combined(with: .opacity))
            }
        }
        .frame(width: 286, height: 286)
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: snap.intensity)
    }

    // 3. 动态节律导引与待校准一体式仪器卡
    private func rhythmTelemetryCard(_ snap: PaceSnapshot, session: Session) -> some View {
        let stopMode = snap.intensity >= .due
        // 标题随状态分三级着色：从容用正文色，宜缓用警示色，当止用朱砂
        let titleColor = stopMode ? Theme.wine : ((snap.cue == .hurried || snap.cue == .near) ? Theme.caution : Theme.cream)
        return VStack(spacing: 10) {
            // 主状态与下次提醒倒计时
            VStack(spacing: 6) {
                HStack(alignment: .center) {
                    Text(snap.title)
                        .font(.system(size: stopMode ? 24 : 19, weight: stopMode ? .semibold : .medium, design: .serif))
                        .foregroundStyle(titleColor)

                    Spacer()

                    // 右侧：下次提醒倒计时胶囊
                    if snap.intensity == .over {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                            Text("每 10 分钟强提醒")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(Theme.wine)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.wine.opacity(0.16)))
                    } else if let next = snap.nextPrompt {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 11))
                            Text("\(Format.shortTime(next.at)) · \(Format.until(next.at, now: store.now))")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                        .foregroundStyle(Theme.goldBright)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.gold.opacity(0.14)))
                    }
                }

                if stopMode {
                    Text(snap.intensity == .over ? "杯深夜长，知止为上。" : "花看半开，酒饮微醉。")
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .tracking(1)
                        .foregroundStyle(Theme.cream)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(snap.message)
                    .font(.system(size: 13))
                    .foregroundStyle(stopMode ? Theme.cream.opacity(0.8) : Theme.mute)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(stopMode ? Theme.wine.opacity(Theme.isLight ? 0.10 : 0.16) : Theme.raised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(stopMode ? AnyShapeStyle(Theme.wine.opacity(0.75)) : AnyShapeStyle(Theme.subtleCardStroke), lineWidth: stopMode ? 1.2 : 1)
                    )
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
                        Text(snap.pendingCount > 1 ? "已暂按节奏计入 · 还有 \(snap.pendingCount - 1) 条" : "已暂按节奏计入虚线刻度")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.mute)
                    }
                    Spacer()
                    Button {
                        withAnimation {
                            store.handlePromptReply(promptID: pending.id, reply: .skipped)
                        }
                    } label: {
                        Text("还没喝")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Theme.surface))
                            .foregroundStyle(Theme.cream)
                            // 胶囊保持紧凑，点击热区补足到 44pt
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation {
                            store.handlePromptReply(promptID: pending.id, reply: .drank)
                        }
                    } label: {
                        Text("喝了\(defaultPreset.name)")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Theme.gold))
                            .foregroundStyle(Theme.ink)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
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
                            .font(.system(size: 11, weight: .bold))
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
                                .font(.system(size: 11))
                            Text("撤销")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(Theme.gold)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
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
        // 该停档主次互换：收杯升为中央主按钮，记一杯退为右侧小钮，不再让「再来一杯」是屏幕上最亮的东西
        let stopMode = snap.intensity >= .due

        return HStack(alignment: .center, spacing: 14) {
            // 左侧：喝水缓冲（急饮时高亮提示可折抵冷却）
            Button {
                store.logWater()
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(snap.isTooFast ? Theme.water.opacity(0.12) : Color.clear)
                            .frame(width: 54, height: 54)
                            .overlay(
                                Circle()
                                    .stroke(snap.isTooFast ? Theme.water : Theme.water.opacity(0.45), lineWidth: snap.isTooFast ? 1.5 : 0.8)
                            )
                        Image(systemName: "drop.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.water)
                    }
                    Text(snap.isTooFast ? "喝水缓5m" : "喝了水")
                        .font(.system(size: 11, weight: snap.isTooFast ? .semibold : .regular))
                        .foregroundStyle(snap.isTooFast ? Theme.water : Theme.mute)
                }
            }
            .buttonStyle(.plain)

            // 中央主表冠按钮：轻点直接记 1 份当前默认酒饮（零弹窗阻断），下方附带「换酒 / 补记时间」副键
            VStack(spacing: 6) {
                if stopMode {
                    Button {
                        confirmingEnd = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("收杯 · 结席")
                                .font(.system(size: 18, weight: .semibold, design: .serif))
                                .tracking(2)
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            Capsule()
                                .fill(Theme.wine)
                                .shadow(color: Theme.wine.opacity(0.35), radius: 10, y: 4)
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            store.logDrink()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                            VStack(alignment: .leading, spacing: 1) {
                                // 混饮/通用的单位本身就是「标准杯」，不再拼接酒种名，避免出现「记 1 标准杯混饮/通用」
                                Text(cat == .custom ? "记 1 标准杯" : "记 1 \(cat.unitName)\(cat.name)")
                                    .font(.system(size: 16, weight: .semibold, design: .serif))
                                Text(defaultDrink.detail)
                                    .font(.system(size: 11))
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
                }

                Button {
                    showingDrinks = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11))
                        Text("选其它酒 / 回溯补记时间")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Theme.gold)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)

            // 右侧：常态为收杯；该停档换成「再记一杯」小钮（主按钮已让位给收杯）
            if stopMode {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        store.logDrink()
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 54, height: 54)
                                .overlay(Circle().stroke(Theme.mute.opacity(0.5), lineWidth: 0.8))
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Theme.mute)
                        }
                        Text("再记一杯")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.mute)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(cat == .custom ? "再记 1 标准杯" : "再记 1 \(cat.unitName)\(cat.name)")
            } else {
                Button {
                    confirmingEnd = true
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 54, height: 54)
                                .overlay(
                                    Circle()
                                        .stroke(Theme.gold.opacity(0.55), lineWidth: 0.8)
                                )
                            Text("收")
                                .font(.system(size: 18, weight: .semibold, design: .serif))
                                .foregroundStyle(Theme.goldBright)
                        }
                        Text("我收杯了")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.mute)
                    }
            }
            .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 16)
        // 不再用整块背景框围住三枚按钮；只以一道两端渐隐的细金线托底，取界画「以尺引线」之意
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [.clear, Theme.gold.opacity(0.4), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.8)
        }
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

// MARK: - 表盘绘图组件：分段刻度环与六种主题时标

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
                    // 1. 玄漆描金 · 描金双线：48 枚次刻度 + 11 道泥金时标 + 子位双金线
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
                        // 子位双金线
                        let offset = max(1.6, radius * 0.022)
                        let rTop = radius
                        let rBottom = radius - 9.5
                        path.move(to: CGPoint(x: center.x - offset, y: center.y - rTop))
                        path.addLine(to: CGPoint(x: center.x - offset, y: center.y - rBottom))
                        path.move(to: CGPoint(x: center.x + offset, y: center.y - rTop))
                        path.addLine(to: CGPoint(x: center.x + offset, y: center.y - rBottom))

                        // 其余 11 道泥金时标
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
                    // 2. 汝窑天青 · 弦纹开片：外内双道器物弦纹 + 隐约蝉翼冰裂开片纹 + 十二辰芝麻支钉玉珠
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
                    // 3. 琥珀光 · 宝相星芒：内外花边双轨 + 48 枚琥珀微珠 + 12 枚四芒宝相星
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
                            // 沿半径方向的四芒宝相星四顶点
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
                    // 4. 霁蓝映月 · 北辰夜光：60 格细刻度 + 子位倒三角北辰 + 卯午酉三道夜光柱
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

                    // 卯 / 午 / 酉位加粗夜光柱
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

                    // 子位倒三角北辰
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
                    // 5. 牙白界画 · 界尺双轨：界画式双环分刻（每 5 格加粗）+ 四正细界线
                    Circle()
                        .stroke(tickColor.opacity(0.32), lineWidth: 0.75)
                    Circle()
                        .stroke(tickColor.opacity(0.24), lineWidth: 0.65)
                        .padding(5.5)

                    // 四正细界线（仅在盘缘轻触）
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
                    // 6. 宣纸水墨 · 乌丝十二辰：宋刻本乌丝外粗内细双边栏 + 十二辰竖向乌丝界格 + 12 点位微型朱砂方印
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
