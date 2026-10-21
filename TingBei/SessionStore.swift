import Foundation
import UIKit
import ActivityKit
@preconcurrency import UserNotifications

enum NotificationActionID {
    static let category = "TINGBEI_PROMPT"
    static let drank = "ACTION_DRANK"
    static let skipped = "ACTION_SKIPPED"
    static let stop = "ACTION_STOP"
}

enum NotificationPermission {
    case unknown
    case allowed
    case denied
}

enum HapticFeedbackEvent: Equatable {
    case tap
    case soft
    case warning
    case stop
    case success
}

struct SignatureStatus: Equatable {
    var daysRemaining: Int?
    var expirationDate: Date?
    var isSimulator: Bool

    var displayText: String {
        if isSimulator {
            return "开发环境 (模拟器运行)"
        }
        guard let days = daysRemaining else {
            return "永久有效 / 生产发布版"
        }
        if days < 0 {
            return "签名已过期"
        } else if days == 0 {
            return "签名将于今日到期"
        } else {
            return "签名剩余 \(days) 天 · 自动续签保护中"
        }
    }

    static func current() -> SignatureStatus {
        #if targetEnvironment(simulator)
        return SignatureStatus(daysRemaining: nil, expirationDate: nil, isSimulator: true)
        #else
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let rawString = String(data: data, encoding: .ascii) ?? String(data: data, encoding: .isoLatin1) else {
            return SignatureStatus(daysRemaining: nil, expirationDate: nil, isSimulator: false)
        }

        guard let xmlStart = rawString.range(of: "<?xml"),
              let xmlEnd = rawString.range(of: "</plist>", range: xmlStart.lowerBound..<rawString.endIndex) else {
            return SignatureStatus(daysRemaining: nil, expirationDate: nil, isSimulator: false)
        }

        let xmlSubstring = rawString[xmlStart.lowerBound..<xmlEnd.upperBound]
        guard let xmlData = xmlSubstring.data(using: .utf8),
              let plist = (try? PropertyListSerialization.propertyList(from: xmlData, options: [], format: nil)) as? [String: Any],
              let expirationDate = plist["ExpirationDate"] as? Date else {
            return SignatureStatus(daysRemaining: nil, expirationDate: nil, isSimulator: false)
        }

        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: .now, to: expirationDate).day ?? 0
        return SignatureStatus(daysRemaining: max(0, days), expirationDate: expirationDate, isSimulator: false)
        #endif
    }
}

@MainActor
@Observable
final class SessionStore {
    var settings: Settings
    var active: Session?
    var history: [Session]
    var now: Date = .now
    var review: Session?
    var notificationPermission: NotificationPermission = .unknown
    var bannerPulse = 0
    var toast: String?
    var saveFailed = false
    var hapticEvent: HapticFeedbackEvent?
    var signatureStatus: SignatureStatus = .current()
    private var currentActivity: Activity<TingBeiAttributes>? = nil

    private var clock: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    init() {
        let saved = Self.load()
        settings = saved.settings
        active = saved.active
        history = saved.history
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--sample") {
            installSample()
        }
        #endif
        registerNotificationCategories()
        if active != nil {
            armClock()
        }
    }

    var snapshot: PaceSnapshot? {
        guard let active else { return nil }
        return Pace.evaluate(active, now: now)
    }

    var wantsScreenOn: Bool {
        active != nil && settings.keepScreenOn
    }

    func triggerHaptic(_ event: HapticFeedbackEvent) {
        hapticEvent = event
    }

    func sceneAppeared() {
        now = .now
        signatureStatus = .current()
        applyIdleTimer()
        Task {
            await refreshNotificationPermission()
        }
        if let session = active {
            reschedule()
            armClock()
            updateLiveActivity(session: session, snap: Pace.evaluate(session, now: now))
        }
    }

    func normalizeAndSaveSettings() {
        var next = settings
        next.normalize()
        if next != settings {
            settings = next
        }
        persist()
        applyIdleTimer()
    }

    func start(_ plan: Plan) {
        var plan = plan
        if plan.hardLimit < plan.softLimit {
            plan.hardLimit = plan.softLimit
        }
        let initialNow = Date.now
        var session = Session(
            id: UUID(),
            startedAt: initialNow,
            endedAt: nil,
            planName: plan.name,
            plannedMinutes: plan.plannedMinutes,
            softLimit: plan.softLimit,
            hardLimit: plan.hardLimit,
            minIntervalMinutes: plan.minIntervalMinutes,
            estimateWhenSilent: settings.estimateWhenSilent,
            drinks: [],
            waters: [],
            prompts: [],
            lastAnnouncedRank: 0,
            lastAnnouncedCue: nil
        )
        // 预排未来的主动提醒
        session.prompts = Pace.projectPrompts(session, now: initialNow)
        let initialSnap = Pace.evaluate(session, now: initialNow)
        session.lastAnnouncedRank = initialSnap.intensity.rawValue
        session.lastAnnouncedCue = initialSnap.cue
        active = session
        now = initialNow
        bannerPulse += 1
        persist()
        applyIdleTimer()
        armClock()
        startLiveActivity(session: session, snap: initialSnap)
        Task {
            await requestNotificationsThenSchedule()
        }
        triggerHaptic(.tap)
    }

    /// 用户在界面或通知上确认：喝了一杯。
    /// 可以指定具体酒类，若未指定则默认按一个通用标准杯计入。
    func logDrink(preset: DrinkPreset = Pace.genericDrink, at customDate: Date? = nil) {
        guard var session = active else { return }
        let logTime = customDate ?? .now
        let before = Pace.evaluate(session, now: .now)

        let newDrinkID = UUID()
        session.drinks.append(
            DrinkLog(
                id: newDrinkID,
                presetID: preset.id,
                name: preset.name,
                detail: preset.detail,
                grams: preset.grams,
                at: logTime
            )
        )

        // 对应标记刚才可能已经触发的提醒（若有）为已确认，避免重复计入估算
        for i in 0..<session.prompts.count {
            if session.prompts[i].reply == nil && session.prompts[i].at <= logTime.addingTimeInterval(5 * 60) {
                session.prompts[i].reply = .logged
                session.prompts[i].drinkID = newDrinkID
            }
        }

        // 刷新未来的提醒时间表
        updatePrompts(&session, now: .now)

        let after = Pace.evaluate(session, now: .now)
        session.lastAnnouncedRank = after.intensity.rawValue
        session.lastAnnouncedCue = after.cue
        active = session
        now = .now
        bannerPulse += 1
        persist()
        reschedule()
        updateLiveActivity(session: session, snap: after)

        if after.cue == .over {
            triggerHaptic(.stop)
        } else if after.intensity > before.intensity || after.cue == .hurried {
            triggerHaptic(.warning)
        } else {
            triggerHaptic(.tap)
        }
    }

    func logCustom(name: String, volumeMl: Double, abv: Double, at customDate: Date? = nil) {
        let preset = DrinkPreset.custom(name: name, volumeMl: volumeMl, abv: abv)
        logDrink(preset: preset, at: customDate)
    }

    /// 用户回应某次主动提醒："这段时间没喝"
    func handlePromptReply(promptID: UUID, reply: PromptReply) {
        guard var session = active else { return }
        guard let idx = session.prompts.firstIndex(where: { $0.id == promptID }) else { return }

        session.prompts[idx].reply = reply
        if reply == .drank {
            let drinkID = UUID()
            session.drinks.append(
                DrinkLog(
                    id: drinkID,
                    presetID: Pace.genericDrink.id,
                    name: Pace.genericDrink.name,
                    detail: Pace.genericDrink.detail,
                    grams: Pace.genericDrink.grams,
                    at: session.prompts[idx].at
                )
            )
            session.prompts[idx].drinkID = drinkID
        }

        updatePrompts(&session, now: .now)
        active = session
        now = .now
        bannerPulse += 1
        persist()
        reschedule()
        updateLiveActivity(session: session, snap: Pace.evaluate(session, now: .now))
        triggerHaptic(.soft)
    }

    func logWater() {
        guard var session = active else { return }
        session.waters.append(WaterLog(id: UUID(), at: .now))
        active = session
        persist()
        showToast("💧 及时补水，给身体留足代谢缓冲")
        updateLiveActivity(session: session, snap: Pace.evaluate(session, now: .now))
        triggerHaptic(.soft)
    }

    func undoLast() {
        guard var session = active else { return }
        let drink = session.drinks.max(by: { $0.at < $1.at })
        let water = session.waters.max(by: { $0.at < $1.at })
        switch (drink?.at, water?.at) {
        case let (drinkAt?, waterAt?) where waterAt > drinkAt:
            session.waters.removeAll { $0.id == water?.id }
        case (nil, _?):
            session.waters.removeAll { $0.id == water?.id }
        case (_?, _):
            if let drinkID = drink?.id {
                session.drinks.removeAll { $0.id == drinkID }
                for i in 0..<session.prompts.count where session.prompts[i].drinkID == drinkID {
                    session.prompts[i].reply = nil
                    session.prompts[i].drinkID = nil
                }
            }
        default:
            return
        }

        updatePrompts(&session, now: .now)
        let after = Pace.evaluate(session, now: .now)
        session.lastAnnouncedRank = after.intensity.rawValue
        session.lastAnnouncedCue = after.cue
        active = session
        now = .now
        bannerPulse += 1
        persist()
        reschedule()
        updateLiveActivity(session: session, snap: after)
        triggerHaptic(.soft)
    }

    func end() {
        guard var session = active else { return }
        let end = Date()
        session.endedAt = end

        // 结束时若完全空场（0 杯且未喝水）并且时间短于 5 分钟，直接静默丢弃
        if session.drinks.isEmpty && session.duration < 5 * 60 {
            active = nil
            clock?.cancel()
            toast = nil
            persist()
            endLiveActivity()
            clearNotifications()
            applyIdleTimer()
            triggerHaptic(.tap)
            return
        }

        let finalSnap = Pace.evaluate(session, now: end)
        session.lastAnnouncedRank = finalSnap.intensity.rawValue
        session.lastAnnouncedCue = finalSnap.cue
        history.append(session)
        if history.count > 50 {
            history.removeFirst(history.count - 50)
        }
        review = session
        active = nil
        clock?.cancel()
        toast = nil
        persist()
        endLiveActivity()
        clearNotifications()
        applyIdleTimer()
        triggerHaptic(.success)
    }

    func deleteHistory(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        persist()
    }

    func deleteHistory(id: UUID) {
        history.removeAll { $0.id == id }
        persist()
    }

    func clearEmptyHistory() {
        history.removeAll { $0.drinks.isEmpty }
        persist()
    }

    func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func tick() {
        guard active != nil else { return }
        now = .now
        guard var session = active else { return }
        let snap = Pace.evaluate(session, now: now)
        let previousRank = session.lastAnnouncedRank
        let previousCue = session.lastAnnouncedCue

        let rankEscalated = snap.intensity.rawValue > previousRank
        let cueChanged = snap.cue != previousCue
        let enteredCriticalCue = cueChanged && (snap.cue == .hurried || snap.cue == .due || snap.cue == .over)

        if rankEscalated || enteredCriticalCue {
            session.lastAnnouncedRank = snap.intensity.rawValue
            session.lastAnnouncedCue = snap.cue
            active = session
            bannerPulse += 1
            persist()

            if snap.cue == .over {
                triggerHaptic(.stop)
            } else {
                triggerHaptic(.warning)
            }
        } else if cueChanged {
            session.lastAnnouncedRank = snap.intensity.rawValue
            session.lastAnnouncedCue = snap.cue
            active = session
            persist()
        }

        updateLiveActivity(session: session, snap: snap)
    }

    private func updatePrompts(_ session: inout Session, now: Date) {
        // 保留过去已经发生的 prompts 及其记录，未来未发生的按新节奏重新推演
        let past = session.prompts.filter { $0.at <= now }
        let future = Pace.projectPrompts(session, now: now)
        session.prompts = past + future
    }

    func reschedule() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard let session = active, session.endedAt == nil else { return }

        // 取未来未来的 prompts 排期推送
        let upcoming = session.prompts.filter { $0.at > .now }.sorted(by: { $0.at < $1.at })
        var overCounter = 0

        for prompt in upcoming.prefix(Pace.promptBudget) {
            let content = UNMutableNotificationContent()
            if prompt.level == .over {
                overCounter += 1
            }
            let copy = Pace.notificationCopy(for: prompt, session: session, ordinal: max(1, overCounter))
            content.title = copy.title
            content.body = copy.body
            content.categoryIdentifier = NotificationActionID.category
            content.threadIdentifier = "tingbei.session"
            content.userInfo = ["promptID": prompt.id.uuidString]

            // 高级明显提醒策略：突破静音/专注模式 + 专属强声音
            if prompt.level >= .due {
                content.interruptionLevel = .timeSensitive
                content.sound = .defaultCritical
            } else if prompt.level >= .steady {
                content.interruptionLevel = .timeSensitive
                content.sound = .default
            } else {
                content.interruptionLevel = .active
                content.sound = .default
            }

            let parts = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: prompt.at
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            let request = UNNotificationRequest(identifier: "tingbei." + prompt.id.uuidString, content: content, trigger: trigger)
            center.add(request)
        }
    }

    func registerNotificationCategories() {
        let drankAction = UNNotificationAction(
            identifier: NotificationActionID.drank,
            title: "喝了一杯",
            options: []
        )
        let skippedAction = UNNotificationAction(
            identifier: NotificationActionID.skipped,
            title: "还没喝",
            options: []
        )
        let stopAction = UNNotificationAction(
            identifier: NotificationActionID.stop,
            title: "我收杯了",
            options: [.destructive]
        )

        let category = UNNotificationCategory(
            identifier: NotificationActionID.category,
            actions: [drankAction, skippedAction, stopAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func handleNotificationAction(actionIdentifier: String, userInfo: [AnyHashable: Any]) {
        if actionIdentifier == NotificationActionID.stop {
            end()
            return
        }

        guard let promptIDString = userInfo["promptID"] as? String,
              let promptID = UUID(uuidString: promptIDString) else {
            return
        }

        switch actionIdentifier {
        case NotificationActionID.drank:
            handlePromptReply(promptID: promptID, reply: .drank)
        case NotificationActionID.skipped:
            handlePromptReply(promptID: promptID, reply: .skipped)
        default:
            break
        }
    }

    func requestNotificationsThenSchedule() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                notificationPermission = granted ? .allowed : .denied
                if granted {
                    reschedule()
                }
            } catch {
                notificationPermission = .denied
            }
        case .denied:
            notificationPermission = .denied
        case .authorized, .provisional, .ephemeral:
            notificationPermission = .allowed
            reschedule()
        @unknown default:
            notificationPermission = .unknown
            reschedule()
        }
    }

    func refreshNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationPermission = .allowed
        case .denied:
            notificationPermission = .denied
        case .notDetermined:
            notificationPermission = .unknown
        @unknown default:
            notificationPermission = .unknown
        }
    }

    private func clearNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Live Activity & 灵动岛管理

    private func startLiveActivity(session: Session, snap: PaceSnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            await clearAllActivities()
            let attributes = TingBeiAttributes(startedAt: session.startedAt, planName: session.planName)
            let state = TingBeiAttributes.ContentState(
                units: snap.units,
                softLimit: session.softLimit,
                hardLimit: session.hardLimit,
                cue: snap.cue.rawValue,
                title: snap.title,
                message: snap.message,
                nextPromptAt: snap.nextPrompt?.at,
                elapsedSeconds: snap.elapsed,
                isOver: snap.cue == .over || snap.cue == .due
            )

            _ = try? Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        }
    }

    private func updateLiveActivity(session: Session, snap: PaceSnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = TingBeiAttributes.ContentState(
            units: snap.units,
            softLimit: session.softLimit,
            hardLimit: session.hardLimit,
            cue: snap.cue.rawValue,
            title: snap.title,
            message: snap.message,
            nextPromptAt: snap.nextPrompt?.at,
            elapsedSeconds: snap.elapsed,
            isOver: snap.cue == .over || snap.cue == .due
        )

        Task {
            let activities = Activity<TingBeiAttributes>.activities
            if !activities.isEmpty {
                let content = ActivityContent(state: state, staleDate: nil)
                for act in activities {
                    await act.update(content)
                }
            } else if active != nil {
                startLiveActivity(session: session, snap: snap)
            }
        }
    }

    private func endLiveActivity() {
        Task {
            await clearAllActivities()
        }
    }

    private func clearAllActivities() async {
        for activity in Activity<TingBeiAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled, toast == text else { return }
            toast = nil
        }
    }

    private func armClock() {
        clock?.cancel()
        clock = Task { @MainActor in
            while !Task.isCancelled, active != nil {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                tick()
            }
        }
    }

    private func applyIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = wantsScreenOn
    }

    private func persist() {
        do {
            let url = try Self.fileURL()
            var state = SavedState(settings: settings, active: active, history: history)
            state.settings.normalize()
            settings = state.settings
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: url, options: .atomic)
            if state.settings != settings {
                settings = state.settings
            }
            saveFailed = false
        } catch {
            saveFailed = true
        }
    }

    private static func load() -> SavedState {
        do {
            let url = try fileURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                return SavedState()
            }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var state = try decoder.decode(SavedState.self, from: data)
            state.settings.normalize()
            return state
        } catch {
            return SavedState()
        }
    }

    private static func fileURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("TingBei", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("state.json")
    }

    #if DEBUG
    private func installSample() {
        let plan = Plan.light
        let start = Date().addingTimeInterval(-50 * 60)
        active = Session(
            id: UUID(),
            startedAt: start,
            endedAt: nil,
            planName: plan.name,
            plannedMinutes: plan.plannedMinutes,
            softLimit: plan.softLimit,
            hardLimit: plan.hardLimit,
            minIntervalMinutes: plan.minIntervalMinutes,
            estimateWhenSilent: true,
            drinks: [
                drink("beer500", at: start.addingTimeInterval(8 * 60)),
                drink("baijiu", at: start.addingTimeInterval(28 * 60)),
            ],
            waters: [WaterLog(id: UUID(), at: start.addingTimeInterval(40 * 60))],
            prompts: [],
            lastAnnouncedRank: 2,
            lastAnnouncedCue: .settle
        )
        if var s = active {
            s.prompts = Pace.projectPrompts(s, now: .now)
            active = s
        }
    }

    private func drink(_ id: String, at: Date) -> DrinkLog {
        let preset = Pace.presets.first { $0.id == id }!
        return DrinkLog(id: UUID(), presetID: preset.id, name: preset.name, detail: preset.detail, grams: preset.grams, at: at)
    }
    #endif
}

struct SavedState: Codable {
    var settings = Settings()
    var active: Session?
    var history: [Session] = []
}
