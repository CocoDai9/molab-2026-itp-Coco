import Foundation

var name = "Coco"
var weeklySaving = 15.0
var savingsGoal = 100.0
var numberOfWeeks = 8

// Creates a text progress bar.
func makeProgressBar(current: Double, goal: Double) -> String {
    let barLength = 10
    let progress = min(current / goal, 1.0)
    let filledLength = Int(progress * Double(barLength))
    let emptyLength = barLength - filledLength

    let filledPart = String(repeating: "#", count: filledLength)
    let emptyPart = String(repeating: "-", count: emptyLength)

    return "[\(filledPart)\(emptyPart)]"
}

// Calculates and displays the savings plan.
func runSavingsPlan(
    person: String,
    weeklyAmount: Double,
    goal: Double,
    weeks: Int
) {
    // Issue handled: zero or negative values would make the calculation invalid.
    guard goal > 0, weeks > 0, weeklyAmount >= 0 else {
        print("Error: Goal and weeks must be greater than zero.")
        return
    }

    var total = 0.0

    print("\(person)'s Saving Plan")
    print("Goal: $\(Int(goal))")
    print()

    for week in 1...weeks {
        var deposit = weeklyAmount

        // Coco saves an extra $5 every fourth week.
        if week % 4 == 0 {
            deposit += 5
        }

        total += deposit

        let percentage = min((total / goal) * 100, 100)
        let progressBar = makeProgressBar(current: total, goal: goal)

        print(
            "Week \(week): deposited $\(Int(deposit)), " +
            "total $\(Int(total)) \(progressBar) " +
            "\(Int(percentage))%"
        )
    }

    print()

    if total >= goal {
        print("\(person) reached the saving goal!")
    } else {
        let remaining = goal - total
        print("\(person) still needs to save $\(Int(remaining)).")
    }
}

runSavingsPlan(
    person: name,
    weeklyAmount: weeklySaving,
    goal: savingsGoal,
    weeks: numberOfWeeks
)
