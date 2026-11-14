import AppIntents

// MARK: - 锁屏卡片与灵动岛后台直连 Intent（App 与小组件共享）

struct LogDrinkLiveIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "记 1 份饮酒" }
    static var description: IntentDescription { "记录当前酒种 1 份默认规格，无需打开停杯" }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let store = await MainActor.run { SessionStore.shared }
        _ = await store.logDrinkFromIntent()
        #endif
        return .result()
    }
}

struct LogWaterLiveIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "喝了一杯水" }
    static var description: IntentDescription { "记录喝了一杯水并折抵急饮冷却，无需打开停杯" }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let store = await MainActor.run { SessionStore.shared }
        _ = await store.logWaterFromIntent()
        #endif
        return .result()
    }
}

struct EndSessionLiveIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "我收杯了" }
    static var description: IntentDescription { "结束本场酒局并生成复盘记录" }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let store = await MainActor.run { SessionStore.shared }
        _ = await store.endSessionFromIntent()
        #endif
        return .result()
    }
}

#if !WIDGET_EXTENSION
// MARK: - Siri、控制中心与 Apple Watch 快捷指令

struct ShortcutLogDrinkIntent: AppIntent {
    static var title: LocalizedStringResource { "记一杯" }
    static var description: IntentDescription { "在当前酒场记录 1 份默认规格的酒饮" }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = await MainActor.run { SessionStore.shared }
        let reply = await store.logDrinkFromIntent()
        return .result(dialog: IntentDialog(stringLiteral: reply))
    }
}

struct ShortcutLogWaterIntent: AppIntent {
    static var title: LocalizedStringResource { "记喝水" }
    static var description: IntentDescription { "记录喝了一杯水，平衡水酒比例并折抵急饮冷却" }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = await MainActor.run { SessionStore.shared }
        let reply = await store.logWaterFromIntent()
        return .result(dialog: IntentDialog(stringLiteral: reply))
    }
}

struct ShortcutCheckPaceIntent: AppIntent {
    static var title: LocalizedStringResource { "查看本场节拍" }
    static var description: IntentDescription { "查看当前累计酒量、建议线与节奏状态" }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let reply = await MainActor.run { SessionStore.shared.statusSummaryForIntent() }
        return .result(dialog: IntentDialog(stringLiteral: reply))
    }
}

struct ShortcutEndSessionIntent: AppIntent {
    static var title: LocalizedStringResource { "收杯结席" }
    static var description: IntentDescription { "结束当前酒场并归档至席间手账" }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = await MainActor.run { SessionStore.shared }
        let reply = await store.endSessionFromIntent()
        return .result(dialog: IntentDialog(stringLiteral: reply))
    }
}

struct TingBeiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShortcutLogDrinkIntent(),
            phrases: [
                "用\(.applicationName)记一杯",
                "在\(.applicationName)记录喝了一杯"
            ],
            shortTitle: "记一杯",
            systemImageName: "wineglass.fill"
        )
        AppShortcut(
            intent: ShortcutLogWaterIntent(),
            phrases: [
                "用\(.applicationName)喝水",
                "在\(.applicationName)记一杯水"
            ],
            shortTitle: "记喝水",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: ShortcutCheckPaceIntent(),
            phrases: [
                "用\(.applicationName)看进度",
                "\(.applicationName)现在喝了多少"
            ],
            shortTitle: "看节拍",
            systemImageName: "gauge.with.needle"
        )
        AppShortcut(
            intent: ShortcutEndSessionIntent(),
            phrases: [
                "用\(.applicationName)收杯",
                "在\(.applicationName)结束酒局"
            ],
            shortTitle: "收杯结席",
            systemImageName: "checkmark.seal.fill"
        )
    }
}
#endif
