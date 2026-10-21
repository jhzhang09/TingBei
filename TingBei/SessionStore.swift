import Foundation
import UIKit
@preconcurrency import UserNotifications

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
        if active != nil {
            reschedule()
            armClock()
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
            plannedMinutes: plan.plannedMinutes,
            softLimit: plan.softLimit,
            hardLimit: plan.hardLimit,
            minIntervalMinutes: plan.minIntervalMinutes,
            drinks: [],
            waters: [],
            lastAnnouncedRank: 0,
            lastAnnouncedCue: nil
        )
        let initialSnap = Pace.evaluate(session, now: initialNow)
        session.lastAnnouncedRank = initialSnap.rank
        session.lastAnnouncedCue = initialSnap.cue
        active = session
        now = initialNow
        bannerPulse += 1
        persist()
        applyIdleTimer()
        armClock()
        Task {
            await requestNotificationsThenSchedule()
        }
        triggerHaptic(.tap)
    }

    func log(_ preset: DrinkPreset) {
        guard var session = active else { return }
        let before = Pace.evaluate(session, now: .now)
        session.drinks.append(
            DrinkLog(
                id: UUID(),
                presetID: preset.id,
                name: preset.name,
                detail: preset.detail,
                grams: preset.grams,
                at: .now
            )
        )
        let after = Pace.evaluate(session, now: .now)
        session.lastAnnouncedRank = after.rank
        session.lastAnnouncedCue = after.cue
        active = session
        now = .now
        bannerPulse += 1
        toast = nil
        persist()
        reschedule()

        if after.cue == .over {
            triggerHaptic(.stop)
        } else if after.rank > before.rank || after.cue == .hurried {
            triggerHaptic(.warning)
        } else {
            triggerHaptic(.tap)
        }
    }

    func logCustom(name: String, volumeMl: Double, abv: Double) {
        let preset = DrinkPreset.custom(name: name, volumeMl: volumeMl, abv: abv)
        log(preset)
    }

    func logWater() {
        guard var session = active else { return }
        session.waters.append(WaterLog(id: UUID(), at: .now))
        active = session
        persist()
        showToast("水记下了。先把这杯喝完。")
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
            session.drinks.removeAll { $0.id == drink?.id }
        default:
            return
        }
        let after = Pace.evaluate(session, now: .now)
        session.lastAnnouncedRank = after.rank
        session.lastAnnouncedCue = after.cue
        active = session
        now = .now
        bannerPulse += 1
        persist()
        reschedule()
        triggerHaptic(.soft)
    }

    func end() {
        guard var session = active else { return }
        let end = Date()
        session.endedAt = end
        let finalSnap = Pace.evaluate(session, now: end)
        session.lastAnnouncedRank = finalSnap.rank
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

        let rankEscalated = snap.rank > previousRank
        let cueChanged = snap.cue != previousCue
        let enteredCriticalCue = cueChanged && (snap.cue == .hurried || snap.cue == .due || snap.cue == .over)

        if rankEscalated || enteredCriticalCue {
            session.lastAnnouncedRank = snap.rank
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
            session.lastAnnouncedRank = snap.rank
            session.lastAnnouncedCue = snap.cue
            active = session
            persist()
        }
    }

    func reschedule() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard let session = active, session.endedAt == nil else { return }
        let cues = Pace.plannedCues(session: session, now: .now).prefix(20)
        for cue in cues {
            let content = UNMutableNotificationContent()
            content.title = cue.title
            content.body = cue.body
            content.sound = .default
            content.threadIdentifier = "tingbei.session"
            let parts = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: cue.at
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            let request = UNNotificationRequest(identifier: "tingbei." + cue.id, content: content, trigger: trigger)
            center.add(request)
        }
    }

    func requestNotificationsThenSchedule() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
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
            plannedMinutes: plan.plannedMinutes,
            softLimit: plan.softLimit,
            hardLimit: plan.hardLimit,
            minIntervalMinutes: plan.minIntervalMinutes,
            drinks: [
                drink("beer500", at: start.addingTimeInterval(8 * 60)),
                drink("baijiu", at: start.addingTimeInterval(28 * 60)),
            ],
            waters: [WaterLog(id: UUID(), at: start.addingTimeInterval(40 * 60))],
            lastAnnouncedRank: 4,
            lastAnnouncedCue: .near
        )
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
