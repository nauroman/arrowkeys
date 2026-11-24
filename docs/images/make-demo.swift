// Renders docs/images/demo.gif, a caret moving through two lines of text as ArrowKeys shortcuts are pressed.
// Usage: swift docs/images/make-demo.swift docs/images/demo.gif
import AppKit
import ImageIO
import UniformTypeIdentifiers

let width = 960, height = 340
let lines = ["I wrote this sentence quickly and found a typo.", "ArrowKeys lets me fix it without leaving the letters."]
let font = NSFont.systemFont(ofSize: 26, weight: .regular)
let textColor = NSColor(calibratedWhite: 0.92, alpha: 1)
let orange = NSColor(calibratedRed: 0.93, green: 0.45, blue: 0.18, alpha: 1)
let caption = NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.45, alpha: 1)
let background = NSColor(calibratedRed: 0.106, green: 0.125, blue: 0.157, alpha: 1)
let card = NSColor(calibratedRed: 0.15, green: 0.172, blue: 0.21, alpha: 1)
let keyFill = NSColor(calibratedRed: 0.2, green: 0.226, blue: 0.27, alpha: 1)
let keyBorder = NSColor(calibratedRed: 0.32, green: 0.35, blue: 0.4, alpha: 1)
let textLeft: CGFloat = 64, lineTop: [CGFloat] = [70, 118]

struct Frame { var line: Int; var column: Int; var key: String?; var label: String; var delay: Double }

func isWordChar(_ c: Character) -> Bool { c.isLetter || c.isNumber }
func previousWord(_ s: String, _ col: Int) -> Int {
    let a = Array(s); var i = col
    while i > 0 && !isWordChar(a[i - 1]) { i -= 1 }
    while i > 0 && isWordChar(a[i - 1]) { i -= 1 }
    return i
}
func nextWord(_ s: String, _ col: Int) -> Int {
    let a = Array(s); var i = col
    while i < a.count && !isWordChar(a[i]) { i += 1 }
    while i < a.count && isWordChar(a[i]) { i += 1 }
    return i
}
func x(_ line: Int, _ column: Int) -> CGFloat {
    let prefix = String(Array(lines[line])[0..<column])
    return textLeft + (prefix as NSString).size(withAttributes: [.font: font]).width
}

// The script: each step presses a key while Caps Lock is held.
var frames: [Frame] = []
var line = 1, column = lines[1].count
func hold(_ label: String, _ delay: Double) { frames.append(Frame(line: line, column: column, key: nil, label: label, delay: delay)) }
func press(_ key: String, _ label: String, times: Int = 1, _ move: () -> Void) {
    for _ in 0..<times {
        move()
        frames.append(Frame(line: line, column: column, key: key, label: label, delay: 0.32))
        frames.append(Frame(line: line, column: column, key: nil, label: label, delay: 0.12))
    }
}
hold("", 1.0)
hold("Hold Caps Lock…", 0.8)
press("I", "Caps Lock + I   moves up", { line = 0; column = min(column, lines[0].count) })
press("H", "Caps Lock + H   jumps back a word", times: 3, { column = previousWord(lines[0], column) })
press("J", "Caps Lock + J   moves one letter left", times: 2, { column -= 1 })
press("L", "Caps Lock + L   moves one letter right", times: 2, { column += 1 })
press("U", "Caps Lock + U   goes to the line start", { column = 0 })
press(";", "Caps Lock + ;   jumps forward a word", times: 2, { column = nextWord(lines[0], column) })
press("O", "Caps Lock + O   goes to the line end", { column = lines[0].count })
press("K", "Caps Lock + K   moves down", { line = 1; column = min(column, lines[1].count) })
hold("Release Caps Lock and keep typing", 1.8)

func key(_ label: String, _ rect: NSRect, active: Bool) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)
    (active ? orange : keyFill).setFill(); path.fill()
    (active ? orange.highlight(withLevel: 0.2)! : keyBorder).setStroke(); path.lineWidth = 2; path.stroke()
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: label.count > 1 ? 17 : 24, weight: .semibold),
                                                .foregroundColor: active ? NSColor.white : textColor]
    let size = (label as NSString).size(withAttributes: attrs)
    (label as NSString).draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: attrs)
}

func render(_ f: Frame) -> CGImage {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * 2, pixelsHigh: height * 2, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    context.cgContext.translateBy(x: 0, y: CGFloat(height * 2))
    context.cgContext.scaleBy(x: 2, y: -2)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context.cgContext, flipped: true)
    background.setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
    card.setFill(); NSBezierPath(roundedRect: NSRect(x: 32, y: 40, width: width - 64, height: 140), xRadius: 14, yRadius: 14).fill()
    for (i, text) in lines.enumerated() {
        (text as NSString).draw(at: NSPoint(x: textLeft, y: lineTop[i]), withAttributes: [.font: font, .foregroundColor: textColor])
    }
    orange.setFill()
    NSRect(x: x(f.line, f.column) - 1, y: lineTop[f.line] + 2, width: 3, height: 32).fill()
    let capsHeld = f.label.hasPrefix("Caps Lock") || f.label.hasPrefix("Hold")
    key("caps lock", NSRect(x: 64, y: 248, width: 150, height: 54), active: capsHeld)
    let letters = ["U", "I", "O", "H", "J", "K", "L", ";"]
    let positions: [String: (CGFloat, CGFloat)] = ["U": (0, 0), "I": (1, 0), "O": (2, 0), "H": (-0.75, 1), "J": (0.25, 1), "K": (1.25, 1), "L": (2.25, 1), ";": (3.25, 1)]
    for letter in letters {
        let (col, row) = positions[letter]!
        key(letter, NSRect(x: 300 + col * 62, y: 186 + row * 62, width: 54, height: 54), active: f.key == letter)
    }
    let parts = f.label.components(separatedBy: "   ")
    let title: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 24, weight: .semibold), .foregroundColor: caption]
    let detail: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 21, weight: .regular), .foregroundColor: textColor]
    (parts[0] as NSString).draw(at: NSPoint(x: 600, y: parts.count > 1 ? 210 : 232), withAttributes: title)
    if parts.count > 1 { (parts[1] as NSString).draw(at: NSPoint(x: 600, y: 248), withAttributes: detail) }
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
