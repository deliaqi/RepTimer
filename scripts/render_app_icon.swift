import AppKit
import CoreGraphics
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "RepTimer/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let size = 1024

guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("Could not create the app icon drawing context.")
}

let forest = NSColor(calibratedRed: 0.055, green: 0.11, blue: 0.075, alpha: 1)
let deepGreen = NSColor(calibratedRed: 0.12, green: 0.21, blue: 0.145, alpha: 1)
let faceGreen = NSColor(calibratedRed: 0.075, green: 0.145, blue: 0.10, alpha: 1)
let lime = NSColor(calibratedRed: 0.85, green: 1.00, blue: 0.33, alpha: 1)
let softLime = NSColor(calibratedRed: 0.91, green: 0.96, blue: 0.78, alpha: 1)
let mint = NSColor(calibratedRed: 0.42, green: 0.82, blue: 0.70, alpha: 1)

let background = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [deepGreen.cgColor, forest.cgColor] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(background, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

let halo = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [NSColor(calibratedRed: 0.85, green: 1, blue: 0.33, alpha: 0.18).cgColor, NSColor(calibratedRed: 0.85, green: 1, blue: 0.33, alpha: 0).cgColor] as CFArray,
    locations: [0, 1]
)!
context.drawRadialGradient(
    halo,
    startCenter: CGPoint(x: 512, y: 535),
    startRadius: 20,
    endCenter: CGPoint(x: 512, y: 535),
    endRadius: 570,
    options: []
)

func fillRoundedRectangle(_ rect: CGRect, radius: CGFloat, color: NSColor) {
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(path)
    context.setFillColor(color.cgColor)
    context.fillPath()
}

// Top pusher, tucked behind the timer body.
fillRoundedRectangle(CGRect(x: 466, y: 758, width: 92, height: 138), radius: 30, color: lime)
fillRoundedRectangle(CGRect(x: 442, y: 834, width: 140, height: 44), radius: 18, color: softLime)

let center = CGPoint(x: 512, y: 500)
let outerDial = CGRect(x: 202, y: 190, width: 620, height: 620)
context.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: NSColor.black.withAlphaComponent(0.36).cgColor)
context.setFillColor(softLime.cgColor)
context.fillEllipse(in: outerDial)
context.setShadow(offset: .zero, blur: 0, color: nil)

let face = CGRect(x: 238, y: 226, width: 548, height: 548)
context.setFillColor(faceGreen.cgColor)
context.fillEllipse(in: face)

// Progress track and active arc make the stopwatch read as an interval timer.
context.setStrokeColor(NSColor.white.withAlphaComponent(0.12).cgColor)
context.setLineWidth(13)
context.strokeEllipse(in: CGRect(x: 260, y: 248, width: 504, height: 504))

context.addArc(
    center: center,
    radius: 252,
    startAngle: .pi / 2,
    endAngle: .pi / 2 - 4.45,
    clockwise: true
)
context.setStrokeColor(lime.cgColor)
context.setLineWidth(17)
context.setLineCap(.round)
context.strokePath()

// Minute marks around the dial stay legible at home-screen size.
for mark in 0..<60 {
    let angle = CGFloat.pi / 2 - CGFloat(mark) * 2 * CGFloat.pi / 60
    let isMajor = mark.isMultiple(of: 5)
    let outerRadius: CGFloat = 220
    let innerRadius: CGFloat = isMajor ? 194 : 207
    let start = CGPoint(x: center.x + cos(angle) * innerRadius, y: center.y + sin(angle) * innerRadius)
    let end = CGPoint(x: center.x + cos(angle) * outerRadius, y: center.y + sin(angle) * outerRadius)
    context.move(to: start)
    context.addLine(to: end)
    context.setStrokeColor((isMajor ? softLime : mint).withAlphaComponent(isMajor ? 0.92 : 0.58).cgColor)
    context.setLineWidth(isMajor ? 9 : 4)
    context.setLineCap(.round)
    context.strokePath()
}

// Two hands sit at different lengths to suggest a focused workout interval.
context.setStrokeColor(softLime.cgColor)
context.setLineWidth(25)
context.setLineCap(.round)
context.move(to: center)
context.addLine(to: CGPoint(x: 421, y: 594))
context.strokePath()

context.setStrokeColor(lime.cgColor)
context.setLineWidth(20)
context.setLineCap(.round)
context.move(to: center)
context.addLine(to: CGPoint(x: 625, y: 648))
context.strokePath()

context.setFillColor(lime.cgColor)
context.fillEllipse(in: CGRect(x: 488, y: 476, width: 48, height: 48))
context.setFillColor(faceGreen.cgColor)
context.fillEllipse(in: CGRect(x: 503, y: 491, width: 18, height: 18))

let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let cgImage = context.makeImage() else {
    fatalError("Could not render the app icon.")
}
let bitmap = NSBitmapImageRep(cgImage: cgImage)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode the app icon as PNG.")
}
try png.write(to: outputURL)
