import SwiftUI

struct ContentView: View {
    let emojis = ["🌸", "🌷", "🌹", "🍀"]
    @State var picture = [String]()

    var body: some View {
        VStack {
            LazyVGrid(columns: [GridItem(), GridItem(), GridItem(), GridItem()]) {
                ForEach(0..<picture.count, id: \.self) { number in
                    Text(picture[number])
                        .font(.largeTitle)
                }
            }
            Button("New Garden") {
                picture = (0..<16).map { _ in emojis.randomElement()! }
            }
        }
        .padding()
        .onAppear {
            picture = (0..<16).map { _ in emojis.randomElement()! }
        }
    }
}

#Preview {
    ContentView()
}
