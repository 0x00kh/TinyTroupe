import AppKit
import RunnerCore
import ServiceManagement

@MainActor
final class RunnerManager: NSObject {
    private let defaults: UserDefaults
    private let frameSets: [RunnerKind: RunnerFrameSet]
    private var controllers: [RunnerStatusItemController] = []
    private var animationTimer: Timer?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let pixelCatFrames = RunnerSpriteRenderer.images(for: RunnerFrames.cat)
        let prostrationFrames = RunnerSpriteRenderer.images(
            for: ProstrationFrames.all,
            logicalPixelSize: ProstrationFrames.logicalPixelSize
        )
        frameSets = [
            .pixelCat: RunnerFrameSet(frames: pixelCatFrames),
            .prostration: RunnerFrameSet(frames: prostrationFrames),
        ]

        super.init()

        let configurations = loadConfigurations()
        controllers = configurations.map {
            RunnerStatusItemController(configuration: $0, manager: self)
        }
        persistConfigurations()
        refreshAllMenus()
        startAnimationTimer()
    }

    var canRemoveRunner: Bool {
        controllers.count > 1
    }

    var launchAtLoginState: LaunchAtLoginState {
        switch SMAppService.mainApp.status {
        case .enabled:
            return LaunchAtLoginState(isRegistered: true, requiresApproval: false)
        case .requiresApproval:
            return LaunchAtLoginState(isRegistered: true, requiresApproval: true)
        case .notRegistered, .notFound:
            return LaunchAtLoginState(isRegistered: false, requiresApproval: false)
        @unknown default:
            return LaunchAtLoginState(isRegistered: false, requiresApproval: false)
        }
    }

    func isAvailable(_ runner: RunnerKind) -> Bool {
        !(frameSets[runner]?.normal ?? []).isEmpty
    }

    func frames(for configuration: RunnerConfiguration) -> [NSImage] {
        guard let frameSet = frameSets[configuration.runner] else {
            preconditionFailure("Runner has no frame set")
        }
        let frames = configuration.isMirrored
            ? frameSet.mirrored
            : frameSet.normal
        precondition(!frames.isEmpty)
        return frames
    }

    func selectRunner(id: UUID, runner: RunnerKind) {
        guard isAvailable(runner) else {
            return
        }
        updateRunner(id: id) { configuration in
            configuration.runner = runner
        }
    }

    func toggleMirrored(id: UUID) {
        updateRunner(id: id) { configuration in
            configuration.isMirrored.toggle()
        }
    }

    func toggleRunning(id: UUID) {
        updateRunner(id: id) { configuration in
            configuration.isRunning.toggle()
        }
    }

    func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp

        do {
            switch service.status {
            case .enabled, .requiresApproval:
                try service.unregister()
            case .notRegistered, .notFound:
                try service.register()
            @unknown default:
                try service.register()
            }
        } catch {
            presentLaunchAtLoginError(error)
        }

        refreshAllMenus()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func addRunner(_ runner: RunnerKind) {
        guard isAvailable(runner) else {
            return
        }

        let configuration = RunnerConfiguration(
            runner: runner,
            isRunning: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        controllers.append(
            RunnerStatusItemController(
                configuration: configuration,
                manager: self
            )
        )
        persistConfigurations()
        refreshAllMenus()
    }

    func removeRunner(id: UUID) {
        guard canRemoveRunner,
              let index = controllers.firstIndex(where: { $0.id == id })
        else {
            return
        }

        let controller = controllers.remove(at: index)
        controller.invalidate()
        persistConfigurations()
        refreshAllMenus()
    }

    private func updateRunner(
        id: UUID,
        mutation: (inout RunnerConfiguration) -> Void
    ) {
        guard let controller = controllers.first(where: { $0.id == id }) else {
            return
        }

        var configuration = controller.configuration
        mutation(&configuration)
        controller.apply(configuration)
        persistConfigurations()
    }

    private func startAnimationTimer() {
        let timer = Timer(
            timeInterval: RunnerTimeline.frameDuration,
            target: self,
            selector: #selector(handleAnimationTick(_:)),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    @objc
    private func handleAnimationTick(_ timer: Timer) {
        for controller in controllers {
            controller.advanceFrame()
        }
    }

    private func refreshAllMenus() {
        for controller in controllers {
            controller.rebuildMenu()
        }
    }

    private func loadConfigurations() -> [RunnerConfiguration] {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if let data = defaults.data(forKey: DefaultsKey.configurations),
           var configurations = try? JSONDecoder().decode(
               [RunnerConfiguration].self,
               from: data
           ) {
            configurations = configurations.filter { isAvailable($0.runner) }
            if reduceMotion {
                configurations = configurations.map { configuration in
                    var paused = configuration
                    paused.isRunning = false
                    return paused
                }
            }
            if !configurations.isEmpty {
                return configurations
            }
        }

        let legacyRunner = defaults.string(forKey: DefaultsKey.legacyRunner)
            .flatMap(RunnerKind.init(rawValue:))
            ?? .prostration
        let runner = isAvailable(legacyRunner) ? legacyRunner : .pixelCat
        let configuration = RunnerConfiguration(
            runner: runner,
            isMirrored: defaults.bool(forKey: DefaultsKey.legacyMirrored),
            isRunning: !reduceMotion
        )
        return [configuration]
    }

    private func persistConfigurations() {
        let configurations = controllers.map(\.configuration)
        guard let data = try? JSONEncoder().encode(configurations) else {
            return
        }
        defaults.set(data, forKey: DefaultsKey.configurations)
    }

    private func presentLaunchAtLoginError(_ error: Error) {
        NSApplication.shared.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "无法更改开机自动启动设置"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

}

struct LaunchAtLoginState {
    let isRegistered: Bool
    let requiresApproval: Bool
}

private struct RunnerFrameSet {
    let normal: [NSImage]
    let mirrored: [NSImage]

    @MainActor
    init(frames: [NSImage]) {
        normal = frames
        mirrored = RunnerSpriteRenderer.horizontallyFlipped(frames)
    }
}

private enum DefaultsKey {
    static let configurations = "runnerConfigurations"
    static let legacyRunner = "selectedRunner"
    static let legacyMirrored = "isMirrored"
}
