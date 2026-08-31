#!/usr/bin/env swift
import AppKit

// Renders the Kiku logo (matching docs/logo.svg) to PNGs for the app icon and in-app logo.

func cgColor(_ hex: String, alpha: CGFloat = 1) -> CGColor {
    var s = hex; if s.hasPrefix("#") { s.removeFirst() }
    var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
    return CGColor(srgbRed: CGFloat((v >> 16) & 0xFF)/255,
                   green: CGFloat((v >> 8) & 0xFF)/255,
                   blue: CGFloat(v & 0xFF)/255, alpha: alpha)
}

func thickLine(_ ctx: CGContext, _ p0: CGPoint, _ p1: CGPoint, width: CGFloat) -> CGPath {
    ctx.beginPath()
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.move(to: p0)
    ctx.addLine(to: p1)
    ctx.replacePathWithStrokedPath()
    let path = ctx.path!.copy()!
    ctx.beginPath()
    return path
}

func star(cx: CGFloat, cy: CGFloat, outer: CGFloat, inner: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let d = inner * 0.7071
    p.move(to: CGPoint(x: cx, y: cy - outer))
    p.addLine(to: CGPoint(x: cx + d, y: cy - d))
    p.addLine(to: CGPoint(x: cx + inner, y: cy))
    p.addLine(to: CGPoint(x: cx + d, y: cy + d))
    p.addLine(to: CGPoint(x: cx, y: cy + outer))
    p.addLine(to: CGPoint(x: cx - d, y: cy + d))
    p.addLine(to: CGPoint(x: cx - inner, y: cy))
    p.addLine(to: CGPoint(x: cx - d, y: cy - d))
    p.closeSubpath()
    return p
}

func drawDesign(_ ctx: CGContext) {
    // White squircle tile.
    let tile = CGPath(roundedRect: CGRect(x: 0, y: 0, width: 1024, height: 1024),
                      cornerWidth: 230, cornerHeight: 230, transform: nil)
    ctx.addPath(tile); ctx.setFillColor(cgColor("#FFFFFF")); ctx.fillPath()

    // Subtle border.
    let border = CGPath(roundedRect: CGRect(x: 2, y: 2, width: 1020, height: 1020),
                        cornerWidth: 228, cornerHeight: 228, transform: nil)
    ctx.addPath(border); ctx.setStrokeColor(cgColor("#000000", alpha: 0.06)); ctx.setLineWidth(4); ctx.strokePath()

    // Gradient "K" monogram.
    let stem = thickLine(ctx, CGPoint(x: 430, y: 312), CGPoint(x: 430, y: 712), width: 98)
    let arm  = thickLine(ctx, CGPoint(x: 474, y: 512), CGPoint(x: 686, y: 312), width: 90)
    let leg  = thickLine(ctx, CGPoint(x: 474, y: 512), CGPoint(x: 712, y: 712), width: 90)

    ctx.saveGState()
    ctx.addPath(stem); ctx.addPath(arm); ctx.addPath(leg); ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [cgColor("#9A8BF5"), cgColor("#5E4CDB")] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 300), end: CGPoint(x: 0, y: 716),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    // Sparkles.
    ctx.setFillColor(cgColor("#C9BFFB"))
    ctx.addPath(star(cx: 772, cy: 322, outer: 64, inner: 22)); ctx.fillPath()
    ctx.addPath(star(cx: 712, cy: 726, outer: 30, inner: 10)); ctx.fillPath()
}

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gctx
    let ctx = gctx.cgContext
    let scale = CGFloat(size) / 1024.0
    ctx.scaleBy(x: scale, y: scale)
    // Flip to match SVG's y-down coordinate space.
    ctx.translateBy(x: 0, y: 1024)
    ctx.scaleBy(x: 1, y: -1)
    drawDesign(ctx)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

/// A centered, padded black "K" for the menu bar (template image the system tints).
func drawMenuBar(_ ctx: CGContext) {
    ctx.setStrokeColor(cgColor("#000000"))
    let stem = thickLine(ctx, CGPoint(x: 330, y: 200), CGPoint(x: 330, y: 820), width: 160)
    let arm  = thickLine(ctx, CGPoint(x: 415, y: 510), CGPoint(x: 760, y: 200), width: 150)
    let leg  = thickLine(ctx, CGPoint(x: 415, y: 510), CGPoint(x: 800, y: 820), width: 150)
    ctx.addPath(stem); ctx.addPath(arm); ctx.addPath(leg)
    ctx.setFillColor(cgColor("#000000")); ctx.fillPath()
}

func renderMenuBar(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gctx
    let ctx = gctx.cgContext
    let scale = CGFloat(size) / 1024.0
    ctx.scaleBy(x: scale, y: scale)
    ctx.translateBy(x: 0, y: 1024)
    ctx.scaleBy(x: 1, y: -1)
    drawMenuBar(ctx)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func write(_ size: Int, to path: String) {
    try! render(size: size).write(to: URL(fileURLWithPath: path))
    print("wrote \(path) (\(size)px)")
}

func writeMenuBar(_ size: Int, to path: String) {
    try! renderMenuBar(size: size).write(to: URL(fileURLWithPath: path))
    print("wrote \(path) (\(size)px, menu bar)")
}

let root = FileManager.default.currentDirectoryPath
let iconDir = "\(root)/Kiku/Resources/Assets.xcassets/AppIcon.appiconset"
let logoDir = "\(root)/Kiku/Resources/Assets.xcassets/KikuLogo.imageset"
let menuDir = "\(root)/Kiku/Resources/Assets.xcassets/MenuBarIcon.imageset"
try? FileManager.default.createDirectory(atPath: logoDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: menuDir, withIntermediateDirectories: true)

// App icon sizes.
let icons: [(Int, String)] = [
    (16, "icon_16.png"), (32, "icon_16@2x.png"),
    (32, "icon_32.png"), (64, "icon_32@2x.png"),
    (128, "icon_128.png"), (256, "icon_128@2x.png"),
    (256, "icon_256.png"), (512, "icon_256@2x.png"),
    (512, "icon_512.png"), (1024, "icon_512@2x.png")
]
for (size, name) in icons { write(size, to: "\(iconDir)/\(name)") }

// In-app logo.
write(80, to: "\(logoDir)/kiku_logo.png")
write(160, to: "\(logoDir)/kiku_logo@2x.png")
write(240, to: "\(logoDir)/kiku_logo@3x.png")

// Menu-bar template icon.
writeMenuBar(18, to: "\(menuDir)/menubar.png")
writeMenuBar(36, to: "\(menuDir)/menubar@2x.png")
writeMenuBar(54, to: "\(menuDir)/menubar@3x.png")
print("Done.")
