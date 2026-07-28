import AppKit
import RunnerCore

@MainActor
final class RunnerStatusItemController: NSObject {
    let id: UUID
    private(set) var configuration: RunnerConfiguration

    private weak var manager: RunnerManager?
    private let statusItem: NSStatusItem
    private var frameIndex = 0
    private var launchAtLoginItem: NSMenuItem?
    private var openLoginItemsSettingsItem: NSMenuItem?

    init(configuration: RunnerConfiguration, manager: RunnerManager) {
        id = configuration.id
        self.configuration = configuration
        self.manager = manager
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        super.init()

        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleProportionallyDown
        updateImage()
        rebuildMenu()
    }

    func apply(_ configuration: RunnerConfiguration) {
        if configuration.runner != self.configuration.runner {
            frameIndex = 0
        }
        self.configuration = configuration
        updateImage()
        rebuildMenu()
    }

    func advanceFrame() {
        guard configuration.isRunning,
              let frames = manager?.frames(for: configuration)
        else {
            return
        }

        frameIndex = (frameIndex + 1) % frames.count
        updateImage(using: frames)
    }

    func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        for runner in RunnerKind.allCases {
            let item = NSMenuItem(
                title: runner.displayName,
                action: #selector(selectRunner(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = runner.rawValue
            item.state = configuration.runner == runner ? .on : .off
            item.isEnabled = manager?.isAvailable(runner) == true
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let mirrorItem = commandItem(
            title: "水平翻转",
            symbolName: "arrow.left.and.right",
            action: #selector(toggleMirrored)
        )
        mirrorItem.state = configuration.isMirrored ? .on : .off
        menu.addItem(mirrorItem)

        let runningItem = commandItem(
            title: configuration.isRunning ? "暂停此动画" : "继续此动画",
            symbolName: configuration.isRunning ? "pause.fill" : "play.fill",
            action: #selector(toggleRunning)
        )
        menu.addItem(runningItem)

        menu.addItem(.separator())

        let addItem = NSMenuItem(
            title: "添加动画",
            action: nil,
            keyEquivalent: ""
        )
        addItem.image = systemImage(named: "plus")
        let addMenu = NSMenu()
        for runner in RunnerKind.allCases {
            let item = NSMenuItem(
                title: "添加\(runner.displayName)",
                action: #selector(addRunner(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = runner.rawValue
            item.isEnabled = manager?.isAvailable(runner) == true
            addMenu.addItem(item)
        }
        addItem.submenu = addMenu
        menu.addItem(addItem)

        let removeItem = commandItem(
            title: "移除此动画",
            symbolName: "trash",
            action: #selector(removeRunner)
        )
        removeItem.isEnabled = manager?.canRemoveRunner == true
        menu.addItem(removeItem)

        menu.addItem(.separator())

        let launchAtLoginItem = commandItem(
            title: "开机自动启动",
            symbolName: "power",
            action: #selector(toggleLaunchAtLogin)
        )
        menu.addItem(launchAtLoginItem)
        self.launchAtLoginItem = launchAtLoginItem

        let openLoginItemsSettingsItem = commandItem(
            title: "打开登录项设置…",
            symbolName: "gearshape",
            action: #selector(openLoginItemsSettings)
        )
        menu.addItem(openLoginItemsSettingsItem)
        self.openLoginItemsSettingsItem = openLoginItemsSettingsItem
        updateLaunchAtLoginMenuItems()

        menu.addItem(.separator())

        menu.addItem(
            commandItem(
                title: "退出 TinyTroupe",
                symbolName: "xmark.circle",
                action: #selector(quitApplication)
            )
        )

        statusItem.menu = menu
    }

    func invalidate() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func updateImage(using frames: [NSImage]? = nil) {
        guard let frames = frames ?? manager?.frames(for: configuration) else {
            return
        }

        frameIndex %= frames.count
        statusItem.button?.image = frames[frameIndex]
        statusItem.button?.toolTip = toolTip
    }

    private var toolTip: String {
        let state = configuration.isRunning ? "播放中" : "已暂停"
        let direction = configuration.isMirrored ? "镜像方向" : "默认方向"
        return "\(configuration.runner.displayName)，\(state)，\(direction)"
    }

    private func commandItem(
        title: String,
        symbolName: String,
        action: Selector
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: title,
            action: action,
            keyEquivalent: ""
        )
        item.target = self
        item.image = systemImage(named: symbolName)
        return item
    }

    private func systemImage(named name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    private func updateLaunchAtLoginMenuItems() {
        guard let state = manager?.launchAtLoginState else {
            launchAtLoginItem?.isEnabled = false
            openLoginItemsSettingsItem?.isHidden = true
            return
        }

        launchAtLoginItem?.isEnabled = true
        launchAtLoginItem?.state = state.isRegistered ? .on : .off
        launchAtLoginItem?.title = state.requiresApproval
            ? "开机自动启动（等待系统允许）"
            : "开机自动启动"
        openLoginItemsSettingsItem?.isHidden = !state.requiresApproval
    }

    @objc
    private func selectRunner(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let runner = RunnerKind(rawValue: rawValue)
        else {
            return
        }
        manager?.selectRunner(id: id, runner: runner)
    }

    @objc
    private func toggleMirrored() {
        manager?.toggleMirrored(id: id)
    }

    @objc
    private func toggleRunning() {
        manager?.toggleRunning(id: id)
    }

    @objc
    private func toggleLaunchAtLogin() {
        manager?.toggleLaunchAtLogin()
    }

    @objc
    private func openLoginItemsSettings() {
        manager?.openLoginItemsSettings()
    }

    @objc
    private func addRunner(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let runner = RunnerKind(rawValue: rawValue)
        else {
            return
        }
        manager?.addRunner(runner)
    }

    @objc
    private func removeRunner() {
        manager?.removeRunner(id: id)
    }

    @objc
    private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
}

extension RunnerStatusItemController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updateLaunchAtLoginMenuItems()
    }
}
