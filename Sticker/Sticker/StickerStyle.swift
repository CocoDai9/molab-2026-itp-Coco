import SwiftUI

enum Style {
    static let paper = Color(red: 248/255, green: 243/255, blue: 233/255)
    static let brown = Color(red: 114/255, green: 75/255, blue: 52/255)
    static let muted = Color(red: 0.58, green: 0.57, blue: 0.56)
    static let ink = Color(red: 39/255, green: 33/255, blue: 30/255)
    static let editorMuted = Color(red: 129/255, green: 122/255, blue: 117/255)
    static let refinementProtectedTopHeight: CGFloat = 104
}


struct BrownButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 54)
            .background(Style.brown.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 9))
    }
}

