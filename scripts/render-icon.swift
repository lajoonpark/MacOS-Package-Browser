import AppKit

// Renders the 1024x1024 app icon: dark squircle, white package box with a
// tape seam, and a row of colored dots standing in for the package managers.
let args = CommandLine.arguments
guard args.count == 2 else {
    FileHandle.standardError.write("usage: render-icon.swift <output.png>\n".data(using: .utf8)!)
    exit(1)
}
let outputURL = URL(fileURLWithPath: args[1])

let size = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = NSSize(width: size, height: size)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
defer { NSGraphicsContext.restoreGraphicsState() }

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
}

let bgTop = color(0.23, 0.25, 0.29)
let bgBottom = color(0.09, 0.10, 0.12)

// Squircle background (Big Sur grid: 824pt art in a 1024pt canvas).
let canvas = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: canvas, xRadius: 185, yRadius: 185)
squircle.addClip()
NSGradient(colors: [bgTop, bgBottom])!.draw(in: canvas, angle: -70)

// Hairline top highlight.
NSColor.white.withAlphaComponent(0.09).setStroke()
let highlight = NSBezierPath(roundedRect: canvas.insetBy(dx: 2, dy: 2), xRadius: 183, yRadius: 183)
highlight.lineWidth = 3
highlight.stroke()

// Package box.
let box = NSRect(x: 292, y: 420, width: 440, height: 360)
color(0.97, 0.97, 0.98).setFill()
box.fill()

// Tape seam across the box, in the background color. Mid-box, so the box's
// rounded corners are untouched and no extra clip is needed.
bgBottom.setFill()
NSRect(x: box.minX, y: 560, width: box.width, height: 64).fill()

// Manager dots under the box.
let dots: [(CGFloat, NSColor)] = [
    (332, color(0.96, 0.62, 0.04)),  // Homebrew amber
    (452, color(0.94, 0.30, 0.27)),  // npm red
    (572, color(0.23, 0.51, 0.96)),  // Nix blue
    (692, color(0.66, 0.33, 0.97)),  // pkgx purple
]
for (x, dotColor) in dots {
    let circle = NSBezierPath(ovalIn: NSRect(x: x - 36, y: 264, width: 72, height: 72))
    dotColor.setFill()
    circle.fill()
}

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("PNG encoding failed\n".data(using: .utf8)!)
    exit(1)
}
try png.write(to: outputURL)
print("Wrote \(outputURL.path)")
