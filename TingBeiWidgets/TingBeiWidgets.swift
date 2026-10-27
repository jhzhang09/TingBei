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

    static func resolve(for themeID: String?) -> WidgetThemeColors {
        switch themeID {
        case "celadonJade":
            return WidgetThemeColors(
                bg: Color(red: 0.04, green: 0.08, blue: 0.08),
                accent: Color(red: 0.50, green: 0.78, blue: 0.73),
                danger: Color(red: 0.88, green: 0.36, blue: 0.31),
                textPrimary: Color(red: 0.91, green: 0.95, blue: 0.94),
                textMuted: Color.white.opacity(0.6)
            )
        case "burgundyCellar":
            return WidgetThemeColors(
                bg: Color(red: 0.08, green: 0.03, blue: 0.05),
                accent: Color(red: 0.90, green: 0.64, blue: 0.52),
                danger: Color(red: 0.93, green: 0.30, blue: 0.38),
                textPrimary: Color(red: 0.97, green: 0.92, blue: 0.92),
                textMuted: Color.white.opacity(0.6)
            )
        case "midnightSapphire":
            return WidgetThemeColors(
                bg: Color(red: 0.03, green: 0.06, blue: 0.11),
                accent: Color(red: 0.48, green: 0.74, blue: 0.94),
                danger: Color(red: 0.91, green: 0.35, blue: 0.31),
                textPrimary: Color(red: 0.93, green: 0.95, blue: 0.98),
                textMuted: Color.white.opacity(0.6)
            )
        case "enamelIvory":
            return WidgetThemeColors(
                bg: Color(red: 0.96, green: 0.94, blue: 0.90),
                accent: Color(red: 0.62, green: 0.41, blue: 0.17),
                danger: Color(red: 0.76, green: 0.20, blue: 0.17),
                textPrimary: Color(red: 0.14, green: 0.11, blue: 0.09),
                textMuted: Color(red: 0.14, green: 0.11, blue: 0.09).opacity(0.6)
            )
        case "xuanPaperInk":
            return WidgetThemeColors(
                bg: Color(red: 0.93, green: 0.92, blue: 0.90),
                accent: Color(red: 0.25, green: 0.43, blue: 0.38),
                danger: Color(red: 0.75, green: 0.21, blue: 0.18),
                textPrimary: Color(red: 0.12, green: 0.13, blue: 0.12),
                textMuted: Color(red: 0.12, green: 0.13, blue: 0.12).opacity(0.6)
            )
        default:
            return WidgetThemeColors(
                bg: Color(red: 0.05, green: 0.04, blue: 0.03),
                accent: Color(red: 0.79, green: 0.66, blue: 0.43),
                danger: Color(red: 0.86, green: 0.30, blue: 0.25),
                textPrimary: .white,
                textMuted: Color.white.opacity(0.6)
            )
        }
    }
}

struct TingBeiLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TingBeiAttributes.self) { context in
            let wt = WidgetThemeColors.resolve(for: context.state.themeID)
            // 锁屏实时卡片 (Lock Screen Banner)
            LockScreenLiveActivityView(state: context.state, attributes: context.attributes, wt: wt)
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
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(context.state.isOver ? wt.danger : wt.accent)

                        if context.state.isOver {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.octagon.fill")
                                    .font(.system(size: 9))
                                Text("每10分钟提醒")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(wt.danger)
                        } else if let next = context.state.nextPromptAt {
                            HStack(spacing: 3) {
                                Image(systemName: "bell.badge")
                                    .font(.system(size: 9))
                                Text(next, style: .timer)
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
                        .foregroundStyle(context.state.isOver ? wt.danger : wt.accent)
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
                    Text(next, style: .timer)
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
                    .foregroundStyle(context.state.isOver ? wt.danger : wt.accent)
            }
        }
    }
}

// MARK: - 锁屏实时卡片 (随主题联动表盘)

struct LockScreenLiveActivityView: View {
    let state: TingBeiAttributes.ContentState
    let attributes: TingBeiAttributes
    let wt: WidgetThemeColors

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // 左侧：杯量与主题指示圆环（实线确认 + 虚线推测）
            ZStack {
                Circle()
                    .stroke(wt.textPrimary.opacity(0.14), lineWidth: 4)
                let hard = max(1.0, state.hardLimit)
                let totalProgress = min(1.0, state.units / hard)
                let confirmedProgress = min(1.0, (state.confirmedUnits ?? state.units) / hard)
                let ringColor = state.isOver ? wt.danger : wt.accent

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
                        .font(.system(size: 9))
                        .foregroundStyle(wt.textMuted)
                }
            }
            .frame(width: 58, height: 58)

            // 中间：状态与文案
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(state.title)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(state.isOver ? wt.danger : wt.accent)
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
                            .font(.system(size: 10))
                        if let count = state.overCount, count > 0 {
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
                            .font(.system(size: 9))
                        Text("下次提醒")
                        Text(next, style: .timer)
                            .font(.caption2.monospacedDigit())
                    }
                    .foregroundStyle(wt.accent.opacity(0.9))
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 9))
                        Text("节拍守护中")
                            .font(.caption2)
                    }
                    .foregroundStyle(wt.textMuted)
                }
            }

            Spacer(minLength: 0)

            // 右侧快速操作
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
                        .background(Capsule().fill(state.isOver ? wt.danger : wt.textPrimary.opacity(0.14)))
                        .foregroundStyle(state.isOver ? .white : wt.textPrimary)
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
