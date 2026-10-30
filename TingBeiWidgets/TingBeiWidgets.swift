import WidgetKit
import SwiftUI
import ActivityKit

@main
struct TingBeiWidgetBundle: WidgetBundle {
    var body: some Widget {
        TingBeiLiveActivityWidget()
    }
}

struct WidgetThemeColors {
    let bg: Color
    let accent: Color
    let danger: Color
    let textPrimary: Color
    let textMuted: Color
    /// 偏快 / 临线的警示色，与主题主色 accent 区分
    let caution: Color

    /// 取自共享配色表 ThemePalette，保证锁屏卡片 / 灵动岛与 App 内主题色一致。
    static func resolve(for themeID: String?) -> WidgetThemeColors {
        let palette = ThemePalette.forThemeID(themeID)
        return WidgetThemeColors(
            bg: palette.bg,
            accent: palette.gold,
            danger: palette.wine,
            textPrimary: palette.cream,
            textMuted: palette.cream.opacity(0.6),
            caution: palette.caution
        )
    }

    /// 状态色：到线 / 越线用朱砂，偏快 / 临线用警示色，其余用主题主色
    func status(for state: TingBeiAttributes.ContentState) -> Color {
        if state.isOver { return danger }
        return (state.cue == "near" || state.cue == "hurried") ? caution : accent
    }
}

struct TingBeiLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TingBeiAttributes.self) { context in
            let wt = WidgetThemeColors.resolve(for: context.state.themeID)
            // 锁屏实时卡片 (Lock Screen Banner)
            LockScreenLiveActivityView(state: context.state, attributes: context.attributes, isStale: context.isStale, wt: wt)
                .activityBackgroundTint(wt.bg)
                .activitySystemActionForegroundColor(wt.accent)
        } dynamicIsland: { context in
            let wt = WidgetThemeColors.resolve(for: context.state.themeID)
            return DynamicIsland {
                // 长按展开态 (Expanded View)
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("停杯")
                                .font(.system(size: 11, weight: .semibold, design: .serif))
                                .foregroundStyle(wt.accent)
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(context.attributes.planName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(context.state.physicalText ?? "\(FormatWidget.units(context.state.units))杯")
                                .font(.system(size: 20, weight: .bold, design: .serif))
                                .foregroundStyle(context.state.isOver ? wt.danger : .white)
                            Text(context.state.physicalSoftLimitText != nil ? "/ \(context.state.physicalSoftLimitText!)" : "/ \(FormatWidget.units(context.state.softLimit))杯")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(wt.status(for: context.state))

                        if context.state.isOver {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.octagon.fill")
                                    .font(.system(size: 11))
                                Text("每10分钟提醒")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(wt.danger)
                        } else if let next = context.state.nextPromptAt {
                            HStack(spacing: 3) {
                                Image(systemName: "bell.badge")
                                    .font(.system(size: 11))
                                PromptCountdown(target: next, isStale: context.isStale)
                                    .font(.system(size: 11, design: .monospaced))
                            }
                            .foregroundStyle(.secondary)
                        } else {
                            Text("节拍守护中")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        Text(context.state.message)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // 快速深链跳转控制按钮
                        HStack(spacing: 12) {
                            Link(destination: URL(string: "tingbei://logWater")!) {
                                Label("喝了水", systemImage: "drop.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.blue.opacity(0.2)))
                                    .foregroundStyle(Color(red: 0.42, green: 0.68, blue: 0.86))
                            }

                            Link(destination: URL(string: "tingbei://logDrink")!) {
                                Label("+1份", systemImage: "plus")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(wt.accent.opacity(0.25)))
                                    .foregroundStyle(wt.accent)
                            }

                            Spacer()

                            Link(destination: URL(string: "tingbei://end")!) {
                                Text("我收杯了")
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(context.state.isOver ? wt.danger : Color.white.opacity(0.15)))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "wineglass.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(wt.status(for: context.state))
                    Text(context.state.physicalText ?? FormatWidget.units(context.state.units))
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .foregroundStyle(context.state.isOver ? wt.danger : .white)
                }
                .padding(.leading, 2)
            } compactTrailing: {
                if context.state.isOver {
                    Text("该停了")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(wt.danger)
                } else if let next = context.state.nextPromptAt {
                    PromptCountdown(target: next, isStale: context.isStale)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(wt.accent)
                } else {
                    Text(context.state.physicalSoftLimitText != nil ? "\(context.state.physicalSoftLimitText!)线" : "\(FormatWidget.units(context.state.softLimit))杯线")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } minimal: {
                Image(systemName: "wineglass.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(wt.status(for: context.state))
            }
        }
    }
}

// MARK: - 朱砂印章（与 App 内 CinnabarSeal 同款；小组件拿不到 App 的 Theme，颜色由调用方传入）

struct WidgetSeal: View {
    let text: String
    let color: Color

    var body: some View {
        CarvedSeal(text: text, color: color)
    }
}

// MARK: - 锁屏实时卡片 (随主题联动表盘)

/// 下次提醒倒计时。App 挂起期间卡片不会刷新，`Text(_:style: .timer)` 过点后会转为正向计时、数字越走越大；
/// 改用 timerInterval 倒计时并停在 0:00，到达 staleDate（即该次提醒时间）后提示「待回应」。
struct PromptCountdown: View {
    let target: Date
    let isStale: Bool

    var body: some View {
        if isStale || target <= .now {
            Text("待回应")
        } else {
            Text(timerInterval: Date.now...target, countsDown: true)
        }
    }
}

struct LockScreenLiveActivityView: View {
    let state: TingBeiAttributes.ContentState
    let attributes: TingBeiAttributes
    let isStale: Bool
    let wt: WidgetThemeColors

    /// isOver 同时覆盖「到线」与「越线」；cue 区分二者
    private var isPastHard: Bool { state.cue == "over" }
    private var statusColor: Color { wt.status(for: state) }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // 左侧：常态为杯量圆环（实线确认 + 虚线推测）；该停档换成朱砂印章
            if state.isOver {
                WidgetSeal(text: isPastHard ? "停杯" : "当止", color: wt.danger)
                    .frame(width: 58, height: 58)
            } else {
            ZStack {
                Circle()
                    .stroke(wt.textPrimary.opacity(0.14), lineWidth: 4)
                let hard = max(1.0, state.hardLimit)
                let totalProgress = min(1.0, state.units / hard)
                let confirmedProgress = min(1.0, (state.confirmedUnits ?? state.units) / hard)
                let ringColor = statusColor

                if totalProgress > confirmedProgress {
                    Circle()
                        .trim(from: confirmedProgress, to: totalProgress)
                        .stroke(
                            ringColor.opacity(0.65),
                            style: StrokeStyle(lineWidth: 4, lineCap: .butt, dash: [3, 3])
                        )
                        .rotationEffect(.degrees(-90))
                }

                if confirmedProgress > 0 {
                    Circle()
                        .trim(from: 0, to: confirmedProgress)
                        .stroke(
                            ringColor,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }

                VStack(spacing: 0) {
                    Text(state.physicalText ?? FormatWidget.units(state.units))
                        .font(.system(size: state.physicalText != nil ? 14 : 22, weight: .light, design: .serif))
                        .foregroundStyle(wt.textPrimary)
                    Text(state.physicalSoftLimitText != nil ? "/\(state.physicalSoftLimitText!)" : "/\(FormatWidget.units(state.softLimit))杯")
                        .font(.system(size: 11))
                        .foregroundStyle(wt.textMuted)
                }
            }
            .frame(width: 58, height: 58)
            }

            // 中间：状态与文案
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(state.title)
                        .font(.system(size: state.isOver ? 18 : 16, weight: .semibold, design: .serif))
                        .foregroundStyle(statusColor)
                    Text("·")
                        .foregroundStyle(wt.textMuted)
                    Text(state.physicalText ?? attributes.planName)
                        .font(.caption2.bold())
                        .foregroundStyle(wt.textPrimary.opacity(0.8))
                }

                Text(state.message)
                    .font(.caption)
                    .foregroundStyle(wt.textPrimary.opacity(0.85))
                    .lineLimit(1)

                // 核心修复：越线后绝不显示过期的静态时间，显示实时的超限警示
                if state.isOver {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .font(.system(size: 11))
                        if !isPastHard {
                            Text("已到建议线 · 花看半开")
                                .font(.caption2.bold())
                        } else if let count = state.overCount, count > 0 {
                            Text("已超上限 · 第 \(count) 次提醒")
                                .font(.caption2.bold())
                        } else {
                            Text("已超上限 · 持续提醒中")
                                .font(.caption2.bold())
                        }
                    }
                    .foregroundStyle(wt.danger)
                } else if let next = state.nextPromptAt {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 11))
                        Text("下次提醒")
                        PromptCountdown(target: next, isStale: isStale)
                            .font(.caption2.monospacedDigit())
                    }
                    .foregroundStyle(wt.accent.opacity(0.9))
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 11))
                        Text("节拍守护中")
                            .font(.caption2)
                    }
                    .foregroundStyle(wt.textMuted)
                }
            }

            Spacer(minLength: 0)

            // 右侧快速操作
            // 右侧快速操作：常态「+1」在上为主；该停档「收杯」放大置顶，「+1」退为小号
            if state.isOver {
                VStack(spacing: 6) {
                    Link(destination: URL(string: "tingbei://end")!) {
                        Text("收杯")
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .frame(width: 56, height: 40)
                            .background(Capsule().fill(wt.danger))
                            .foregroundStyle(.white)
                    }
                    Link(destination: URL(string: "tingbei://logDrink")!) {
                        Text("+1")
                            .font(.system(size: 12, design: .serif))
                            .frame(width: 56, height: 22)
                            .background(Capsule().fill(wt.textPrimary.opacity(0.10)))
                            .foregroundStyle(wt.textMuted)
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Link(destination: URL(string: "tingbei://logDrink")!) {
                        Text("+1")
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .frame(width: 44, height: 32)
                            .background(Capsule().fill(wt.accent.opacity(0.2)))
                            .foregroundStyle(wt.accent)
                    }

                    Link(destination: URL(string: "tingbei://end")!) {
                        Text("收")
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .frame(width: 44, height: 26)
                            .background(Capsule().fill(wt.textPrimary.opacity(0.14)))
                            .foregroundStyle(wt.textPrimary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(wt.bg)
    }
}

enum FormatWidget {
    static func units(_ value: Double) -> String {
        let tenths = (value * 10).rounded() / 10
        if abs(tenths - tenths.rounded()) < 0.001 {
            return String(Int(tenths.rounded()))
        }
        return String(format: "%.1f", tenths)
    }
}
