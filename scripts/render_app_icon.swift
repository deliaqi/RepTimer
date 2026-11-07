import AppKit
import CoreGraphics
import Foundation

let appIconSetDir = URL(fileURLWithPath: "RepTimer/Assets.xcassets/AppIcon.appiconset")
let iconBundleDir = URL(fileURLWithPath: "RepTimer/AppIcon.icon")
let iconAssetsDir = iconBundleDir.appendingPathComponent("Assets")

try FileManager.default.createDirectory(at: appIconSetDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconAssetsDir, withIntermediateDirectories: true)

// MARK: - 1. Generate Layered Icon Composer Bundle (AppIcon.icon) for iOS 26 Liquid Glass

let layer1CaseAndCrownSVG = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <!-- Top crown stem -->
  <rect x="466" y="128" width="92" height="138" rx="30" fill="#D8FF55" />
  <!-- Top crown cap -->
  <rect x="442" y="114" width="140" height="44" rx="18" fill="#E8F5C8" />
  <!-- Outer stopwatch bezel ring (r=310 outer, r=274 inner) -->
  <path fill="#E8F5C8" fill-rule="evenodd" d="M 512 214 A 310 310 0 1 0 512 834 A 310 310 0 1 0 512 214 Z M 512 250 A 274 274 0 1 1 512 798 A 274 274 0 1 1 512 250 Z" />
  <!-- Subtle inner progress track -->
  <circle cx="512" cy="524" r="252" fill="none" stroke="#E8F5C8" stroke-width="13" stroke-opacity="0.22" />
</svg>
"""

var tickLines: [String] = []
let svgCenter = CGPoint(x: 512, y: 524)
for mark in 0..<60 {
    let angle = -CGFloat.pi / 2 + CGFloat(mark) * 2 * CGFloat.pi / 60
    let isMajor = mark.isMultiple(of: 5)
    let outerRadius: CGFloat = 220
    let innerRadius: CGFloat = isMajor ? 194 : 207
    let x1 = svgCenter.x + cos(angle) * innerRadius
    let y1 = svgCenter.y + sin(angle) * innerRadius
    let x2 = svgCenter.x + cos(angle) * outerRadius
    let y2 = svgCenter.y + sin(angle) * outerRadius
    let color = isMajor ? "#E8F5C8" : "#6BE0B3"
    let opacity = isMajor ? "0.92" : "0.62"
    let width = isMajor ? 9 : 4
    tickLines.append(
        String(
            format: "  <line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" stroke=\"%@\" stroke-opacity=\"%@\" stroke-width=\"%d\" stroke-linecap=\"round\" />",
            x1, y1, x2, y2, color, opacity, width
        )
    )
}

let layer2DialTicksSVG = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
\(tickLines.joined(separator: "\n"))
</svg>
"""

let layer3IntervalArcSVG = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <!-- Active work interval arc (255 deg clockwise from 12 o'clock) -->
  <path d="M 512 272 A 252 252 0 1 1 268.59 589.22" fill="none" stroke="#D8FF55" stroke-width="18" stroke-linecap="round" />
  <!-- Secondary rest/prep interval arc segment -->
  <path d="M 260.15 515.21 A 252 252 0 0 1 434.13 284.33" fill="none" stroke="#64DEC3" stroke-width="14" stroke-linecap="round" stroke-opacity="0.85" />
</svg>
"""

let layer4HandsSVG = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <!-- Round / minute hand -->
  <line x1="512" y1="524" x2="421" y2="430" stroke="#E8F5C8" stroke-width="25" stroke-linecap="round" />
  <!-- Active interval second hand -->
  <line x1="512" y1="524" x2="625" y2="376" stroke="#D8FF55" stroke-width="20" stroke-linecap="round" />
  <!-- Center pivot cap with pinhole cutout -->
  <path fill="#D8FF55" fill-rule="evenodd" d="M 512 500 A 24 24 0 1 0 512 548 A 24 24 0 1 0 512 500 Z M 512 515 A 9 9 0 1 1 512 533 A 9 9 0 1 1 512 515 Z" />
</svg>
"""

let iconJSON = """
{
  "fill" : {
    "automatic-gradient" : "srgb:0.12000,0.21000,0.14500,1.00000"
  },
  "fill-specializations" : [
    {
      "appearance" : "dark",
      "value" : {
        "automatic-gradient" : "srgb:0.05500,0.11000,0.07500,1.00000"
      }
    }
  ],
  "groups" : [
    {
      "layers" : [
        {
          "glass" : true,
          "image-name" : "01-case-and-crown.svg",
          "name" : "Case and Crown"
        }
      ],
      "shadow" : {
        "kind" : "neutral",
        "opacity" : 0.45
      },
      "translucency" : {
        "enabled" : true,
        "value" : 0.25
      }
    },
    {
      "layers" : [
        {
          "glass" : false,
          "image-name" : "02-dial-ticks.svg",
          "name" : "Dial Ticks"
        }
      ],
      "shadow" : {
        "kind" : "neutral",
        "opacity" : 0.3
      },
      "translucency" : {
        "enabled" : true,
        "value" : 0.2
      }
    },
    {
      "layers" : [
        {
          "glass" : true,
          "image-name" : "03-interval-arc.svg",
          "name" : "Interval Arc"
        }
      ],
      "shadow" : {
        "kind" : "layer-color",
        "opacity" : 0.5
      },
      "translucency" : {
        "enabled" : true,
        "value" : 0.15
      }
    },
    {
      "layers" : [
        {
          "glass" : true,
          "image-name" : "04-hands.svg",
          "name" : "Stopwatch Hands"
        }
      ],
      "shadow" : {
        "kind" : "neutral",
        "opacity" : 0.5
      },
      "translucency" : {
        "enabled" : true,
        "value" : 0.1
      }
    }
  ],
  "supported-platforms" : {
    "circles" : [
      "watchOS"
    ],
    "squares" : "shared"
  }
}
"""

try layer1CaseAndCrownSVG.write(to: iconAssetsDir.appendingPathComponent("01-case-and-crown.svg"), atomically: true, encoding: .utf8)
try layer2DialTicksSVG.write(to: iconAssetsDir.appendingPathComponent("02-dial-ticks.svg"), atomically: true, encoding: .utf8)
try layer3IntervalArcSVG.write(to: iconAssetsDir.appendingPathComponent("03-interval-arc.svg"), atomically: true, encoding: .utf8)
try layer4HandsSVG.write(to: iconAssetsDir.appendingPathComponent("04-hands.svg"), atomically: true, encoding: .utf8)
try iconJSON.write(to: iconBundleDir.appendingPathComponent("icon.json"), atomically: true, encoding: .utf8)

// MARK: - 2. Render Fallback Adaptive PNGs in Assets.xcassets/AppIcon.appiconset

enum IconVariant {
    case light
    case dark
    case tinted
}

func renderIconVariant(_ variant: IconVariant, to outputURL: URL) throws {
    let size = 1024
    let alphaInfo: CGImageAlphaInfo = (variant == .dark) ? .premultipliedLast : .noneSkipLast
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: alphaInfo.rawValue
    ) else {
        fatalError("Could not create the app icon drawing context.")
    }

    let forest = NSColor(calibratedRed: 0.055, green: 0.11, blue: 0.075, alpha: 1)
    let deepGreen = NSColor(calibratedRed: 0.12, green: 0.21, blue: 0.145, alpha: 1)
    let faceGreen = NSColor(calibratedRed: 0.075, green: 0.145, blue: 0.10, alpha: 1)
    let lime = NSColor(calibratedRed: 0.85, green: 1.00, blue: 0.33, alpha: 1)
    let softLime = NSColor(calibratedRed: 0.91, green: 0.96, blue: 0.78, alpha: 1)
    let mint = NSColor(calibratedRed: 0.42, green: 0.82, blue: 0.70, alpha: 1)

    let white = NSColor(calibratedWhite: 0.96, alpha: 1)
    let lightGray = NSColor(calibratedWhite: 0.82, alpha: 1)
    let midGray = NSColor(calibratedWhite: 0.62, alpha: 1)
    let darkGray = NSColor(calibratedWhite: 0.14, alpha: 1)
    let deepCharcoal = NSColor(calibratedWhite: 0.07, alpha: 1)

    switch variant {
    case .light:
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
    case .dark:
        context.clear(CGRect(x: 0, y: 0, width: size, height: size))
    case .tinted:
        let background = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [darkGray.cgColor, deepCharcoal.cgColor] as CFArray,
            locations: [0, 1]
        )!
        context.drawLinearGradient(background, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
    }

    func fillRoundedRectangle(_ rect: CGRect, radius: CGFloat, color: NSColor) {
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.addPath(path)
        context.setFillColor(color.cgColor)
        context.fillPath()
    }

    let primaryAccent = (variant == .tinted) ? white : lime
    let secondaryAccent = (variant == .tinted) ? lightGray : softLime
    let tickMinorColor = (variant == .tinted) ? midGray : mint
    let dialFaceColor: NSColor = switch variant {
    case .light: faceGreen
    case .dark: NSColor(calibratedRed: 0.045, green: 0.085, blue: 0.06, alpha: 1)
    case .tinted: NSColor(calibratedWhite: 0.10, alpha: 1)
    }

    // Top pusher, tucked behind the timer body.
    fillRoundedRectangle(CGRect(x: 466, y: 758, width: 92, height: 138), radius: 30, color: primaryAccent)
    fillRoundedRectangle(CGRect(x: 442, y: 834, width: 140, height: 44), radius: 18, color: secondaryAccent)

    let center = CGPoint(x: 512, y: 500)
    let outerDial = CGRect(x: 202, y: 190, width: 620, height: 620)
    context.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: NSColor.black.withAlphaComponent(0.36).cgColor)
    context.setFillColor((variant == .dark ? primaryAccent.withAlphaComponent(0.92) : secondaryAccent).cgColor)
    context.fillEllipse(in: outerDial)
    context.setShadow(offset: .zero, blur: 0, color: nil)

    let face = CGRect(x: 238, y: 226, width: 548, height: 548)
    context.setFillColor(dialFaceColor.cgColor)
    context.fillEllipse(in: face)

    // Progress track and active arc make the stopwatch read as an interval timer.
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.14).cgColor)
    context.setLineWidth(13)
    context.strokeEllipse(in: CGRect(x: 260, y: 248, width: 504, height: 504))

    context.addArc(
        center: center,
        radius: 252,
        startAngle: .pi / 2,
        endAngle: .pi / 2 - 4.45,
        clockwise: true
    )
    context.setStrokeColor(primaryAccent.cgColor)
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
        context.setStrokeColor((isMajor ? secondaryAccent : tickMinorColor).withAlphaComponent(isMajor ? 0.92 : 0.58).cgColor)
        context.setLineWidth(isMajor ? 9 : 4)
        context.setLineCap(.round)
        context.strokePath()
    }

    // Two hands sit at different lengths to suggest a focused workout interval.
    context.setStrokeColor(secondaryAccent.cgColor)
    context.setLineWidth(25)
    context.setLineCap(.round)
    context.move(to: center)
    context.addLine(to: CGPoint(x: 421, y: 594))
    context.strokePath()

    context.setStrokeColor(primaryAccent.cgColor)
    context.setLineWidth(20)
    context.setLineCap(.round)
    context.move(to: center)
    context.addLine(to: CGPoint(x: 625, y: 648))
    context.strokePath()

    context.setFillColor(primaryAccent.cgColor)
    context.fillEllipse(in: CGRect(x: 488, y: 476, width: 48, height: 48))
    context.setFillColor(dialFaceColor.cgColor)
    context.fillEllipse(in: CGRect(x: 503, y: 491, width: 18, height: 18))

    guard let cgImage = context.makeImage() else {
        fatalError("Could not render the app icon.")
    }
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode the app icon as PNG.")
    }
    try png.write(to: outputURL)
}

try renderIconVariant(.light, to: appIconSetDir.appendingPathComponent("AppIcon.png"))
try renderIconVariant(.dark, to: appIconSetDir.appendingPathComponent("AppIcon-Dark.png"))
try renderIconVariant(.tinted, to: appIconSetDir.appendingPathComponent("AppIcon-Tinted.png"))

let contentsJSON = """
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "AppIcon-Dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "AppIcon-Tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

try contentsJSON.write(to: appIconSetDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
