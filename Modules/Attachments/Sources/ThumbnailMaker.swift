import Foundation
import ImageIO
import UniformTypeIdentifiers
#if canImport(QuickLookThumbnailing)
import QuickLookThumbnailing
#endif

/// Small images for grid cells, decoded small: ImageIO draws an image's thumbnail without holding
/// the full bitmap, and Quick Look makes one for anything else (the same images the Files app
/// shows). Thumbnails are written as JPEG under the store's cache.
enum ThumbnailMaker {
    static func make(for file: URL, kind: Attachment.Kind, pixelSize: Int) async -> CGImage? {
        switch kind {
        case .image: return imageThumbnail(of: file, pixelSize: pixelSize)
        case .movie, .file: return await quickLookThumbnail(of: file, pixelSize: pixelSize)
        case .link: return nil
        }
    }

    static func imageThumbnail(of file: URL, pixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceThumbnailMaxPixelSize: pixelSize,
                                        kCGImageSourceCreateThumbnailWithTransform: true]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func quickLookThumbnail(of file: URL, pixelSize: Int) async -> CGImage? {
#if canImport(QuickLookThumbnailing)
        let request = QLThumbnailGenerator.Request(fileAt: file, size: CGSize(width: pixelSize, height: pixelSize),
                                                   scale: 1, representationTypes: .all)
        return try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).cgImage
#else
        return nil
#endif
    }

    static func image(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func write(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }

    /// Encoded JPEG bytes of a plain image: the fake camera's capture, and test fixtures.
    static func sampleJPEG(width: Int = 600, height: Int = 400, hue: CGFloat = 0.58) -> Data? {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.setFillColor(CGColor(colorSpace: space, components: [hue, 0.5, 1 - hue, 1]) ?? CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
        guard let image = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
