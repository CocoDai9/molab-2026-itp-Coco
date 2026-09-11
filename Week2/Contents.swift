//: # Help the Mouse Find the Cheese — 1024 × 1024
//: Uses UIGraphicsImageRenderer, Core Graphics walls, and PNG export.
//: Inspired by https://github.com/molab-itp/01-UIRender-playground
//: Run this iOS playground in Xcode to make a new solvable maze.

import UIKit
import PlaygroundSupport

// MARK: - Customize
let dim: CGFloat = 1024
let gridCount = 12  // More cells make a harder maze. Use at least 2.
let margin: CGFloat = 96
let lineWidth: CGFloat = 5
let background = UIColor(red: 1.00, green: 0.98, blue: 0.92, alpha: 1)
let wallColor = UIColor(red: 0.13, green: 0.23, blue: 0.26, alpha: 1)

// Make connected passages by visiting each cell once.
// Wall order: top, right, bottom, left.
precondition(gridCount >= 2)
var walls = Array(repeating: [true, true, true, true], count: gridCount * gridCount)
var visited = Array(repeating: false, count: gridCount * gridCount)
var stack = [0]
let dx = [0, 1, 0, -1]
let dy = [-1, 0, 1, 0]
visited[0] = true

while let current = stack.last {
    let row = current / gridCount
    let column = current % gridCount
    var choices: [Int] = []
    for direction in 0..<4 {
        let x = column + dx[direction]
        let y = row + dy[direction]
        if x >= 0 && x < gridCount && y >= 0 && y < gridCount {
            if !visited[y * gridCount + x] {
                choices.append(direction)
            }
        }
    }
    if let direction = choices.randomElement() {
        let next = (row + dy[direction]) * gridCount + column + dx[direction]
        walls[current][direction] = false
        walls[next][(direction + 2) % 4] = false
        visited[next] = true
        stack.append(next)
    } else {
        stack.removeLast()
    }
}
walls[0][3] = false                 // Entrance.
walls[walls.count - 1][1] = false    // Exit.

let cellSize = (dim - margin * 2) / CGFloat(gridCount)

// Explicit scale ensures exactly 1024 × 1024 pixels, including on Retina.
let format = UIGraphicsImageRendererFormat()
format.scale = 1
format.opaque = true
format.preferredRange = .standard
let renderer = UIGraphicsImageRenderer(
    size: CGSize(width: dim, height: dim), format: format
)

var image = renderer.image { (context) in
    let ctx = context.cgContext
    let box = renderer.format.bounds
    background.setFill()
    context.fill(box)

    func cellRect(_ index: Int) -> CGRect {
        CGRect(x: margin + CGFloat(index % gridCount) * cellSize,
               y: margin + CGFloat(index / gridCount) * cellSize,
               width: cellSize, height: cellSize)
    }

    func drawCentered(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let origin = CGPoint(x: rect.midX - size.width / 2,
                             y: rect.midY - size.height / 2)
        (text as NSString).draw(at: origin, withAttributes: attributes)
    }

    drawCentered("HELP THE MOUSE FIND THE CHEESE",
                 in: CGRect(x: 0, y: 20, width: dim, height: 48),
                 font: .systemFont(ofSize: 26, weight: .bold), color: wallColor)

    // Soft highlights mark the start and goal without covering their walls.
    UIColor(red: 0.80, green: 0.93, blue: 0.86, alpha: 1).setFill()
    context.fill(cellRect(0).insetBy(dx: 4, dy: 4))
    UIColor(red: 1.00, green: 0.89, blue: 0.57, alpha: 1).setFill()
    context.fill(cellRect(walls.count - 1).insetBy(dx: 4, dy: 4))

    ctx.setStrokeColor(wallColor.cgColor)
    ctx.setLineWidth(lineWidth)
    ctx.setLineCap(.round)
    for index in walls.indices {
        let rect = cellRect(index)
        let cellWalls = walls[index]
        // Draw shared walls once: top/left, plus bottom/right outer edges.
        if cellWalls[0] {
            ctx.move(to: CGPoint(x: rect.minX, y: rect.minY))
            ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        if cellWalls[3] {
            ctx.move(to: CGPoint(x: rect.minX, y: rect.minY))
            ctx.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        if index / gridCount == gridCount - 1 && cellWalls[2] {
            ctx.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        if index % gridCount == gridCount - 1 && cellWalls[1] {
            ctx.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
    }
    ctx.drawPath(using: .stroke)

    // System emoji are drawn into the exported PNG; no image files needed.
    let iconFont = UIFont.systemFont(ofSize: cellSize * 0.62)
    drawCentered("🐭", in: cellRect(0), font: iconFont, color: wallColor)
    drawCentered("🧀", in: cellRect(walls.count - 1), font: iconFont, color: wallColor)

}

// Inspect this value using the playground's Quick Look button.
image
precondition(image.cgImage?.width == 1024 && image.cgImage?.height == 1024,
             "The exported image must be exactly 1024 × 1024 pixels.")

// Display a smaller preview without changing the exported image dims.
let preview = UIImageView(image: image)
preview.frame = CGRect(x: 0, y: 0, width: 512, height: 512)
preview.contentMode = .scaleAspectFit
PlaygroundPage.current.liveView = preview

// Get the image as PNG data and write it to the Documents folder.
let data = image.pngData()
let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let filePath = folder.appendingPathComponent("Maze1024-\(UUID().uuidString).png")

if let data = data {
    do {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: filePath)
        print("Saved 1024 × 1024 PNG:\n\(filePath.path)")
    } catch {
        print("Could not save PNG: \(error.localizedDescription)")
    }
} else {
    print("Could not encode PNG.")
}
