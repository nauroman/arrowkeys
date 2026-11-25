// Renders docs/images/demo.gif, a caret moving through two lines of text while Caps Lock and J, I, K or L are held.
// Usage: swift docs/images/make-demo.swift docs/images/demo.gif
import AppKit
import ImageIO
import UniformTypeIdentifiers

let width = 960, height = 340, scale = 2
let lines = ["I wrote this sentence quickly and found a typo.", "ArrowKeys lets me fix it without leaving the letters."]
let font = NSFont.systemFont(ofSize: 26, weight: .regular)
let textColor = NSColor(calibratedWhite: 0.92, alpha: 1)
let mutedColor = NSColor(calibratedWhite: 0.62, alpha: 1)
let orange = NSColor(calibratedRed: 0.93, green: 0.45, blue: 0.18, alpha: 1)
let captionColor = NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.45, alpha: 1)
let background = NSColor(calibratedRed: 0.106, green: 0.125, blue: 0.157, alpha: 1)
let card = NSColor(calibratedRed: 0.15, green: 0.172, blue: 0.21, alpha: 1)
let keyFill = NSColor(calibratedRed: 0.2, green: 0.226, blue: 0.27, alpha: 1)
let keyBorder = NSColor(calibratedRed: 0.32, green: 0.35, blue: 0.4, alpha: 1)
let textLeft: CGFloat = 64, lineTop: [CGFloat] = [70, 118]

// Keyboard layout: Caps Lock on the home row, then I above K and J K L below, like arrow keys.
let keySize: CGFloat = 58, gap: CGFloat = 8, topRow: CGFloat = 192, homeRow: CGFloat = topRow + keySize + gap
let capsRect = NSRect(x: 64, y: homeRow, width: 150, height: keySize)
let clusterLeft: CGFloat = 268
let arrowKeys: [(letter: String, arrow: String, rect: NSRect)] = [
    ("I", "↑", NSRect(x: clusterLeft + keySize + gap, y: topRow, width: keySize, height: keySize)),
    ("J", "←", NSRect(x: clusterLeft, y: homeRow, width: keySize, height: keySize)),
    ("K", "↓", NSRect(x: clusterLeft + keySize + gap, y: homeRow, width: keySize, height: keySize)),
    ("L", "→", NSRect(x: clusterLeft + 2 * (keySize + gap), y: homeRow, width: keySize, height: keySize)),
]
let captionLeft: CGFloat = 500, captionRight = CGFloat(width) - 40
let titleFont = NSFont.systemFont(ofSize: 26, weight: .semibold)
let detailFont = NSFont.systemFont(ofSize: 22, weight: .regular)

struct Frame { var line: Int; var column: Int; var key: String?; var caps: Bool; var title: String; var detail: String; var delay: Double }

var frames: [Frame] = []
var line = 1, column = lines[1].count
func hold(caps: Bool, _ title: String, _ detail: String, _ delay: Double) {
    frames.append(Frame(line: line, column: column, key: nil, caps: caps, title: title, detail: detail, delay: delay))
}
func press(_ key: String, _ detail: String, times: Int = 1, _ move: () -> Void) {
    for _ in 0..<times {
        move()
        frames.append(Frame(line: line, column: column, key: key, caps: true, title: "Caps Lock + \(key)", detail: detail, delay: 0.3))
        frames.append(Frame(line: line, column: column, key: nil, caps: true, title: "Caps Lock + \(key)", detail: detail, delay: 0.1))
    }
}
hold(caps: false, "", "", 1.0)
hold(caps: true, "Hold Caps Lock", "then press J, K, L or I", 1.4)
press("I", "moves the cursor up", { line = 0; column = min(column, lines[0].count) })
press("J", "moves the cursor left", times: 6, { column -= 1 })
press("L", "moves the cursor right", times: 3, { column += 1 })
press("K", "moves the cursor down", { line = 1; column = min(column, lines[1].count) })
hold(caps: false, "Release Caps Lock", "and keep typing", 2.0)

// Every caption must fit between the keys and the right edge.
for f in frames {
    let widest = max((f.title as NSString).size(withAttributes: [.font: titleFont]).width,
                     (f.detail as NSString).size(withAttributes: [.font: detailFont]).width)
    precondition(captionLeft + widest <= captionRight, "Caption does not fit: \(f.title) / \(f.detail)")
}
for text in lines {
    precondition(textLeft + (text as NSString).size(withAttributes: [.font: font]).width <= CGFloat(width) - 64, "Line does not fit: \(text)")
}

func x(_ line: Int, _ column: Int) -> CGFloat {
    let prefix = String(Array(lines[line])[0..<column])
    return textLeft + (prefix as NSString).size(withAttributes: [.font: font]).width
}

func drawCentered(_ text: String, in rect: NSRect, y: CGFloat, _ attrs: [NSAttributedString.Key: Any]) {
    let size = (text as NSString).size(withAttributes: attrs)
    (text as NSString).draw(at: NSPoint(x: rect.midX - size.width / 2, y: y), withAttributes: attrs)
}

func drawKey(_ rect: NSRect, active: Bool) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
    (active ? orange : keyFill).setFill(); path.fill()
    (active ? orange.highlight(withLevel: 0.2)! : keyBorder).setStroke(); path.lineWidth = 2; path.stroke()
}

func render(_ f: Frame) -> CGImage {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * scale, pixelsHigh: height * scale, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    context.cgContext.translateBy(x: 0, y: CGFloat(height * scale))
    context.cgContext.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context.cgContext, flipped: true)
    background.setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
    card.setFill(); NSBezierPath(roundedRect: NSRect(x: 32, y: 40, width: width - 64, height: 140), xRadius: 14, yRadius: 14).fill()
    for (i, text) in lines.enumerated() {
        (text as NSString).draw(at: NSPoint(x: textLeft, y: lineTop[i]), withAttributes: [.font: font, .foregroundColor: textColor])
    }
    orange.setFill()
    NSRect(x: x(f.line, f.column) - 1, y: lineTop[f.line] + 2, width: 3, height: 32).fill()

    drawKey(capsRect, active: f.caps)
    drawCentered("caps lock", in: capsRect, y: capsRect.midY - 11,
                 [.font: NSFont.systemFont(ofSize: 18, weight: .semibold), .foregroundColor: f.caps ? NSColor.white : textColor])
    drawCentered("+", in: NSRect(x: capsRect.maxX, y: 0, width: clusterLeft - capsRect.maxX, height: 0), y: homeRow + 12,
                 [.font: NSFont.systemFont(ofSize: 26, weight: .medium), .foregroundColor: mutedColor])
    for key in arrowKeys {
        let active = f.key == key.letter
        drawKey(key.rect, active: active)
        drawCentered(key.letter, in: key.rect, y: key.rect.minY + 5,
                     [.font: NSFont.systemFont(ofSize: 22, weight: .bold), .foregroundColor: active ? NSColor.white : textColor])
        drawCentered(key.arrow, in: key.rect, y: key.rect.minY + 28,
                     [.font: NSFont.systemFont(ofSize: 19, weight: .bold), .foregroundColor: active ? NSColor.white : orange])
    }

    (f.title as NSString).draw(at: NSPoint(x: captionLeft, y: topRow + 34), withAttributes: [.font: titleFont, .foregroundColor: captionColor])
    (f.detail as NSString).draw(at: NSPoint(x: captionLeft, y: topRow + 72), withAttributes: [.font: detailFont, .foregroundColor: textColor])
    NSGraphicsContext.restoreGraphicsState()
    return rep.cgImage!
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(out as CFURL, UTType.gif.identifier as CFString, frames.count, nil)!
CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for f in frames {
    CGImageDestinationAddImage(destination, render(f), [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: f.delay]] as CFDictionary)
}
precondition(CGImageDestinationFinalize(destination))
print("frames:", frames.count)
