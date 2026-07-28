public enum RunnerKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case pixelCat
    case prostration = "bowing" // Keep settings written by version 1.5 readable.

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .pixelCat:
            "像素猫"
        case .prostration:
            "日式跪拜"
        }
    }
}
