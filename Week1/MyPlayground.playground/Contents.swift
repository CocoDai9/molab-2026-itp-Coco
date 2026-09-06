var name = "Coco"
var weeklySaving = 15
var numberOfWeeks = 5

func calculateSavings(amountPerWeek: Int, weeks: Int) -> Int {
    var total = 0

    print("\(name)'s Saving Plan")

    for week in 1...weeks {
        total += amountPerWeek
        print("Week \(week): $\(total)")
    }

    return total
}

let finalAmount = calculateSavings(
    amountPerWeek: weeklySaving,
    weeks: numberOfWeeks
)

print("\(name) saved $\(finalAmount) in total.")

// Week1 issues
// Issue: My Playground could not open because required files were missing.
// Fix: I recreated contents.xcplayground and Contents.swift.
// Coding error: Wrote some variables in int format
// Coding error fixed
