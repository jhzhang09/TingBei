import SwiftUI
import UIKit
@preconcurrency import UserNotifications

@main
struct TingBeiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .onAppear {
                    appDelegate.store = store
                }
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
            store.end()
        default:
            break
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var store: SessionStore?

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
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run {
            store?.handleNotificationAction(actionIdentifier: actionIdentifier, userInfo: userInfo)
        }
    }
}
