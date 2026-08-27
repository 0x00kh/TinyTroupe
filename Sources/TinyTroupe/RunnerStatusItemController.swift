import AppKit
import RunnerCore

@MainActor
final class RunnerStatusItemController: NSObject {
    let id: UUID
    private(set) var configuration: RunnerConfiguration

    private weak var manager: RunnerManager?
    private let statusItem: NSStatusItem
    private let imageView: RunnerStatusItemView
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
        imageView = RunnerStatusItemView(frame: .zero)
        super.init()

        configureStatusItemButton()
        updateImage()
        updateToolTip()
        rebuildMenu()
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
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func updateImage(using frames: [NSImage]? = nil) {
        guard let frames = frames ?? manager?.frames(for: configuration) else {
            return
        }

        frameIndex %= frames.count
        imageView.display(frames[frameIndex])
    }

    private func updateToolTip() {
        statusItem.button?.toolTip = toolTip
    }

    private func configureStatusItemButton() {
        guard let button = statusItem.button else {
            return
        }

        updateStatusItemLength()
        button.image = nil
        button.imagePosition = .noImage
        button.title = ""

        imageView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: button.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])
    }

    private func updateStatusItemLength() {
        let imageWidth = manager?.frames(for: configuration)
            .map(\.size.width)
            .max() ?? NSStatusItem.squareLength
        statusItem.length = max(NSStatusItem.squareLength, imageWidth + 4)
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
private final class RunnerStatusItemView: NSView {
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

        // Update the mask directly so AppKit does not rasterize the status item image each frame.
        if spriteSize != image.size {
            spriteSize = image.size
            updateLayerFrames()
        }

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
