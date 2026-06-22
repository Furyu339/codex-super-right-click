// 生成 Flicker 应用图标（1024x1024 PNG）。
// 用法: swift scripts/gen_icon.swift <输出png路径>
// 主题：蓝紫渐变圆角底 + 白色右键菜单面板（首项高亮）+ 鼠标光标。

import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

let S = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fputs("create context failed\n", stderr); exit(1)
}

func rounded(_ r: CGRect, _ rad: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
}

// 背景圆角方形 + 渐变
ctx.saveGState()
ctx.addPath(rounded(CGRect(x: 0, y: 0, width: S, height: S), 230))
ctx.clip()
let gradColors = [
    CGColor(red: 0.29, green: 0.44, blue: 0.98, alpha: 1.0),
    CGColor(red: 0.62, green: 0.31, blue: 0.96, alpha: 1.0)
] as CFArray
let grad = CGGradient(colorsSpace: cs, colors: gradColors, locations: [0.0, 1.0])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: CGFloat(S)),
                       end: CGPoint(x: CGFloat(S), y: 0), options: [])
ctx.restoreGState()

// 菜单面板（白，投影）
let panel = CGRect(x: 232, y: 300, width: 560, height: 460)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 64,
              color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.38))
ctx.addPath(rounded(panel, 52))
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fillPath()
ctx.restoreGState()

// 高亮首项
let highlight = CGRect(x: 264, y: 644, width: 496, height: 76)
ctx.addPath(rounded(highlight, 20))
ctx.setFillColor(CGColor(red: 0.29, green: 0.44, blue: 0.98, alpha: 1.0))
ctx.fillPath()
// 首项内容：左圆点 + 白条
ctx.addPath(rounded(CGRect(x: 288, y: 672, width: 24, height: 24), 12))
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
ctx.fillPath()
ctx.addPath(rounded(CGRect(x: 332, y: 676, width: 260, height: 16), 8))
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
ctx.fillPath()

// 分隔线
ctx.setFillColor(CGColor(red: 0.92, green: 0.93, blue: 0.95, alpha: 1.0))
ctx.fill(CGRect(x: 288, y: 616, width: 448, height: 3))
ctx.fill(CGRect(x: 288, y: 532, width: 448, height: 3))

// 其余菜单项：灰条
let rowsY: [CGFloat] = [560, 476, 392]
let rowsW: [CGFloat] = [300, 360, 240]
for (i, y) in rowsY.enumerated() {
    ctx.addPath(rounded(CGRect(x: 288, y: y, width: rowsW[i], height: 28), 14))
    ctx.setFillColor(CGColor(red: 0.83, green: 0.86, blue: 0.90, alpha: 1.0))
    ctx.fillPath()
}

// 鼠标光标（指向面板底部）
ctx.saveGState()
let s: CGFloat = 15
let ox: CGFloat = 600
let oy: CGFloat = 250
func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x*s, y: oy - y*s) }
let arrow = CGMutablePath()
arrow.move(to: pt(0, 0))
arrow.addLine(to: pt(0, 15))
arrow.addLine(to: pt(3.5, 11.5))
arrow.addLine(to: pt(5.5, 15.5))
arrow.addLine(to: pt(7, 14.5))
arrow.addLine(to: pt(5, 10.5))
arrow.addLine(to: pt(9, 10.5))
arrow.closeSubpath()
ctx.setShadow(offset: CGSize(width: 2, height: -3), blur: 10,
              color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
ctx.addPath(arrow)
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fillPath()
ctx.addPath(arrow)
ctx.setStrokeColor(CGColor(red: 0.18, green: 0.20, blue: 0.28, alpha: 1))
ctx.setLineWidth(3)
ctx.strokePath()
ctx.restoreGState()

guard let img = ctx.makeImage() else { fputs("makeImage failed\n", stderr); exit(1) }
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let outURL = URL(fileURLWithPath: outPath)
guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fputs("create dest failed\n", stderr); exit(1)
}
CGImageDestinationAddImage(dest, img, nil)
if !CGImageDestinationFinalize(dest) { fputs("finalize failed\n", stderr); exit(1) }
print("wrote \(outURL.path)")
