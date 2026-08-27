import AppKit
import RunnerCore

@MainActor
final class RunnerStatusItemController: NSObject {
    let id: UUID
    private(set) var configuration: RunnerConfiguration

    private weak var manager: RunnerManager?
    private let statusItem: NSStatusItem
    private var spriteWindows: [NSNumber: NSWindow] = [:]
    private var spriteViews: [NSNumber: RunnerSpriteView] = [:]
    private weak var observedStatusWindow: NSWindow?
    private var currentImage: NSImage?
    private var stableRightInset: CGFloat?
    private var stableTopInset: CGFloat?
    private var spaceRefreshWorkItem: DispatchWorkItem?
    private var spaceRefreshGeneration = 0
    private var suppressVisibilityRefresh = false
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

        configureSpriteView()
        updateImage()
        updateToolTip()
        rebuildMenu()

        DispatchQueue.main.async { [weak self] in
            self?.updateSpriteWindowFrames()
        }
    }

    func apply(_ configuration: RunnerConfiguration) {
        if configuration.runner != self.configuration.runner {
            frameIndex = 0
        }
        self.configuration = configuration
        updateStatusItemLength()
        updateImage()
        updateToolTip()
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
        spaceRefreshWorkItem?.cancel()
        spaceRefreshWorkItem = nil
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        for window in spriteWindows.values {
            window.orderOut(nil)
        }
        spriteWindows.removeAll()
        spriteViews.removeAll()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func updateImage(using frames: [NSImage]? = nil) {
        guard let frames = frames ?? manager?.frames(for: configuration) else {
            return
        }

        frameIndex %= frames.count
        let image = frames[frameIndex]
        currentImage = image
        for spriteView in spriteViews.values {
            spriteView.display(image)
        }
    }

    private func updateToolTip() {
        statusItem.button?.toolTip = toolTip
    }

    private func configureSpriteView() {
        guard let button = statusItem.button else {
            return
        }

        updateStatusItemLength()
        button.image = nil
        button.imagePosition = .noImage
        button.title = ""

        button.postsFrameChangedNotifications = true
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(sourceGeometryDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: button
        )
        center.addObserver(
            self,
            selector: #selector(sourceGeometryDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(sourceGeometryDidChange(_:)),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    private func updateStatusItemLength() {
        let imageWidth = manager?.frames(for: configuration)
            .map(\.size.width)
            .max() ?? NSStatusItem.squareLength
        statusItem.length = max(NSStatusItem.squareLength, imageWidth + 4)

        DispatchQueue.main.async { [weak self] in
            self?.updateSpriteWindowFrames()
        }
    }

    @objc
    private func sourceGeometryDidChange(_ notification: Notification) {
        if notification.name == NSWorkspace.activeSpaceDidChangeNotification {
            suppressVisibilityRefresh = true
            updateSpriteWindowFrames(updateVisibility: false)
            scheduleSpaceRefresh()
            return
        }

        updateSpriteWindowFrames(updateVisibility: !suppressVisibilityRefresh)
    }

    private func scheduleSpaceRefresh() {
        spaceRefreshWorkItem?.cancel()
        spaceRefreshGeneration += 1
        let generation = spaceRefreshGeneration
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.spaceRefreshGeneration == generation
            else {
                return
            }
            self.suppressVisibilityRefresh = false
            self.updateSpriteWindowFrames()
        }
        spaceRefreshWorkItem = workItem
        // Window Server visibility can lag the active-Space notification.
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.25,
            execute: workItem
        )
    }

    private func updateSpriteWindowFrames(updateVisibility: Bool = true) {
        guard let button = statusItem.button,
              let statusWindow = button.window
        else {
            return
        }

        observeStatusWindowIfNeeded(statusWindow)
        let frameInWindow = button.convert(button.bounds, to: nil)
        let sourceFrame = statusWindow.convertToScreen(frameInWindow)
        if let sourceScreen = NSScreen.screens.first(where: {
            $0.frame.contains(sourceFrame)
        }) ?? statusWindow.screen,
           sourceScreen.frame.contains(sourceFrame) {
            let rightInset = sourceScreen.frame.maxX - sourceFrame.maxX
            let topInset = sourceScreen.frame.maxY - sourceFrame.maxY
            let maximumTopInset = NSStatusBar.system.thickness

            if rightInset >= 0,
               topInset >= 0,
               topInset <= maximumTopInset {
                stableRightInset = rightInset
                stableTopInset = topInset
            }
        }

        guard let rightInset = stableRightInset,
              let topInset = stableTopInset
        else {
            return
        }
        let visibleMenuBarScreens = updateVisibility
            ? visibleMenuBarScreenNumbers()
            : nil
        var activeScreenNumbers = Set<NSNumber>()

        for screen in NSScreen.screens {
            guard let screenNumber = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? NSNumber else {
                continue
            }

            activeScreenNumbers.insert(screenNumber)
            let targetFrame = NSRect(
                x: screen.frame.maxX - rightInset - sourceFrame.width,
                y: screen.frame.maxY - topInset - sourceFrame.height,
                width: sourceFrame.width,
                height: sourceFrame.height
            )
            let (window, spriteView) = spriteWindow(
                for: screenNumber,
                appearance: button.effectiveAppearance
            )

            window.setFrame(targetFrame, display: false)
            if let currentImage {
                spriteView.display(currentImage)
            }
            if visibleMenuBarScreens?.contains(screenNumber) == true,
               !window.isVisible {
                window.orderFrontRegardless()
            } else if visibleMenuBarScreens?.contains(screenNumber) == false,
                      window.isOnActiveSpace,
                      window.isVisible {
                window.orderOut(nil)
            }
        }

        let removedScreenNumbers = Set(spriteWindows.keys)
            .subtracting(activeScreenNumbers)
        for screenNumber in removedScreenNumbers {
            spriteWindows.removeValue(forKey: screenNumber)?.orderOut(nil)
            spriteViews.removeValue(forKey: screenNumber)
        }
    }

    private func spriteWindow(
        for screenNumber: NSNumber,
        appearance: NSAppearance
    ) -> (NSWindow, RunnerSpriteView) {
        if let window = spriteWindows[screenNumber],
           let spriteView = spriteViews[screenNumber] {
            window.appearance = appearance
            return (window, spriteView)
        }

        let spriteView = RunnerSpriteView(frame: .zero)
        spriteView.autoresizingMask = [.width, .height]
        let window = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.appearance = appearance
        window.backgroundColor = .clear
        // Transient windows move with their Space instead of lingering over it.
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .ignoresCycle,
            .transient,
        ]
        window.contentView = spriteView
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.isReleasedWhenClosed = false
        window.level = NSWindow.Level(
            rawValue: NSWindow.Level.statusBar.rawValue + 1
        )

        spriteWindows[screenNumber] = window
        spriteViews[screenNumber] = spriteView
        return (window, spriteView)
    }

    private func visibleMenuBarScreenNumbers() -> Set<NSNumber> {
        guard let windowList = CGWindowListCopyWindowInfo(
            .optionOnScreenOnly,
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        let menuBarFrames = windowList.compactMap { window -> CGRect? in
            guard window[kCGWindowLayer as String] as? Int
                    == NSWindow.Level.mainMenu.rawValue,
                  let bounds = window[kCGWindowBounds as String]
            else {
                return nil
            }

            return CGRect(dictionaryRepresentation: bounds as! CFDictionary)
        }

        return Set(NSScreen.screens.compactMap { screen -> NSNumber? in
            guard let screenNumber = screenNumber(for: screen) else {
                return nil
            }

            let displayBounds = CGDisplayBounds(
                CGDirectDisplayID(screenNumber.uint32Value)
            )
            let hasVisibleMenuBar = menuBarFrames.contains { menuBarFrame in
                abs(menuBarFrame.minX - displayBounds.minX) < 1
                    && abs(menuBarFrame.minY - displayBounds.minY) < 1
                    && abs(menuBarFrame.width - displayBounds.width) < 1
                    && menuBarFrame.height <= 64
            }
            return hasVisibleMenuBar ? screenNumber : nil
        })
    }

    private func screenNumber(for screen: NSScreen) -> NSNumber? {
        screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber
    }

    private func observeStatusWindowIfNeeded(_ statusWindow: NSWindow) {
        guard observedStatusWindow !== statusWindow else {
            return
        }

        let center = NotificationCenter.default
        if let observedStatusWindow {
            center.removeObserver(
                self,
                name: NSWindow.didMoveNotification,
                object: observedStatusWindow
            )
            center.removeObserver(
                self,
                name: NSWindow.didResizeNotification,
                object: observedStatusWindow
            )
            center.removeObserver(
                self,
                name: NSWindow.didChangeScreenNotification,
                object: observedStatusWindow
            )
        }

        observedStatusWindow = statusWindow
        center.addObserver(
            self,
            selector: #selector(sourceGeometryDidChange(_:)),
            name: NSWindow.didMoveNotification,
            object: statusWindow
        )
        center.addObserver(
            self,
            selector: #selector(sourceGeometryDidChange(_:)),
            name: NSWindow.didResizeNotification,
            object: statusWindow
        )
        center.addObserver(
            self,
            selector: #selector(sourceGeometryDidChange(_:)),
            name: NSWindow.didChangeScreenNotification,
            object: statusWindow
        )
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

@MainActor
private final class RunnerSpriteView: NSView {
    private let tintLayer = CALayer()
    private let maskLayer = CALayer()
    private var spriteSize = NSSize.zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layerContentsRedrawPolicy = .never
        maskLayer.magnificationFilter = .nearest
        maskLayer.minificationFilter = .nearest
        maskLayer.contentsGravity = .resize
        tintLayer.mask = maskLayer
        layer?.addSublayer(tintLayer)
        updateTintColor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func display(_ image: NSImage) {
        guard let representation = image.representations
            .compactMap({ $0 as? NSBitmapImageRep })
            .first,
              let contents = representation.cgImage
        else {
            return
        }

        spriteSize = image.size
        updateLayerFrames()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.contents = contents
        maskLayer.contentsScale = max(
            CGFloat(contents.width) / max(image.size.width, 1),
            CGFloat(contents.height) / max(image.size.height, 1)
        )
        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        updateLayerFrames()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateTintColor()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func updateLayerFrames() {
        let size = NSSize(
            width: min(spriteSize.width, bounds.width),
            height: min(spriteSize.height, bounds.height)
        )
        let frame = NSRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        ).integral

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tintLayer.frame = frame
        maskLayer.frame = tintLayer.bounds
        CATransaction.commit()
    }

    private func updateTintColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            tintLayer.backgroundColor = NSColor.labelColor.cgColor
            CATransaction.commit()
        }
    }
}

extension RunnerStatusItemController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updateLaunchAtLoginMenuItems()
    }
}
