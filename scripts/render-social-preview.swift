// Draws a 1280x640 social preview card: the app icon beside the title, a tagline, feature rows with
// drawn icons, one line of chips, and up to three screenshots fanned on the right.
// Called by scripts/social-preview.py, which reads .github/social-preview.json and picks the inputs.
//
// swift scripts/render-social-preview.swift --theme light|dark --output card.png --icon icon.png
//     --title "My App" [--tagline "..."] [--url "github.com/me/app"]
//     [--feature "glyph|label" or "glyph|label|soon" ...] [--chip label ...]
//     [--screen front.png --screen middle.png --screen back.png]
// Glyphs: modules, chat, bridge, backend, lock, sparkle, globe, check. Anything else draws a dot.
import AppKit

var options: [String: [String]] = [:]
var arguments = CommandLine.arguments.dropFirst()
while let flag = arguments.popFirst() {
    guard flag.hasPrefix("--"), let value = arguments.popFirst() else {
        FileHandle.standardError.write(Data("render-social-preview: expected --flag value pairs, got \(flag)\n".utf8))
        exit(64)
    }
    options[String(flag.dropFirst(2)), default: []].append(value)
}
func option(_ name: String) -> String? { options[name]?.last }
func image(_ path: String) -> NSImage {
    guard let image = NSImage(contentsOfFile: path) else {
        FileHandle.standardError.write(Data("render-social-preview: cannot read image \(path)\n".utf8))
        exit(1)
    }
    return image
}
guard let output = option("output"), let iconPath = option("icon"), let title = option("title") else {
    FileHandle.standardError.write(Data("render-social-preview: --output, --icon and --title are required\n".utf8))
    exit(64)
}
let dark = option("theme") == "dark"
let icon = image(iconPath)
let screens = (options["screen"] ?? []).prefix(3).map(image)
let features = (options["feature"] ?? []).prefix(4).map { spec -> (glyph: String, label: String, soon: Bool) in
    let parts = spec.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
    return (parts[0], parts.count > 1 ? parts[1] : parts[0], parts.count > 2 && parts[2] == "soon")
}

let width: CGFloat = 1280, height: CGFloat = 640
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let ink = dark ? NSColor.white : NSColor(srgbRed: 0.07, green: 0.11, blue: 0.20, alpha: 1)
let accent = dark ? NSColor(srgbRed: 0.55, green: 0.75, blue: 1, alpha: 1) : NSColor(srgbRed: 0.05, green: 0.35, blue: 0.85, alpha: 1)
NSGradient(starting: dark ? NSColor(srgbRed: 0.06, green: 0.09, blue: 0.18, alpha: 1) : NSColor(srgbRed: 0.97, green: 0.98, blue: 1, alpha: 1),
           ending: dark ? NSColor(srgbRed: 0.03, green: 0.05, blue: 0.11, alpha: 1) : NSColor(srgbRed: 0.88, green: 0.93, blue: 0.99, alpha: 1))!
    .draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)

let left: CGFloat = 72
let column: CGFloat = screens.isEmpty ? width - 2 * left : 590

func attributed(_ string: String, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor) -> NSAttributedString {
    NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
}

/// Draws wrapped text with its top at `top`, from `x` across the rest of the column; returns its bottom y.
func paragraph(_ text: NSAttributedString, x: CGFloat = left, top: CGFloat) -> CGFloat {
    let available = left + column - x
    let bounds = text.boundingRect(with: NSSize(width: available, height: 400), options: [.usesLineFragmentOrigin])
    text.draw(with: NSRect(x: x, y: top - bounds.height, width: available, height: bounds.height), options: [.usesLineFragmentOrigin])
    return top - bounds.height
}

/// A simple line glyph drawn into `box`, so the card uses no Apple symbol or emoji artwork.
func glyph(_ name: String, in box: NSRect) {
    let s = box.width, x = box.minX, y = box.minY
    func p(_ px: CGFloat, _ py: CGFloat) -> NSPoint { NSPoint(x: x + px * s, y: y + py * s) }
    func rounded(_ rx: CGFloat, _ ry: CGFloat, _ rw: CGFloat, _ rh: CGFloat, _ r: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: NSRect(x: x + rx * s, y: y + ry * s, width: rw * s, height: rh * s), xRadius: r * s, yRadius: r * s)
    }
    func bubble(_ rx: CGFloat, _ ry: CGFloat, _ rw: CGFloat, _ rh: CGFloat, tailLeft: Bool) -> NSBezierPath {
        let path = rounded(rx, ry, rw, rh, 0.14)
        let tail = NSBezierPath()
        let tx = tailLeft ? rx + 0.12 : rx + rw - 0.12
        tail.move(to: p(tx - 0.06, ry + 0.02))
        tail.line(to: p(tailLeft ? tx - 0.12 : tx + 0.12, ry - 0.12))
        tail.line(to: p(tx + 0.06, ry + 0.02))
        path.append(tail)
        return path
    }
    accent.set()
    var paths: [NSBezierPath] = []
    var filled: [NSBezierPath] = []
    switch name {
    case "modules":
        paths = [rounded(0.08, 0.52, 0.36, 0.36, 0.08), rounded(0.56, 0.52, 0.36, 0.36, 0.08), rounded(0.08, 0.08, 0.36, 0.36, 0.08)]
        filled = [rounded(0.56, 0.08, 0.36, 0.36, 0.08)]
    case "chat":
        paths = [bubble(0.06, 0.26, 0.88, 0.62, tailLeft: true)]
        filled = [0.3, 0.5, 0.7].map { NSBezierPath(ovalIn: NSRect(x: x + ($0 - 0.05) * s, y: y + 0.52 * s, width: 0.1 * s, height: 0.1 * s)) }
    case "bridge":
        paths = [bubble(0.04, 0.42, 0.56, 0.44, tailLeft: true), bubble(0.40, 0.16, 0.56, 0.44, tailLeft: false)]
    case "backend":
        paths = [rounded(0.08, 0.64, 0.84, 0.26, 0.07), rounded(0.08, 0.37, 0.84, 0.26, 0.07), rounded(0.08, 0.10, 0.84, 0.26, 0.07)]
        filled = [0.77, 0.50, 0.23].map { NSBezierPath(ovalIn: NSRect(x: x + 0.72 * s, y: y + ($0 - 0.04) * s, width: 0.08 * s, height: 0.08 * s)) }
    case "lock":
        let shackle = NSBezierPath()
        shackle.appendArc(withCenter: p(0.5, 0.56), radius: 0.22 * s, startAngle: 0, endAngle: 180)
        shackle.line(to: p(0.28, 0.46))
        shackle.move(to: p(0.72, 0.56))
        shackle.line(to: p(0.72, 0.46))
        paths = [shackle, rounded(0.14, 0.06, 0.72, 0.44, 0.08)]
    case "sparkle":
        let star = NSBezierPath()
        star.move(to: p(0.5, 0.94))
        for (px, py) in [(0.6, 0.6), (0.94, 0.5), (0.6, 0.4), (0.5, 0.06), (0.4, 0.4), (0.06, 0.5), (0.4, 0.6)] { star.line(to: p(px, py)) }
        star.close()
        filled = [star]
    case "globe":
        let meridian = NSBezierPath(ovalIn: NSRect(x: x + 0.3 * s, y: y + 0.08 * s, width: 0.4 * s, height: 0.84 * s))
        let equator = NSBezierPath()
        equator.move(to: p(0.08, 0.5))
        equator.line(to: p(0.92, 0.5))
        paths = [NSBezierPath(ovalIn: NSRect(x: x + 0.08 * s, y: y + 0.08 * s, width: 0.84 * s, height: 0.84 * s)), meridian, equator]
    case "check":
        let tick = NSBezierPath()
        tick.move(to: p(0.12, 0.5))
        tick.line(to: p(0.4, 0.22))
        tick.line(to: p(0.9, 0.78))
        paths = [tick]
    default:
        filled = [NSBezierPath(ovalIn: NSRect(x: x + 0.35 * s, y: y + 0.35 * s, width: 0.3 * s, height: 0.3 * s))]
    }
    for path in paths {
        path.lineWidth = max(2, s * 0.09)
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }
    for path in filled { path.fill() }
}

/// One line of rounded labels; labels that would overflow the column are left off.
func chips(_ labels: [String], baseline y: CGFloat) {
    let size: CGFloat = 17, chipHeight = size + 16
    var x = left
    for label in labels {
        let text = attributed(label, size, .semibold, accent)
        let chipWidth = text.size().width + 28
        guard x + chipWidth <= left + column else { break }
        accent.withAlphaComponent(dark ? 0.18 : 0.12).setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: chipWidth, height: chipHeight),
                     xRadius: chipHeight / 2, yRadius: chipHeight / 2).fill()
        text.draw(at: NSPoint(x: x + 14, y: y + 7))
        x += chipWidth + 10
    }
}

/// A plain drawn phone outline (not an Apple device frame) holding a screenshot, rotated about its centre.
func phone(_ shot: NSImage, center: NSPoint, height phoneHeight: CGFloat, degrees: CGFloat) {
    let phoneWidth = phoneHeight * shot.size.width / shot.size.height
    let rect = NSRect(x: -phoneWidth / 2, y: -phoneHeight / 2, width: phoneWidth, height: phoneHeight)
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: center.x, yBy: center.y)
    transform.rotate(byDegrees: degrees)
    transform.concat()
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowColor = NSColor.black.withAlphaComponent(dark ? 0.55 : 0.22)
    shadow.set()
    NSColor(white: dark ? 0.2 : 0.12, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: 38, yRadius: 38).fill()
    NSGraphicsContext.restoreGraphicsState()
    let screen = rect.insetBy(dx: 9, dy: 9)
    NSBezierPath(roundedRect: screen, xRadius: 31, yRadius: 31).addClip()
    shot.draw(in: screen)
    NSGraphicsContext.restoreGraphicsState()
}

// Header: app icon with the title beside it.
let iconSize: CGFloat = 112
icon.draw(in: NSRect(x: left, y: height - 72 - iconSize, width: iconSize, height: iconSize))
let titleText = attributed(title, 54, .bold, ink)
let titleHeight = titleText.boundingRect(with: NSSize(width: column - iconSize - 24, height: 300), options: [.usesLineFragmentOrigin]).height
var cursor = paragraph(titleText, x: left + iconSize + 24, top: height - 72 - (iconSize - titleHeight) / 2)
cursor = min(cursor, height - 72 - iconSize) - 22

if let tagline = option("tagline"), !tagline.isEmpty {
    cursor = paragraph(attributed(tagline, 25, .regular, ink.withAlphaComponent(0.68)), top: cursor) - 26
}

// Feature rows: a tinted tile with the glyph, then the label, then "soon" for planned ones.
for feature in features {
    let tile: CGFloat = 40, rowTop = cursor
    let tileRect = NSRect(x: left, y: rowTop - tile, width: tile, height: tile)
    accent.withAlphaComponent(dark ? 0.18 : 0.12).setFill()
    NSBezierPath(roundedRect: tileRect, xRadius: 10, yRadius: 10).fill()
    glyph(feature.glyph, in: tileRect.insetBy(dx: 9, dy: 9))
    let label = attributed(feature.label, 24, .semibold, ink)
    let labelY = rowTop - tile + (tile - label.size().height) / 2
    label.draw(at: NSPoint(x: left + tile + 16, y: labelY))
    if feature.soon {
        let soon = attributed("SOON", 13, .bold, ink.withAlphaComponent(0.55))
        let soonX = left + tile + 16 + label.size().width + 12
        let soonRect = NSRect(x: soonX, y: rowTop - tile + 10, width: soon.size().width + 16, height: 20)
        let outline = NSBezierPath(roundedRect: soonRect, xRadius: 10, yRadius: 10)
        outline.lineWidth = 1.5
        ink.withAlphaComponent(0.3).setStroke()
        outline.stroke()
        soon.draw(at: NSPoint(x: soonX + 8, y: soonRect.minY + 2))
    }
    cursor = rowTop - tile - 14
}

let chipLabels = options["chip"] ?? []
if !chipLabels.isEmpty {
    chips(chipLabels, baseline: max(72, cursor - 48))
}
if let url = option("url"), !url.isEmpty {
    attributed(url, 18, .medium, ink.withAlphaComponent(0.42)).draw(at: NSPoint(x: left, y: 30))
}

// Right: screenshots fanned, the first one in front.
let fan: [(x: CGFloat, y: CGFloat, degrees: CGFloat)] = [(800, 318, 7), (972, 330, 0), (1140, 318, -7)]
for (index, shot) in screens.enumerated().reversed() {
    let slot = screens.count == 1 ? (x: CGFloat(972), y: CGFloat(320), degrees: CGFloat(0)) : fan[index]
    phone(shot, center: NSPoint(x: slot.x, y: slot.y), height: 460, degrees: slot.degrees)
}

NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]),
      (try? png.write(to: URL(fileURLWithPath: output))) != nil else {
    FileHandle.standardError.write(Data("render-social-preview: cannot write \(output)\n".utf8))
    exit(1)
}
print(output)
