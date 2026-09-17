import UIKit
import PlaygroundSupport

let dim = 1024.0
let format = UIGraphicsImageRendererFormat()
format.scale = 1 // 1 point = 1 pixel
let renderer = UIGraphicsImageRenderer(size: CGSize(width: dim, height: dim), format: format)

let image = renderer.image { context in
    let ctx = context.cgContext
    UIColor.white.setFill()
    context.fill(renderer.format.bounds)
    ctx.setStrokeColor(UIColor.black.cgColor)
    ctx.setLineWidth(6)
    ctx.setLineCap(.round)

    // 坐标从左上角开始：x 向右增加，y 向下增加。
    // 每两行画一面墙：move 是起点，addLine 是终点。

    // 外框：左上方留入口，右下方留出口。
    ctx.move(to: CGPoint(x: 100, y: 100))
    ctx.addLine(to: CGPoint(x: 900, y: 100))

    ctx.move(to: CGPoint(x: 100, y: 200))
    ctx.addLine(to: CGPoint(x: 100, y: 900))

    ctx.move(to: CGPoint(x: 100, y: 900))
    ctx.addLine(to: CGPoint(x: 900, y: 900))

    ctx.move(to: CGPoint(x: 900, y: 100))
    ctx.addLine(to: CGPoint(x: 900, y: 800))

    // 只保留三面内部墙：从右边、左边、右边绕过去。
    ctx.move(to: CGPoint(x: 100, y: 300))
    ctx.addLine(to: CGPoint(x: 700, y: 300))

    ctx.move(to: CGPoint(x: 300, y: 500))
    ctx.addLine(to: CGPoint(x: 900, y: 500))

    ctx.move(to: CGPoint(x: 100, y: 700))
    ctx.addLine(to: CGPoint(x: 700, y: 700))

    ctx.drawPath(using: .stroke)

    // 直接指定老鼠和奶酪的位置。
    let font = UIFont.systemFont(ofSize: 48)
    ("🐭" as NSString).draw(at: CGPoint(x: 120, y: 120), withAttributes: [.font: font])
    ("🧀" as NSString).draw(at: CGPoint(x: 820, y: 820), withAttributes: [.font: font])
}

image

// 在 Playground 中显示图片。
let preview = UIImageView(image: image)
preview.frame = CGRect(x: 0, y: 0, width: 512, height: 512)
preview.contentMode = .scaleAspectFit
PlaygroundPage.current.liveView = preview

// 保存 PNG，控制台会显示文件位置。
let data = image.pngData()!
let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let filePath = folder.appendingPathComponent("Maze1024-\(UUID().uuidString).png")

do {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try data.write(to: filePath)
    print("Saved PNG: \(filePath.path)")
} catch {
    print("Could not save PNG: \(error.localizedDescription)")
}
