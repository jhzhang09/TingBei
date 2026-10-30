import SwiftUI
import UIKit

// MARK: - Root View

struct RootView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var store = store
        ZStack(alignment: .top) {
            NightBackground(cue: store.snapshot?.cue)
            if store.active != nil {
                SessionView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                HomeView()
                    .transition(.opacity)
            }

            // 全局顶部悬浮胶囊提示（带高光倒角）
            if let toast = store.toast {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle")
                        .font(.caption2.bold())
                        .foregroundStyle(Theme.goldBright)
                    Text(toast)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.cream)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Theme.raised.opacity(0.96))
                        .shadow(color: Theme.cardShadow, radius: 16, y: 6)
                )
                .overlay(Capsule().stroke(Theme.bezelGradient, lineWidth: 1))
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.smooth(duration: 0.35), value: store.active != nil)
        .animation(.smooth(duration: 0.28), value: store.toast)
        .animation(.smooth(duration: 0.32), value: Theme.current)
        .preferredColorScheme(Theme.colorScheme)
        .tint(Theme.gold)
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
        .onAppear {
            Theme.apply(store.settings.selectedTheme)
            store.sceneAppeared()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.sceneAppeared()
            } else if phase == .background {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
        .sheet(item: $store.review) { session in
            SummarySheet(session: session)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
                .preferredColorScheme(Theme.colorScheme)
        }
    }
}

// MARK: - Night Background (环境呼吸氛围光)

struct NightBackground: View {
    var cue: Cue?

    var body: some View {
        let heat = heat(for: cue)
        let topGoldAlpha = Theme.isLight ? (0.10 * (1 - heat) + 0.02) : (0.14 * (1 - heat) + 0.03)
        let topWineAlpha = Theme.isLight ? (0.22 * heat) : (0.38 * heat)
        ZStack {
            Theme.bg
            RadialGradient(
                colors: [
                    Theme.gold.opacity(topGoldAlpha),
                    Theme.wine.opacity(topWineAlpha),
                    .clear,
                ],
                center: .top,
                startRadius: 5,
                endRadius: 540
            )
            RadialGradient(
                colors: [
                    Theme.gold.opacity(Theme.isLight ? 0.04 : 0.05),
                    .clear,
                ],
                center: .bottom,
                startRadius: 20,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
        .animation(.smooth(duration: 0.8), value: cue)
    }

    private func heat(for cue: Cue?) -> Double {
        switch cue {
        case nil, .calm: 0
        case .settle: 0.12
        case .hurried: 0.38
        case .near: 0.55
        case .due: 0.78
        case .over: 1.0
        }
    }
}
