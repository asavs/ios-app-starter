// Draws a 1280x640 social preview card: icon, title, tagline and chips on the left, up to three
// screenshots fanned on the right. Called by scripts/social-preview.py, which picks the inputs.
//
// swift scripts/render-social-preview.swift --theme light|dark --output card.png --icon icon.png
//     --title "My App" [--tagline "..."] [--url "github.com/me/app"]
//     [--chip Onboarding ...] [--planned "AI chat" ...] [--screen front.png --screen middle.png --screen back.png]
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

// The text column is narrower when screenshots take the right half.
let left: CGFloat = 72
let column: CGFloat = screens.isEmpty ? width - 2 * left : 580

/// Draws wrapped text with its top at `top` and returns the y of its bottom edge.
func paragraph(_ string: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, top: CGFloat) -> CGFloat {
    let text = NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight),
                                                               .foregroundColor: color])
    let bounds = text.boundingRect(with: NSSize(width: column, height: 400), options: [.usesLineFragmentOrigin])
    text.draw(with: NSRect(x: left, y: top - bounds.height, width: column, height: bounds.height), options: [.usesLineFragmentOrigin])
    return top - bounds.height
}

/// Rounded labels that wrap within the column; planned features get a dashed outline and "· soon".
func chips(_ labels: [(String, Bool)], top: CGFloat) {
    let size: CGFloat = 19, chipHeight = size + 18
    var x = left, y = top - chipHeight
    for (label, planned) in labels {
        let text = NSAttributedString(string: planned ? "\(label) · soon" : label, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: planned ? ink.withAlphaComponent(0.6) : accent])
        let chipWidth = text.size().width + 30
        if x + chipWidth > left + column {
            x = left
            y -= chipHeight + 10
        }
        let path = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: chipWidth, height: chipHeight),
                                xRadius: chipHeight / 2, yRadius: chipHeight / 2)
        if planned {
            path.lineWidth = 1.5
            path.setLineDash([5, 4], count: 2, phase: 0)
            ink.withAlphaComponent(0.35).setStroke()
            path.stroke()
        } else {
            accent.withAlphaComponent(dark ? 0.18 : 0.12).setFill()
            path.fill()
        }
        text.draw(at: NSPoint(x: x + 15, y: y + 8))
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

// Left column, top down.
icon.draw(in: NSRect(x: left, y: 430, width: 132, height: 132))
var cursor = paragraph(title, size: 60, weight: .bold, color: ink, top: 410)
if let tagline = option("tagline"), !tagline.isEmpty {
    cursor = paragraph(tagline, size: 26, weight: .regular, color: ink.withAlphaComponent(0.68), top: cursor - 10)
}
let labels = (options["chip"] ?? []).map { ($0, false) } + (options["planned"] ?? []).map { ($0, true) }
if !labels.isEmpty {
    chips(labels, top: cursor - 26)
}
if let url = option("url"), !url.isEmpty {
    NSAttributedString(string: url, attributes: [.font: NSFont.systemFont(ofSize: 18, weight: .medium),
                                                 .foregroundColor: ink.withAlphaComponent(0.42)])
        .draw(at: NSPoint(x: left, y: 30))
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
