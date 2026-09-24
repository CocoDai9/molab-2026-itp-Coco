import SwiftUI
import PlaygroundSupport

struct ContentView: View {
    var body: some View {
        TabView {
            ArtView().tabItem { Text("Art") }
            Text("Random Emoji Art").tabItem { Text("About") }
        }
    }
}

struct ArtView: View {
    let emojis = ["🌸", "⭐️", "❤️", "🍀"]
    @State var picture = [String]()

    var body: some View {
        VStack {
            LazyVGrid(columns: [GridItem(), GridItem(), GridItem(), GridItem()]) {
                ForEach(0..<picture.count, id: \.self) { number in
                    Text(picture[number])
                        .font(.largeTitle)
                }
            }

            Button("New Picture") {
                picture = (0..<16).map { _ in emojis.randomElement()! }
            }
        }
        .padding()
        .onAppear {
            picture = (0..<16).map { _ in emojis.randomElement()! }
        }
    }
}

PlaygroundPage.current.setLiveView(ContentView())
