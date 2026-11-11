// Draws the app icon and writes Support/AppIcon.icns.
//   swift tools/make_icon.swift
// A scope screen with a yellow CH1 trace, framed by capture corners.
import AppKit

let size = 1024.0
let out = URL(fileURLWithPath: "Support/AppIcon.icns")

func draw(_ ctx: CGContext) {
    let s = size
    // Body: the macOS icon grid puts an 824 pt rounded square in a 1024 canvas.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.35))
    ctx.addPath(bodyPath)
    ctx.setFillColor(CGColor(srgbRed: 0.17, green: 0.19, blue: 0.22, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: [CGColor(srgbRed: 0.24, green: 0.27, blue: 0.31, alpha: 1),
                                   CGColor(srgbRed: 0.11, green: 0.12, blue: 0.14, alpha: 1)] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])
    ctx.restoreGState()

    // Screen.
    let screen = CGRect(x: 196, y: 262, width: 632, height: 500)
    ctx.addPath(CGPath(roundedRect: screen, cornerWidth: 28, cornerHeight: 28, transform: nil))
    ctx.setFillColor(CGColor(srgbRed: 0.02, green: 0.03, blue: 0.04, alpha: 1))
    ctx.fillPath()

    // Graticule: 8 x 6 divisions, centre lines brighter.
    let cols = 8, rows = 6
    for i in 1..<cols {
        let x = screen.minX + screen.width * Double(i) / Double(cols)
        ctx.setStrokeColor(CGColor(gray: 1, alpha: i == cols / 2 ? 0.28 : 0.12))
        ctx.setLineWidth(3)
        ctx.move(to: CGPoint(x: x, y: screen.minY + 14)); ctx.addLine(to: CGPoint(x: x, y: screen.maxY - 14))
        ctx.strokePath()
    }
    for j in 1..<rows {
        let y = screen.minY + screen.height * Double(j) / Double(rows)
        ctx.setStrokeColor(CGColor(gray: 1, alpha: j == rows / 2 ? 0.28 : 0.12))
        ctx.setLineWidth(3)
        ctx.move(to: CGPoint(x: screen.minX + 14, y: y)); ctx.addLine(to: CGPoint(x: screen.maxX - 14, y: y))
        ctx.strokePath()
    }

    // Trace: two sine cycles, with a soft glow under a crisp line.
    let trace = CGMutablePath()
    let inset = 30.0
    let steps = 400
    for k in 0...steps {
        let t = Double(k) / Double(steps)
        let x = screen.minX + inset + (screen.width - 2 * inset) * t
        let y = screen.midY + 150 * sin(t * 2 * .pi * 2)
        k == 0 ? trace.move(to: CGPoint(x: x, y: y)) : trace.addLine(to: CGPoint(x: x, y: y))
    }
    let yellow = CGColor(srgbRed: 1.0, green: 0.86, blue: 0.1, alpha: 1)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 30, color: CGColor(srgbRed: 1, green: 0.8, blue: 0, alpha: 0.9))
    ctx.addPath(trace)
    ctx.setStrokeColor(yellow)
    ctx.setLineWidth(16)
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.restoreGState()

    // Capture corners around the screen.
    let pad = 30.0, arm = 92.0
    let frame = screen.insetBy(dx: -pad, dy: -pad)
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.95))
    ctx.setLineWidth(22)
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    for (cx, cy, dx, dy) in [(frame.minX, frame.minY, 1.0, 1.0), (frame.maxX, frame.minY, -1.0, 1.0),
                             (frame.minX, frame.maxY, 1.0, -1.0), (frame.maxX, frame.maxY, -1.0, -1.0)] {
        ctx.move(to: CGPoint(x: cx, y: cy + dy * arm))
        ctx.addLine(to: CGPoint(x: cx, y: cy))
        ctx.addLine(to: CGPoint(x: cx + dx * arm, y: cy))
        ctx.strokePath()
    }
    _ = s
}

func png(_ px: Int) -> Data {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: Double(px) / size, y: Double(px) / size)
    draw(ctx)
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = fm.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for pt in [16, 32, 128, 256, 512] {
    try png(pt).write(to: iconset.appendingPathComponent("icon_\(pt)x\(pt).png"))
    try png(pt * 2).write(to: iconset.appendingPathComponent("icon_\(pt)x\(pt)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try p.run(); p.waitUntilExit()
if CommandLine.arguments.count > 1 {
    try png(1024).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
print("wrote \(out.path)")
