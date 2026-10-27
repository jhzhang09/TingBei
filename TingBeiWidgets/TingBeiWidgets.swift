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
            // 汝窑天青：雨过天青云破处，温润粉青瓷釉与香灰胎骨墨字
            return WidgetThemeColors(
                bg: Color(red: 0.843, green: 0.886, blue: 0.878),
                accent: Color(red: 0.259, green: 0.467, blue: 0.455),
                danger: Color(red: 0.698, green: 0.290, blue: 0.255),
                textPrimary: Color(red: 0.149, green: 0.208, blue: 0.200),
                textMuted: Color(red: 0.149, green: 0.208, blue: 0.200).opacity(0.62)
            )
        case "burgundyCellar":
            return WidgetThemeColors(
                bg: Color(red: 0.071, green: 0.031, blue: 0.035),
                accent: Color(red: 0.824, green: 0.565, blue: 0.439),
                danger: Color(red: 0.855, green: 0.220, blue: 0.259),
                textPrimary: Color(red: 0.961, green: 0.918, blue: 0.910),
                textMuted: Color.white.opacity(0.6)
            )
        case "midnightSapphire":
            return WidgetThemeColors(
                bg: Color(red: 0.027, green: 0.051, blue: 0.086),
                accent: Color(red: 0.447, green: 0.682, blue: 0.855),
                danger: Color(red: 0.878, green: 0.302, blue: 0.271),
                textPrimary: Color(red: 0.925, green: 0.949, blue: 0.976),
                textMuted: Color.white.opacity(0.6)
            )
        case "enamelIvory":
            return WidgetThemeColors(
                bg: Color(red: 0.961, green: 0.949, blue: 0.925),
                accent: Color(red: 0.620, green: 0.416, blue: 0.188),
                danger: Color(red: 0.722, green: 0.212, blue: 0.180),
                textPrimary: Color(red: 0.106, green: 0.094, blue: 0.082),
                textMuted: Color(red: 0.106, green: 0.094, blue: 0.082).opacity(0.6)
            )
        case "xuanPaperInk":
            // 宣纸水墨：陈年泾县生宣、徽州松烟墨与泥金乌丝
            return WidgetThemeColors(
                bg: Color(red: 0.937, green: 0.922, blue: 0.886),
                accent: Color(red: 0.451, green: 0.365, blue: 0.247),
                danger: Color(red: 0.737, green: 0.204, blue: 0.169),
                textPrimary: Color(red: 0.122, green: 0.118, blue: 0.110),
                textMuted: Color(red: 0.122, green: 0.118, blue: 0.110).opacity(0.6)
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
