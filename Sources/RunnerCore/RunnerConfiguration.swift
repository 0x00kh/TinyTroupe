import Foundation

public struct RunnerConfiguration: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var runner: RunnerKind
    public var isMirrored: Bool
    public var isRunning: Bool

    public init(
        id: UUID = UUID(),
        runner: RunnerKind,
        isMirrored: Bool = false,
        isRunning: Bool = true
    ) {
        self.id = id
        self.runner = runner
        self.isMirrored = isMirrored
        self.isRunning = isRunning
    }
}
