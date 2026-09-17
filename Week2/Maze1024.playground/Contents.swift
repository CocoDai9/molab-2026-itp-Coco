import UIKit
import PlaygroundSupport

let dim = 1024.0
let format = UIGraphicsImageRendererFormat()
format.scale = 1
let renderer = UIGraphicsImageRenderer(size: CGSize(width: dim, height: dim), format: format)

let image = renderer.image { context in
    let ctx = context.cgContext
    UIColor.white.setFill()
    context.fill(renderer.format.bounds)
    ctx.setStrokeColor(UIColor.black.cgColor)
    ctx.setLineWidth(6)
    ctx.setLineCap(.round)

    ctx.move(to: CGPoint(x: 100, y: 100))
    ctx.addLine(to: CGPoint(x: 900, y: 100))

    ctx.move(to: CGPoint(x: 100, y: 200))
    ctx.addLine(to: CGPoint(x: 100, y: 900))

    ctx.move(to: CGPoint(x: 100, y: 900))
    ctx.addLine(to: CGPoint(x: 900, y: 900))

    ctx.move(to: CGPoint(x: 900, y: 100))
    ctx.addLine(to: CGPoint(x: 900, y: 800))

    ctx.move(to: CGPoint(x: 100, y: 300))
    ctx.addLine(to: CGPoint(x: 700, y: 300))

    ctx.move(to: CGPoint(x: 300, y: 500))
    ctx.addLine(to: CGPoint(x: 900, y: 500))

    ctx.move(to: CGPoint(x: 100, y: 700))
    ctx.addLine(to: CGPoint(x: 700, y: 700))

    ctx.drawPath(using: .stroke)

    let font = UIFont.systemFont(ofSize: 48)
    ("🐭" as NSString).draw(at: CGPoint(x: 120, y: 120), withAttributes: [.font: font])
    ("🧀" as NSString).draw(at: CGPoint(x: 820, y: 820), withAttributes: [.font: font])
}

image

let preview = UIImageView(image: image)
preview.frame = CGRect(x: 0, y: 0, width: 512, height: 512)
preview.contentMode = .scaleAspectFit
PlaygroundPage.current.liveView = preview

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
