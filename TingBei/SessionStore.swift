import Foundation
import UIKit
import ActivityKit
import AudioToolbox
import AVFoundation
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
    var hoursRemaining: Int?
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
            let hrs = max(1, hoursRemaining ?? 1)
            return "签名将于 \(hrs) 小时后到期"
        } else {
            return "签名剩余 \(days) 天 · 自动续签保护中"
        }
    }

    static func current() -> SignatureStatus {
        #if targetEnvironment(simulator)
        return SignatureStatus(daysRemaining: nil, hoursRemaining: nil, expirationDate: nil, isSimulator: true)
        #else
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let rawString = String(data: data, encoding: .ascii) ?? String(data: data, encoding: .isoLatin1) else {
            return SignatureStatus(daysRemaining: nil, hoursRemaining: nil, expirationDate: nil, isSimulator: false)
        }

        guard let xmlStart = rawString.range(of: "<?xml"),
              let xmlEnd = rawString.range(of: "</plist>", range: xmlStart.lowerBound..<rawString.endIndex) else {
            return SignatureStatus(daysRemaining: nil, hoursRemaining: nil, expirationDate: nil, isSimulator: false)
        }

        let xmlSubstring = rawString[xmlStart.lowerBound..<xmlEnd.upperBound]
        guard let xmlData = xmlSubstring.data(using: .utf8),
              let plist = (try? PropertyListSerialization.propertyList(from: xmlData, options: [], format: nil)) as? [String: Any],
              let expirationDate = plist["ExpirationDate"] as? Date else {
            return SignatureStatus(daysRemaining: nil, hoursRemaining: nil, expirationDate: nil, isSimulator: false)
        }

        let remainingSeconds = expirationDate.timeIntervalSince(.now)
        if remainingSeconds <= 0 {
            return SignatureStatus(daysRemaining: -1, hoursRemaining: 0, expirationDate: expirationDate, isSimulator: false)
        }
        let totalHours = Int(ceil(remainingSeconds / 3600.0))
        let days = Int(ceil(remainingSeconds / 86400.0))
        return SignatureStatus(daysRemaining: days, hoursRemaining: totalHours, expirationDate: expirationDate, isSimulator: false)
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
    var confirmingEndFromDeepLink = false

    private var clock: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var rescheduleTask: Task<Void, Never>?
    @ObservationIgnored private var liveActivityTask: Task<Void, Never>?
    @ObservationIgnored private var audioPlayer: AVAudioPlayer?
    @ObservationIgnored private var lastLiveActivityState: TingBeiAttributes.ContentState?

    init() {
        let saved = Self.load()
        settings = saved.settings
        active = saved.active
        history = saved.history
        Theme.apply(saved.settings.selectedTheme)
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
        Theme.apply(settings.selectedTheme)
        persist()
        applyIdleTimer()
    }

    func selectTheme(_ theme: AppTheme) {
        guard settings.selectedTheme != theme else { return }
        settings.selectedTheme = theme
        Theme.apply(theme)
        normalizeAndSaveSettings()
        if let session = active {
            updateLiveActivity(session: session, snap: Pace.evaluate(session, now: now), force: true)
        }
        showToast("已切换主题：\(theme.name) · \(theme.subtitle)")
        triggerHaptic(.soft)
    }

    func previewSound(_ option: NotificationSoundOption) {
        triggerHaptic(.soft)
        guard let fileName = option.fileName else {
            AudioServicesPlaySystemSound(1007) // 系统默认短促提示
            return
        }
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        guard let soundURL = Bundle.main.url(forResource: name, withExtension: ext) else {
            AudioServicesPlaySystemSound(1007)
            return
        }
        do {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            AudioServicesPlaySystemSound(1007)
        }
    }

    func start(_ plan: Plan, category: BeverageCategory? = nil) {
        var plan = plan
        if plan.hardLimit < plan.softLimit {
            plan.hardLimit = plan.softLimit
        }
        let chosenCategory = category ?? settings.selectedBeverageCategory
        let initialNow = Date.now
        var session = Session(
            id: UUID(),
            startedAt: initialNow,
            endedAt: nil,
            planName: plan.name,
            beverageCategory: chosenCategory,
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

    /// 切换当前酒场的酒种
    func switchBeverageCategory(_ cat: BeverageCategory) {
        guard var session = active else { return }
        session.beverageCategory = cat
        updatePrompts(&session, now: .now)
        active = session
        let snap = Pace.evaluate(session, now: .now)
        persist()
        reschedule()
        updateLiveActivity(session: session, snap: snap)
        showToast("已切换为主要饮用：\(cat.name)，按 \(cat.unitName) 计量")
        triggerHaptic(.soft)
    }

    func defaultPresetForCurrentSession() -> DrinkPreset {
        guard let session = active else { return Pace.genericDrink }
        switch session.beverageCategory {
        case .beer:
            return Pace.presets.first(where: { $0.id == "beer500" }) ?? Pace.genericDrink
        case .baijiu:
            return Pace.presets.first(where: { $0.id == "baijiu" }) ?? Pace.genericDrink
        case .wine:
            return Pace.presets.first(where: { $0.id == "wine" }) ?? Pace.genericDrink
        case .custom:
            return Pace.genericDrink
        }
    }

    /// 用户在界面或通知上确认：喝了一份。若未指定则自动按当前酒种默认规格记录。
    func logDrink(preset: DrinkPreset? = nil, at customDate: Date? = nil) {
        guard var session = active else { return }
        let chosenPreset = preset ?? defaultPresetForCurrentSession()
        let logTime = customDate ?? .now
        let before = Pace.evaluate(session, now: .now)

        let newDrinkID = UUID()
        session.drinks.append(
            DrinkLog(
                id: newDrinkID,
                presetID: chosenPreset.id,
                name: chosenPreset.name,
                detail: chosenPreset.detail,
                grams: chosenPreset.grams,
                at: logTime
            )
        )

        // 仅将最接近当前记录时间的一条未回复提醒标记为已确认（避免一次性吞掉多条历史推测提醒）
        if let matchIdx = session.prompts.indices
            .filter({ session.prompts[$0].reply == nil && session.prompts[$0].at <= logTime.addingTimeInterval(5 * 60) })
            .max(by: { session.prompts[$0].at < session.prompts[$1].at }) {
            session.prompts[matchIdx].reply = .logged
            session.prompts[matchIdx].drinkID = newDrinkID
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
        updateLiveActivity(session: session, snap: after, force: true)
        showToast("已记录：\(chosenPreset.name)（\(chosenPreset.detail)）")

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

    /// 用户回应某次主动提醒："喝了一份" 或 "这段时间没喝"
    func handlePromptReply(promptID: UUID, reply: PromptReply) {
        guard var session = active else { return }
        guard let idx = session.prompts.firstIndex(where: { $0.id == promptID }) else { return }

        session.prompts[idx].reply = reply
        if reply == .drank {
            let defaultPreset = defaultPresetForCurrentSession()
            let drinkID = UUID()
            session.drinks.append(
                DrinkLog(
                    id: drinkID,
                    presetID: defaultPreset.id,
                    name: defaultPreset.name,
                    detail: defaultPreset.detail,
                    grams: defaultPreset.grams,
                    at: session.prompts[idx].at
                )
            )
            session.prompts[idx].drinkID = drinkID
            showToast("已确认：\(defaultPreset.name)")
        } else if reply == .skipped {
            showToast("已消除本轮推测，节拍已校准")
        }

        updatePrompts(&session, now: .now)
        active = session
        now = .now
        bannerPulse += 1
        persist()
        reschedule()
        updateLiveActivity(session: session, snap: Pace.evaluate(session, now: .now), force: true)
        triggerHaptic(.soft)
    }

    func logWater() {
        guard var session = active else { return }
        let before = Pace.evaluate(session, now: .now)
        session.waters.append(WaterLog(id: UUID(), at: .now))
        active = session
        let after = Pace.evaluate(session, now: .now)
        persist()
        if before.isTooFast && !after.isTooFast {
            showToast("💧 已喝水缓冲，急饮警示已解除")
        } else if before.isTooFast {
            showToast("💧 已折抵 5 分钟急饮冷却，请继续慢饮")
        } else {
            showToast("💧 喝了一杯水，水酒平衡 \(after.waterCount):\(max(1, after.drinkCount))")
        }
        updateLiveActivity(session: session, snap: after, force: true)
        triggerHaptic(.soft)
    }

    func undoLast() {
        guard var session = active else { return }
        let drink = session.drinks.max(by: { $0.at < $1.at })
        let water = session.waters.max(by: { $0.at < $1.at })
        switch (drink?.at, water?.at) {
        case let (drinkAt?, waterAt?) where waterAt > drinkAt:
            session.waters.removeAll { $0.id == water?.id }
            showToast("已撤销上一条喝水记录")
        case (nil, _?):
            session.waters.removeAll { $0.id == water?.id }
            showToast("已撤销上一条喝水记录")
        case (_?, _):
            if let drinkID = drink?.id {
                session.drinks.removeAll { $0.id == drinkID }
                for i in 0..<session.prompts.count where session.prompts[i].drinkID == drinkID {
                    session.prompts[i].reply = nil
                    session.prompts[i].drinkID = nil
                }
                showToast("已撤销上一份饮酒记录")
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
        updateLiveActivity(session: session, snap: after, force: true)
        triggerHaptic(.soft)
    }

    func handleDeepLinkEnd() {
        guard let snap = snapshot else { return }
        if snap.intensity >= .due {
            end()
        } else {
            confirmingEndFromDeepLink = true
            triggerHaptic(.warning)
        }
    }

    func end() {
        guard var session = active else { return }
        let end = Date()
        session.endedAt = end
        confirmingEndFromDeepLink = false

        // 结束时若完全没有确认饮酒且短于 5 分钟，直接静默丢弃
        if session.drinks.isEmpty && session.waters.isEmpty && session.duration < 5 * 60 {
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
        history.removeAll { $0.isEmptyRecord }
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

        // 越线后若未来的排期通知剩余不多，自动滚动补充未来排期
        let upcomingCount = session.prompts.filter { $0.at > now }.count
        if snap.intensity == .over && upcomingCount < 15 {
            updatePrompts(&session, now: now)
            reschedule()
        }

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
            if previousCue == .hurried && snap.cue == .settle {
                triggerHaptic(.soft)
            }
        }

        updateLiveActivity(session: session, snap: snap)
    }

    private func updatePrompts(_ session: inout Session, now: Date) {
        let past = session.prompts.filter { $0.at <= now }
        let future = Pace.projectPrompts(session, now: now)
        session.prompts = past + future
    }

    func reschedule() {
        let center = UNUserNotificationCenter.current()
        let previous = rescheduleTask
        previous?.cancel()
        rescheduleTask = Task {
            // 串行化：等上一轮彻底结束再读取待发列表。否则旧任务在本轮读取之后才 add 的过期提醒
            // 不在本轮删除名单里，会变成无人清理的孤儿通知。
            await previous?.value
            guard !Task.isCancelled else { return }
            let pending = await center.pendingNotificationRequests()
            let sessionIDs = pending.map(\.identifier).filter { !$0.hasPrefix("tingbei.test.") }
            if !sessionIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: sessionIDs)
            }
            guard let session = active, session.endedAt == nil else { return }

            let currentNow = Date.now
            let upcoming = session.prompts.filter { $0.at > currentNow.addingTimeInterval(1) }.sorted(by: { $0.at < $1.at })
            var overCounter = 0

            for prompt in upcoming.prefix(Pace.promptBudget) {
                // 已被新一轮取代时停止补加；残留部分由下一轮读取待发列表后统一删除
                if Task.isCancelled { return }
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

                // 突破静音/专注模式的强提醒级别
                content.interruptionLevel = .timeSensitive

                // 配置声音
                if let soundFile = settings.notificationSound.fileName {
                    content.sound = UNNotificationSound(named: UNNotificationSoundName(soundFile))
                } else {
                    content.sound = .default
                }

                let interval = max(1.0, prompt.at.timeIntervalSince(currentNow))
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                let request = UNNotificationRequest(identifier: "tingbei." + prompt.id.uuidString, content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }

    /// 发送一条 5 秒后的测试通知，方便在锁屏下验证通知能否正常弹窗并响铃
    func scheduleTestNotification() {
        Task {
            let center = UNUserNotificationCenter.current()
            let authSettings = await center.notificationSettings()
            if authSettings.authorizationStatus == .notDetermined {
                let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                notificationPermission = granted ? .allowed : .denied
                if !granted {
                    showToast("请先开启通知权限，才能接收测试提醒")
                    return
                }
            } else if authSettings.authorizationStatus == .denied {
                notificationPermission = .denied
                showToast("通知权限已关闭，请前往系统设置开启")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "停杯 · 声音与通知测试"
            content.body = "恭喜！当前通知与【\(settings.notificationSound.displayName)】提示音已正常送达。"
            content.categoryIdentifier = NotificationActionID.category
            content.interruptionLevel = .timeSensitive

            if let soundFile = settings.notificationSound.fileName {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(soundFile))
            } else {
                content.sound = .default
            }

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5.0, repeats: false)
            let request = UNNotificationRequest(identifier: "tingbei.test." + UUID().uuidString, content: content, trigger: trigger)
            try? await center.add(request)
            showToast("已排期测试通知！请立即锁屏，5 秒后听音看弹窗")
            triggerHaptic(.tap)
        }
    }

    func registerNotificationCategories() {
        let drankAction = UNNotificationAction(
            identifier: NotificationActionID.drank,
            title: "喝了一份",
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

    /// 处理通知按钮。锁屏点按时 App 只在后台被短暂唤醒，回调返回后进程可能立即被挂起，
    /// 因此须等重新排期写入通知中心、实时活动更新送达后再返回，否则会残留过期提醒、锁屏卡片停在旧数值。
    func handleNotificationAction(actionIdentifier: String, promptIDString: String?) async {
        switch actionIdentifier {
        case NotificationActionID.stop:
            end()
        case NotificationActionID.drank, NotificationActionID.skipped:
            guard let promptIDString, let promptID = UUID(uuidString: promptIDString) else { return }
            handlePromptReply(promptID: promptID, reply: actionIdentifier == NotificationActionID.drank ? .drank : .skipped)
        default:
            return
        }
        await rescheduleTask?.value
        await liveActivityTask?.value
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
        // 进行中的重新排期可能仍在补加提醒；追加一轮串行清理（此时 active 已为 nil，只删不加）
        reschedule()
    }

    // MARK: - Live Activity & 灵动岛管理

    private func makeLiveActivityState(session: Session, snap: PaceSnapshot) -> TingBeiAttributes.ContentState {
        let overCount = snap.intensity == .over ? session.prompts.filter { $0.level == .over && $0.at <= now }.count : nil
        let softPhysical = session.beverageCategory.formatPhysical(from: session.softLimit)
        // 按分钟粒度对齐 elapsedSeconds，避免每秒无意义触发 ActivityKit 跨进程 IPC 刷新
        let roundedElapsed = Double(Int(snap.elapsed) / 60 * 60)
        return TingBeiAttributes.ContentState(
            units: (snap.units * 100).rounded() / 100,
            confirmedUnits: (snap.confirmedUnits * 100).rounded() / 100,
            estimatedUnits: (snap.estimatedUnits * 100).rounded() / 100,
            softLimit: session.softLimit,
            hardLimit: session.hardLimit,
            cue: snap.cue.rawValue,
            title: snap.title,
            message: snap.message,
            nextPromptAt: snap.nextPrompt?.at,
            elapsedSeconds: roundedElapsed,
            isOver: snap.cue == .over || snap.cue == .due,
            physicalText: snap.physicalText,
            physicalSoftLimitText: softPhysical,
            overCount: overCount,
            themeID: settings.selectedTheme.rawValue
        )
    }

    private func startLiveActivity(session: Session, snap: PaceSnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = makeLiveActivityState(session: session, snap: snap)
        lastLiveActivityState = state
        let staleDate = snap.nextPrompt?.at

        enqueueLiveActivity {
            await self.requestLiveActivity(session: session, state: state, staleDate: staleDate)
        }
    }

    private func requestLiveActivity(session: Session, state: TingBeiAttributes.ContentState, staleDate: Date?) async {
        await clearAllActivities()
        let attributes = TingBeiAttributes(startedAt: session.startedAt, planName: session.planName)
        _ = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: staleDate),
            pushType: nil
        )
    }

    /// 串行执行实时活动的启动 / 更新 / 结束，并保留最后一个任务句柄：
    /// 一是避免并发的 end 与 request 交错；二是后台处理通知按钮时可等待其完成，
    /// 否则进程被挂起后锁屏卡片会停留在旧数值。
    private func enqueueLiveActivity(_ operation: @escaping @MainActor () async -> Void) {
        let previous = liveActivityTask
        liveActivityTask = Task {
            await previous?.value
            await operation()
        }
    }

    private func updateLiveActivity(session: Session, snap: PaceSnapshot, force: Bool = false) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = makeLiveActivityState(session: session, snap: snap)
        if !force, state == lastLiveActivityState, !Activity<TingBeiAttributes>.activities.isEmpty {
            return
        }
        lastLiveActivityState = state
        let staleDate = snap.nextPrompt?.at

        enqueueLiveActivity {
            let activities = Activity<TingBeiAttributes>.activities
            if !activities.isEmpty {
                let content = ActivityContent(state: state, staleDate: staleDate)
                for act in activities {
                    await act.update(content)
                }
            } else if self.active != nil {
                // 直接在本任务内重建，而不是再排一个任务，保证等待者等到的是完整结果
                await self.requestLiveActivity(session: session, state: state, staleDate: staleDate)
            }
        }
    }

    private func endLiveActivity() {
        lastLiveActivityState = nil
        enqueueLiveActivity {
            await self.clearAllActivities()
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
                try? await Task.sleep(for: .seconds(5))
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
            beverageCategory: .beer,
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
