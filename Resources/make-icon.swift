// Renders the CapsNumber app icon (blue rounded square, Caps Lock arrow, keycaps 1 2 3)
// at every size macOS needs and writes Resources/AppIcon.icns.
//
//   swift Resources/make-icon.swift
import AppKit

let blueTop = NSColor(srgbRed: 0.36, green: 0.63, blue: 1.00, alpha: 1)
let blueBottom = NSColor(srgbRed: 0.10, green: 0.33, blue: 0.86, alpha: 1)
let digitBlue = NSColor(srgbRed: 0.12, green: 0.36, blue: 0.88, alpha: 1)

func roundedFont(size: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: .bold)
    if let descriptor = base.fontDescriptor.withDesign(.rounded), let font = NSFont(descriptor: descriptor, size: size) {
        return font
    }
    return base
}

func drawIcon(px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let s = CGFloat(px)
    rep.size = NSSize(width: s, height: s)
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let cg = context.cgContext
    cg.setShouldAntialias(true)
    cg.interpolationQuality = .high

    // macOS icon shape: 824/1024 rounded square with a soft shadow.
    let inset = s * 100 / 1024
    let shape = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = shape.width * 0.2237
    let shapePath = NSBezierPath(roundedRect: shape, xRadius: radius, yRadius: radius)

    cg.saveGState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = s * 0.025
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.set()
    blueBottom.setFill()
    shapePath.fill()
    cg.restoreGState()

    NSGradient(starting: blueTop, ending: blueBottom)!.draw(in: shapePath, angle: 270)

    // Soft highlight in the upper part of the square.
    cg.saveGState()
    shapePath.addClip()
    let highlight = NSGradient(starting: NSColor.white.withAlphaComponent(0), ending: NSColor.white.withAlphaComponent(0.18))!
    highlight.draw(in: shape, angle: 90)
    cg.restoreGState()

    let w = shape.width, h = shape.height

    // Three keycaps with 1 2 3.
    let key = h * 0.235
    let gap = w * 0.045
    let rowWidth = 3 * key + 2 * gap
    let rowX = shape.minX + (w - rowWidth) / 2
    let rowY = shape.minY + h * 0.16
    let digitFont = roundedFont(size: key * 0.64)
    let attributes: [NSAttributedString.Key: Any] = [.font: digitFont, .foregroundColor: digitBlue]
    for (index, digit) in ["1", "2", "3"].enumerated() {
        let rect = NSRect(x: rowX + CGFloat(index) * (key + gap), y: rowY, width: key, height: key)
        cg.saveGState()
        let keyShadow = NSShadow()
        keyShadow.shadowBlurRadius = s * 0.012
        keyShadow.shadowOffset = NSSize(width: 0, height: -s * 0.008)
        keyShadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
        keyShadow.set()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: rect, xRadius: key * 0.2, yRadius: key * 0.2).fill()
        cg.restoreGState()

        let text = NSAttributedString(string: digit, attributes: attributes)
        let size = text.size()
        let capHeight = digitFont.capHeight
        let baseline = rect.midY - capHeight / 2 - digitFont.descender * 0  // center on cap height
        text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: baseline - (size.height - capHeight) / 2 + digitFont.descender / 2))
    }

    // Caps Lock arrow (arrow up with a bar underneath), white.
    let aw = w * 0.36, ah = h * 0.34
    let ax = shape.midX - aw / 2
    let top = rowY + key + h * 0.085 + ah
    let headBase = top - ah * 0.52
    let shaftHalf = aw * 0.23
    let shaftBottom = top - ah * 0.78
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: shape.midX, y: top))
    arrow.line(to: NSPoint(x: ax + aw, y: headBase))
    arrow.line(to: NSPoint(x: shape.midX + shaftHalf, y: headBase))
    arrow.line(to: NSPoint(x: shape.midX + shaftHalf, y: shaftBottom))
    arrow.line(to: NSPoint(x: shape.midX - shaftHalf, y: shaftBottom))
    arrow.line(to: NSPoint(x: shape.midX - shaftHalf, y: headBase))
    arrow.line(to: NSPoint(x: ax, y: headBase))
    arrow.close()
    let bar = NSBezierPath(roundedRect: NSRect(x: shape.midX - shaftHalf, y: top - ah, width: shaftHalf * 2, height: ah * 0.13),
                           xRadius: ah * 0.04, yRadius: ah * 0.04)
    cg.saveGState()
    let arrowShadow = NSShadow()
    arrowShadow.shadowBlurRadius = s * 0.012
    arrowShadow.shadowOffset = NSSize(width: 0, height: -s * 0.008)
    arrowShadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    arrowShadow.set()
    cg.beginTransparencyLayer(auxiliaryInfo: nil)
    NSColor.white.setFill()
    NSColor.white.setStroke()
    arrow.lineWidth = aw * 0.07
    arrow.lineJoinStyle = .round
    arrow.fill()
    arrow.stroke()
    bar.fill()
    cg.endTransparencyLayer()
    cg.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let iconset = scriptDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in entries {
    let data = drawIcon(px: px).representation(using: .png, properties: [:])!
    try! data.write(to: iconset.appendingPathComponent("\(name).png"))
}

let icns = scriptDir.appendingPathComponent("AppIcon.icns")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try! task.run()
task.waitUntilExit()
if task.terminationStatus == 0 {
    try? FileManager.default.removeItem(at: iconset)
    print("Wrote \(icns.path)")
} else {
    print("iconutil failed"); exit(1)
}
