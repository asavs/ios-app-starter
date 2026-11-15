import CoreGraphics
import Foundation

extension AttachmentStoring {
    /// A stored photo at a size for a full-screen viewer: read from the original each time and scaled
    /// to fit `pixelSize` on its longer side, so it is sharp where the cached grid thumbnail would
    /// be blurred, and a 48-megapixel original never decodes at full size. Nil for anything but a
    /// readable image. Runs off the caller's actor.
    public func displayImage(for attachment: Attachment, pixelSize: Int) async -> CGImage? {
        guard attachment.kind == .image, let file = fileURL(for: attachment) else { return nil }
        return ThumbnailMaker.imageThumbnail(of: file, pixelSize: pixelSize)
    }
}
