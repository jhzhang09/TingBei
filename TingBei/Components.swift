import SwiftUI

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
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.mute)

                Text(metric)
                    .font(.system(size: 11, weight: .medium))
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
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("删除这场记录")
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

struct LogLine: Identifiable {
    let id: UUID
    let at: Date
    let text: String
    let color: Color
    var promptID: UUID? = nil
}

// MARK: - 朱砂印章：该停档的醒目标记

/// 汉印篆白文朱砂方印，两字自右向左。用于到线 / 越线时盖在表盘上：
/// 印章是书画里最醒目的符号，能在不破坏表盘美感的前提下把「该停」说清楚。
struct CinnabarSeal: View {
    /// 两个字，首字在右，如「当止」「停杯」
    let text: String
    var size: CGFloat = 58

    var body: some View {
        CarvedSeal(text: text, color: Theme.wine)
            .frame(width: size, height: size)
    }
}
