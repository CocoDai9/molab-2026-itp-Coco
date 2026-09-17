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

    // 内部横墙：缺口交替在右边和左边，形成曲折的通路。
    ctx.move(to: CGPoint(x: 100, y: 200))
    ctx.addLine(to: CGPoint(x: 800, y: 200))

    ctx.move(to: CGPoint(x: 200, y: 300))
    ctx.addLine(to: CGPoint(x: 900, y: 300))

    ctx.move(to: CGPoint(x: 100, y: 400))
    ctx.addLine(to: CGPoint(x: 800, y: 400))

    ctx.move(to: CGPoint(x: 200, y: 500))
    ctx.addLine(to: CGPoint(x: 900, y: 500))

    ctx.move(to: CGPoint(x: 100, y: 600))
    ctx.addLine(to: CGPoint(x: 800, y: 600))

    ctx.move(to: CGPoint(x: 200, y: 700))
    ctx.addLine(to: CGPoint(x: 900, y: 700))

    ctx.move(to: CGPoint(x: 100, y: 800))
    ctx.addLine(to: CGPoint(x: 800, y: 800))

    // 短墙：增加转弯，但留下足够空间通过。
    ctx.move(to: CGPoint(x: 400, y: 100))
    ctx.addLine(to: CGPoint(x: 400, y: 150))

    ctx.move(to: CGPoint(x: 600, y: 300))
    ctx.addLine(to: CGPoint(x: 600, y: 250))

    ctx.move(to: CGPoint(x: 400, y: 400))
    ctx.addLine(to: CGPoint(x: 400, y: 350))

    ctx.move(to: CGPoint(x: 600, y: 500))
    ctx.addLine(to: CGPoint(x: 600, y: 450))

    ctx.move(to: CGPoint(x: 400, y: 600))
    ctx.addLine(to: CGPoint(x: 400, y: 550))

    ctx.move(to: CGPoint(x: 600, y: 700))
    ctx.addLine(to: CGPoint(x: 600, y: 650))

    ctx.move(to: CGPoint(x: 400, y: 800))
    ctx.addLine(to: CGPoint(x: 400, y: 750))

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
