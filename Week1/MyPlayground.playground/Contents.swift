var name = "Coco"
var symbols = ["*", "#", "+", "."]
var rows = 5
var columns = 8

// Generates one line of random symbols.
func generateLine(length: Int) -> String {
    var line = ""

    for _ in 0..<length {
        let randomIndex = Int.random(in: 0..<symbols.count)
        line += symbols[randomIndex]
    }

    return line
}

// Generates the complete random pattern.
func generatePattern(rowCount: Int, columnCount: Int) {
    print("\(name)'s Random Pattern")
    print()

    for rowNumber in 1...rowCount {
        let line = generateLine(length: columnCount)
        print("\(rowNumber): \(line)")
    }
}

generatePattern(rowCount: rows, columnCount: columns)

// Week 1 issues and fixes:
// Issue: "\*" caused an invalid escape-sequence error.
// Fix: I used "*" because the asterisk does not need to be escaped.
// Issue: "(name)" printed the word name instead of the variable's value.
// Fix: I used Swift string interpolation: "\(name)".
