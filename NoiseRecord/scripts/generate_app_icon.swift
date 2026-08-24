#!/usr/bin/env swift
import AppKit
import CoreGraphics
import ImageIO

enum IconVariant {
    case standard
    case dark
    case tinted

    var background: NSColor {
        switch self {
        case .standard, .dark: return NSColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1)
        case .tinted: return NSColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1)
        }
    }

    var gaugeColors: [(CGFloat, CGFloat, CGFloat)] {
        switch self {
        case .tinted:
            return [
                (0.50, 0.50, 0.52),
                (0.68, 0.68, 0.70),
                (0.86, 0.86, 0.88),
            ]
        default:
            return [
                (0.12, 0.88, 0.38),
                (0.98, 0.86, 0.12),
                (0.98, 0.45, 0.10),
                (0.96, 0.18, 0.18),
            ]
        }
    }

    var barRGB: (CGFloat, CGFloat, CGFloat) {
        switch self {
        case .tinted: return (0.78, 0.78, 0.80)
        default: return (0.10, 0.90, 0.42)
        }
    }

    var textRGB: (CGFloat, CGFloat, CGFloat) { (1, 1, 1) }
    var needleRGB: (CGFloat, CGFloat, CGFloat) { (0.94, 0.94, 0.96) }
}

func rgbColor(_ rgb: (CGFloat, CGFloat, CGFloat), alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: alpha)
}

func drawBackground(in ctx: CGContext, variant: IconVariant, size: CGFloat) {
    ctx.setFillColor(variant.background.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
}

/// Semicircular SPL gauge with green → red gradient arc.
func drawGauge(in ctx: CGContext, size: CGFloat, variant: IconVariant) {
    let center = CGPoint(x: size * 0.5, y: size * 0.52)
    let radius = size * 0.36
    let lineWidth = size * 0.075
    let startAngle = CGFloat.pi
    let endAngle: CGFloat = 0
    let segments = 120
    let colors = variant.gaugeColors

    for i in 0..<segments {
        let t0 = CGFloat(i) / CGFloat(segments)
        let t1 = CGFloat(i + 1) / CGFloat(segments)
        let a0 = startAngle + (endAngle - startAngle) * t0
        let a1 = startAngle + (endAngle - startAngle) * t1

        let color = interpolateRGB(colors, at: t0 + (t1 - t0) * 0.5)
        let path = CGMutablePath()
        path.addArc(center: center, radius: radius, startAngle: a0, endAngle: a1, clockwise: true)
        ctx.saveGState()
        ctx.setStrokeColor(rgbColor(color))
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.butt)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // Subtle outer glow on the green side
    if variant != .tinted {
        let glowPath = CGMutablePath()
        glowPath.addArc(center: center, radius: radius + lineWidth * 0.35, startAngle: .pi * 0.92, endAngle: .pi * 0.55, clockwise: true)
        ctx.saveGState()
        ctx.setStrokeColor(rgbColor(0.10, 0.95, 0.45, alpha: 0.35))
        ctx.setLineWidth(lineWidth * 0.55)
        ctx.setLineCap(.round)
        ctx.addPath(glowPath)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // Needle — points into the green / low-yellow zone (reference layout).
    let needleAngle = CGFloat.pi * 0.78
    let needleTip = CGPoint(
        x: center.x + cos(needleAngle) * radius * 0.92,
        y: center.y + sin(needleAngle) * radius * 0.92
    )
    ctx.saveGState()
    ctx.setStrokeColor(rgbColor(variant.needleRGB))
    ctx.setLineWidth(size * 0.014)
    ctx.setLineCap(.round)
    ctx.move(to: center)
    ctx.addLine(to: needleTip)
    ctx.strokePath()
    ctx.setFillColor(rgbColor(variant.needleRGB))
    ctx.fillEllipse(in: CGRect(
        x: center.x - size * 0.018,
        y: center.y - size * 0.018,
        width: size * 0.036,
        height: size * 0.036
    ))
    ctx.restoreGState()
}

func interpolateRGB(_ colors: [(CGFloat, CGFloat, CGFloat)], at t: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
    guard colors.count > 1 else { return colors.first ?? (1, 1, 1) }
    let scaled = max(0, min(1, t)) * CGFloat(colors.count - 1)
    let index = min(Int(floor(scaled)), colors.count - 2)
    let fraction = scaled - CGFloat(index)
    let a = colors[index]
    let b = colors[index + 1]
    return (
        a.0 + (b.0 - a.0) * fraction,
        a.1 + (b.1 - a.1) * fraction,
        a.2 + (b.2 - a.2) * fraction
    )
}

func rgbColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

/// Green spectrum bars flanking the hero "dB" label.
func drawSpectrumBars(in ctx: CGContext, size: CGFloat, variant: IconVariant, around textRect: CGRect) {
    let barWidth = size * 0.028
    let gap = size * 0.014
    let baseY = textRect.midY - size * 0.055
    let heights: [CGFloat] = [0.42, 0.68, 0.95, 0.72, 0.48]
    let maxBarHeight = size * 0.11

    func drawSide(left: Bool) {
        let count = heights.count
        let totalWidth = CGFloat(count) * barWidth + CGFloat(count - 1) * gap
        let startX = left
            ? textRect.minX - size * 0.04 - totalWidth
            : textRect.maxX + size * 0.04
        for (index, scale) in heights.enumerated() {
            let x = startX + CGFloat(index) * (barWidth + gap)
            let h = maxBarHeight * scale
            let rect = CGRect(x: x, y: baseY, width: barWidth, height: h)
            let path = CGPath(roundedRect: rect, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil)
            ctx.setFillColor(rgbColor(variant.barRGB))
            ctx.addPath(path)
            ctx.fillPath()
        }
    }

    drawSide(left: true)
    drawSide(left: false)
}

func drawDBLabel(in ctx: CGContext, size: CGFloat, variant: IconVariant) -> CGRect {
    let text = "dB" as NSString
    let fontSize = size * 0.34
    let font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(srgbRed: variant.textRGB.0, green: variant.textRGB.1, blue: variant.textRGB.2, alpha: 1),
        .kern: -fontSize * 0.03,
    ]
    let textSize = text.size(withAttributes: attributes)
    let origin = CGPoint(
        x: (size - textSize.width) / 2,
        y: size * 0.14
    )
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx
    text.draw(at: origin, withAttributes: attributes)
    NSGraphicsContext.restoreGraphicsState()
    return CGRect(origin: origin, size: textSize)
}

func renderIcon(variant: IconVariant, size: Int = 1024) -> CGImage {
    let dimension = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Failed to create bitmap context")
    }

    drawBackground(in: ctx, variant: variant, size: dimension)
    drawGauge(in: ctx, size: dimension, variant: variant)
    let textRect = drawDBLabel(in: ctx, size: dimension, variant: variant)
    drawSpectrumBars(in: ctx, size: dimension, variant: variant, around: textRect)

    guard let image = ctx.makeImage() else {
        fatalError("Failed to make CGImage")
    }
    return image
}

func savePNG(_ image: CGImage, to path: String) throws {
    let url = URL(fileURLWithPath: path)
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        "public.png" as CFString,
        1,
        nil
    ) else {
        throw NSError(domain: "icon", code: 1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "icon", code: 2)
    }
}

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "/Users/rock/Documents/Code/noise-record/NoiseRecord/NoiseRecord/Assets.xcassets/AppIcon.appiconset"

try savePNG(renderIcon(variant: .standard), to: "\(outDir)/AppIcon.png")
try savePNG(renderIcon(variant: .dark), to: "\(outDir)/AppIcon-Dark.png")
try savePNG(renderIcon(variant: .tinted), to: "\(outDir)/AppIcon-Tinted.png")

print("Wrote AppIcon.png, AppIcon-Dark.png, AppIcon-Tinted.png to \(outDir)")
