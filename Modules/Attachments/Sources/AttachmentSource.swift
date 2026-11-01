import Foundation

/// Where the picker menu lets people add from. Camera is left out by itself where there is none.
public struct AttachmentSource: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let photos = AttachmentSource(rawValue: 1 << 0)
    public static let camera = AttachmentSource(rawValue: 1 << 1)
    public static let files = AttachmentSource(rawValue: 1 << 2)
    public static let link = AttachmentSource(rawValue: 1 << 3)
    public static let all: AttachmentSource = [.photos, .camera, .files, .link]
}
