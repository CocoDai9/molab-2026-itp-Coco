import UIKit
import PlaygroundSupport

let dim: CGFloat = 1024
let gridCount = 12
let margin: CGFloat = 96
let lineWidth: CGFloat = 5
let background = UIColor.white
let wallColor = UIColor.black
precondition(gridCount >= 2)
var walls = Array(
    repeating: [true, true, true, true],
    count: gridCount * gridCount
)
var visited = Array(
    repeating: false,
    count: gridCount * gridCount
)
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
        let isInside = x >= 0 && x < gridCount
            && y >= 0 && y < gridCount
        if isInside && !visited[y * gridCount + x] {
            choices.append(direction)
        }
    }
    if let direction = choices.randomElement() {
        let nextRow = row + dy[direction]
        let nextColumn = column + dx[direction]
        let next = nextRow * gridCount + nextColumn
        let opposite = (direction + 2) % 4
        walls[current][direction] = false
        walls[next][opposite] = false
        visited[next] = true
        stack.append(next)
    } else {
        stack.removeLast()
    }
}

walls[0][3] = false
walls[walls.count - 1][1] = false
let mazeWidth = dim - margin * 2
let cellSize = mazeWidth / CGFloat(gridCount)
let format = UIGraphicsImageRendererFormat()
format.scale = 1
format.opaque = true
format.preferredRange = .standard

let renderer = UIGraphicsImageRenderer(
    size: CGSize(width: dim, height: dim),
    format: format
)

let image = renderer.image { context in
    let ctx = context.cgContext
    background.setFill()
    context.fill(renderer.format.bounds)

    func cellRect(_ index: Int) -> CGRect {
        let row = index / gridCount
        let column = index % gridCount
        let x = margin + CGFloat(column) * cellSize
        let y = margin + CGFloat(row) * cellSize

        return CGRect(
            x: x,
            y: y,
            width: cellSize,
            height: cellSize
        )
    }

    func drawIcon(_ icon: NSString, in cell: Int) {
        let rect = cellRect(cell)
        let font = UIFont.systemFont(ofSize: cellSize * 0.62)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = icon.size(withAttributes: attributes)
        let x = rect.midX - size.width / 2
        let y = rect.midY - size.height / 2
        icon.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
    }

    ctx.setStrokeColor(wallColor.cgColor)
    ctx.setLineWidth(lineWidth)
    ctx.setLineCap(.round)

    for index in walls.indices {
        let rect = cellRect(index)
        let cellWalls = walls[index]

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
    drawIcon("🐭", in: 0)
    drawIcon("🧀", in: walls.count - 1)
}

image

let preview = UIImageView(image: image)
preview.frame = CGRect(x: 0, y: 0, width: 512, height: 512)
preview.contentMode = .scaleAspectFit
PlaygroundPage.current.liveView = preview

let data = image.pngData()
let folder = FileManager.default.urls(
    for: .documentDirectory,
    in: .userDomainMask
).first!
let fileName = "Maze1024-\(UUID().uuidString).png"
let filePath = folder.appendingPathComponent(fileName)

if let data {
    do {
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        try data.write(to: filePath)
        print("Saved PNG:\n\(filePath.path)")
    } catch {
        print("Could not save PNG: \(error.localizedDescription)")
    }
}
