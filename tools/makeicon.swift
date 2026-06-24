import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments[1]
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
// 绿色渐变背景
let grad = NSGradient(colors: [
    NSColor(red: 0.26, green: 0.74, blue: 0.45, alpha: 1),
    NSColor(red: 0.10, green: 0.52, blue: 0.33, alpha: 1),
])!
grad.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)
// 中心叉勺 emoji
let glyph = "🍴" as NSString
let para = NSMutableParagraphStyle(); para.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 560),
    .paragraphStyle: para,
]
let ts = glyph.size(withAttributes: attrs)
glyph.draw(in: NSRect(x: (size - ts.width)/2, y: (size - ts.height)/2, width: ts.width, height: ts.height),
           withAttributes: attrs)
img.unlockFocus()
guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
