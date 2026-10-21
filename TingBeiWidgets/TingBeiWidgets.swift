import WidgetKit
import SwiftUI
import ActivityKit

@main
struct TingBeiWidgetBundle: WidgetBundle {
    var body: some Widget {
        TingBeiLiveActivityWidget()
    }
}

struct TingBeiLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TingBeiAttributes.self) { context in
            // 锁屏实时卡片 (Lock Screen Banner)
            LockScreenLiveActivityView(state: context.state, attributes: context.attributes)
                .activityBackgroundTint(Color(red: 0.05, green: 0.04, blue: 0.03))
                .activitySystemActionForegroundColor(Color(red: 0.79, green: 0.66, blue: 0.43))
        } dynamicIsland: { context in
            DynamicIsland {
                // 长按展开态 (Expanded View)
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("停杯")
                                .font(.system(size: 11, weight: .semibold, design: .serif))
                                .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.43))
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(context.attributes.planName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(FormatWidget.units(context.state.units))
                                .font(.system(size: 26, weight: .bold, design: .serif))
                                .foregroundStyle(context.state.isOver ? Color(red: 0.90, green: 0.30, blue: 0.25) : .white)
                            Text("/ \(context.state.softLimit)杯")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(context.state.isOver ? Color(red: 0.90, green: 0.30, blue: 0.25) : Color(red: 0.79, green: 0.66, blue: 0.43))

                        if let next = context.state.nextPromptAt {
                            HStack(spacing: 3) {
                                Image(systemName: "bell.badge")
                                    .font(.system(size: 9))
                                Text(next, style: .time)
                                    .font(.system(size: 11, design: .monospaced))
                            }
                            .foregroundStyle(.secondary)
                        } else {
                            Text(Date(timeIntervalSinceNow: -context.state.elapsedSeconds), style: .timer)
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
                                Label("+1杯", systemImage: "plus")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.25)))
                                    .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.43))
                            }

                            Spacer()

                            Link(destination: URL(string: "tingbei://end")!) {
                                Text("我停了")
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(context.state.isOver ? Color(red: 0.76, green: 0.28, blue: 0.22) : Color.white.opacity(0.15)))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // 紧凑左侧：酒杯与当前杯数
                HStack(spacing: 3) {
                    Image(systemName: "wineglass.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(context.state.isOver ? Color(red: 0.90, green: 0.30, blue: 0.25) : Color(red: 0.79, green: 0.66, blue: 0.43))
                    Text(FormatWidget.units(context.state.units))
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .foregroundStyle(context.state.isOver ? Color(red: 0.90, green: 0.30, blue: 0.25) : .white)
                }
                .padding(.leading, 2)
            } compactTrailing: {
                // 紧凑右侧：状态或倒计时
                if context.state.isOver {
                    Text("该停了")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.90, green: 0.30, blue: 0.25))
                } else if let next = context.state.nextPromptAt {
                    Text(next, style: .time)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.43))
                } else {
                    Text("\(context.state.softLimit)杯线")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } minimal: {
                // 最小化态（多个 Live Activity 竞争时）
                Image(systemName: "wineglass.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(context.state.isOver ? Color(red: 0.90, green: 0.30, blue: 0.25) : Color(red: 0.79, green: 0.66, blue: 0.43))
            }
        }
    }
}

// MARK: - 锁屏实时卡片 (黑金沉浸表盘)

struct LockScreenLiveActivityView: View {
    let state: TingBeiAttributes.ContentState
    let attributes: TingBeiAttributes

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // 左侧：杯量与金色指示圆环
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 4)
                let progress = min(1.0, state.units / Double(max(1, state.hardLimit)))
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        state.isOver ? Color(red: 0.76, green: 0.28, blue: 0.22) : Color(red: 0.79, green: 0.66, blue: 0.43),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text(FormatWidget.units(state.units))
                        .font(.system(size: 24, weight: .light, design: .serif))
                        .foregroundStyle(.white)
                    Text("/\(state.softLimit)")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: 58, height: 58)

            // 中间：状态与文案
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(state.title)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(state.isOver ? Color(red: 0.90, green: 0.35, blue: 0.30) : Color(red: 0.79, green: 0.66, blue: 0.43))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.3))
                    Text(attributes.planName)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Text(state.message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)

                if let next = state.nextPromptAt {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 9))
                        Text("下次主动提醒 \(next, style: .time)")
                            .font(.caption2.monospacedDigit())
                    }
                    .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.9))
                }
            }

            Spacer(minLength: 0)

            // 右侧快速操作
            VStack(spacing: 6) {
                Link(destination: URL(string: "tingbei://logDrink")!) {
                    Text("+1")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .frame(width: 44, height: 32)
                        .background(Capsule().fill(Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.2)))
                        .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.43))
                }

                Link(destination: URL(string: "tingbei://end")!) {
                    Text("收")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .frame(width: 44, height: 26)
                        .background(Capsule().fill(state.isOver ? Color(red: 0.76, green: 0.28, blue: 0.22) : Color.white.opacity(0.12)))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.05, green: 0.04, blue: 0.03))
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
