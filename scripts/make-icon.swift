import AppKit
import Foundation

let destination = CommandLine.arguments[1]
let folder = URL(fileURLWithPath: destination).appendingPathComponent("Beira.iconset")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let factor = CGFloat(pixels) / 1024
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: factor, y: factor)
        NSColor(calibratedRed: 0.16, green: 0.19, blue: 0.18, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 208, yRadius: 208).fill()
        for right in [false, true] {
            let outer: CGFloat = right ? 714 : 310
            let inner: CGFloat = right ? 614 : 410
            let color = right ? NSColor(calibratedRed: 0.96, green: 0.78, blue: 0.43, alpha: 1)
                              : NSColor(calibratedRed: 0.9, green: 0.59, blue: 0.38, alpha: 1)
            color.setStroke()
            let bracket = NSBezierPath()
            bracket.move(to: NSPoint(x: inner, y: 730))
            bracket.line(to: NSPoint(x: outer, y: 730))
            bracket.line(to: NSPoint(x: outer, y: 294))
            bracket.line(to: NSPoint(x: inner, y: 294))
            bracket.lineWidth = 60
            bracket.lineCapStyle = .round
            bracket.lineJoinStyle = .round
            bracket.stroke()
        }
        image.unlockFocus()
        let representation = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let data = representation.representation(using: .png, properties: [:])!
        let suffix = scale == 2 ? "@2x" : ""
        try data.write(to: folder.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
