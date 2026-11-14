import SwiftUI
import UIKit
@preconcurrency import UserNotifications

@main
struct TingBeiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private var store: SessionStore { appDelegate.store }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "tingbei" else { return }
        switch url.host {
        case "logWater":
            store.logWater()
        case "logDrink":
            store.logDrink()
        case "end":
            store.handleDeepLinkEnd()
        default:
            break
        }
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// 由 AppDelegate 持有：锁屏点通知按钮冷启动时只在后台运行、不会创建窗口，
    /// 若等 RootView.onAppear 再注入，回调到达时 store 仍为空，操作会被静默丢弃。
    let store = SessionStore.shared

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        await MainActor.run {
            store.tick()
        }
        return [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionIdentifier = response.actionIdentifier
        // 先在当前上下文取出可跨 actor 传递的 String，避免把非 Sendable 的 userInfo 带到主线程
        let promptIDString = response.notification.request.content.userInfo["promptID"] as? String
        await store.handleNotificationAction(actionIdentifier: actionIdentifier, promptIDString: promptIDString)
    }
}
