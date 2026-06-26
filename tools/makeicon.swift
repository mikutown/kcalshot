import AppKit

// KcalShot 图标：相机 + 食物（煎蛋）结合
let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"

func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                          colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: size, height: size)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
ctx.setAllowsAntialiasing(true)
ctx.interpolationQuality = .high

// ---- 背景：清新绿色渐变 ----
let bg = NSGradient(colors: [col(70, 205, 120), col(20, 150, 86)])!
bg.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)

// 顶部柔光
let glow = NSGradient(colors: [col(255, 255, 255, 0.18), col(255, 255, 255, 0)])!
glow.draw(in: NSRect(x: 0, y: size*0.45, width: size, height: size*0.55), angle: -90)

let cx = size/2

// ---- 相机机身 ----
let bodyW: CGFloat = size*0.66
let bodyH: CGFloat = size*0.50
let bodyX = (size - bodyW)/2
let bodyY = size*0.25
let bodyRect = NSRect(x: bodyX, y: bodyY, width: bodyW, height: bodyH)
let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: size*0.085, yRadius: size*0.085)

// 机身投影
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -size*0.012), blur: size*0.05,
              color: col(0, 60, 30, 0.30).cgColor)
col(252, 253, 252).setFill()
bodyPath.fill()
ctx.restoreGState()

// 机身轻微竖向渐变
ctx.saveGState()
bodyPath.addClip()
let bodyGrad = NSGradient(colors: [col(255, 255, 255), col(232, 240, 235)])!
bodyGrad.draw(in: bodyRect, angle: -90)
ctx.restoreGState()

// ---- 顶部取景器凸起 ----
let humpW = bodyW*0.30
let humpH = size*0.058
let humpRect = NSRect(x: bodyX + bodyW*0.10, y: bodyY + bodyH - humpH*0.45,
                      width: humpW, height: humpH)
let humpPath = NSBezierPath(roundedRect: humpRect, xRadius: humpH*0.45, yRadius: humpH*0.45)
col(252, 253, 252).setFill()
humpPath.fill()

// ---- 快门按钮 ----
let shutterRect = NSRect(x: bodyX + bodyW*0.70, y: bodyY + bodyH - humpH*0.30,
                         width: bodyW*0.16, height: humpH*0.7)
let shutterPath = NSBezierPath(roundedRect: shutterRect, xRadius: humpH*0.30, yRadius: humpH*0.30)
col(245, 170, 70).setFill()
shutterPath.fill()

// ---- 闪光灯 ----
let flash = NSBezierPath(ovalIn: NSRect(x: bodyX + bodyW*0.135, y: bodyY + bodyH*0.70,
                                        width: size*0.05, height: size*0.05))
col(150, 210, 180).setFill()
flash.fill()

// ---- 镜头 ----
let lensCx = cx
let lensCy = bodyY + bodyH*0.46
let lensR: CGFloat = bodyH*0.40

func circle(_ r: CGFloat, _ fill: NSColor) {
    let p = NSBezierPath(ovalIn: NSRect(x: lensCx - r, y: lensCy - r, width: r*2, height: r*2))
    fill.setFill(); p.fill()
}

// 镜头外圈（深色相机环）
circle(lensR, col(38, 50, 46))
circle(lensR*0.90, col(70, 86, 80))
// 盘子（浅色）
circle(lensR*0.80, col(245, 247, 244))

// ---- 食物：煎蛋（裁进盘子内）----
ctx.saveGState()
NSBezierPath(ovalIn: NSRect(x: lensCx - lensR*0.80, y: lensCy - lensR*0.80,
                            width: lensR*1.60, height: lensR*1.60)).addClip()
// 蛋白（不规则圆）
let white = NSBezierPath()
let whiteR = lensR*0.70
let pts = 14
for i in 0...pts {
    let ang = CGFloat(i)/CGFloat(pts) * .pi * 2
    let wob = 1 + 0.10*sin(ang*3 + 0.6) + 0.06*cos(ang*5)
    let x = lensCx + cos(ang)*whiteR*wob
    let y = lensCy + sin(ang)*whiteR*wob
    if i == 0 { white.move(to: NSPoint(x: x, y: y)) }
    else { white.line(to: NSPoint(x: x, y: y)) }
}
white.close()
col(255, 255, 255).setFill()
white.fill()
ctx.restoreGState()

// 蛋黄
let yolkR = lensR*0.34
let yolkRect = NSRect(x: lensCx - yolkR, y: lensCy - yolkR, width: yolkR*2, height: yolkR*2)
let yolkGrad = NSGradient(colors: [col(255, 200, 60), col(245, 150, 30)])!
ctx.saveGState()
NSBezierPath(ovalIn: yolkRect).addClip()
yolkGrad.draw(in: yolkRect, angle: -90)
ctx.restoreGState()

// 蛋黄高光（兼作镜头反光）
let glint = NSBezierPath(ovalIn: NSRect(x: lensCx - yolkR*0.55, y: lensCy + yolkR*0.05,
                                        width: yolkR*0.55, height: yolkR*0.45))
col(255, 255, 255, 0.85).setFill()
glint.fill()

// ---- 绿叶点缀（健康） ----
ctx.saveGState()
let leaf = NSBezierPath()
let lx = lensCx + lensR*0.55
let ly = lensCy + lensR*0.62
leaf.move(to: NSPoint(x: lx, y: ly))
leaf.curve(to: NSPoint(x: lx + size*0.085, y: ly + size*0.085),
           controlPoint1: NSPoint(x: lx + size*0.01, y: ly + size*0.06),
           controlPoint2: NSPoint(x: lx + size*0.05, y: ly + size*0.085))
leaf.curve(to: NSPoint(x: lx, y: ly),
           controlPoint1: NSPoint(x: lx + size*0.085, y: ly + size*0.03),
           controlPoint2: NSPoint(x: lx + size*0.06, y: ly + size*0.005))
leaf.close()
col(86, 190, 110).setFill()
leaf.fill()
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
