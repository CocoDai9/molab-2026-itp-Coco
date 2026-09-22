//
//  ContentView.swift
//  Mobile App Dev Week3 Inclass
//
//  Created by Mingshan Dai on 9/17/26.
//

import SwiftUI

struct ContentView: View {
    @State var counter = 1
    var body: some View {
        VStack {
            Image(systemName: "apple.logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
            Text("counter \(counter)")
                .font(.system(size: 60))
            if counter > 2 {
                Image(systemName: "apple.logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            Button("Minus"){
                    counter -= 1
                    print("counter += 1 \(counter)")
                }
            .font(.system(size:60))
            Button(counter > 10?">10":"<10"){
                counter += 1
                print("counter += 1 \(counter)")
            }
            .font(.system(size:60))
        }
        .onAppear(){
        print("counter \(counter)")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
