//
//  ContentView.swift
//  SixthSense
//
//  Created by Shreepa Parthaje on 3/23/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            ViewContainer()
                .edgesIgnoringSafeArea(.all)
        }
    }
}

#Preview {
    ContentView()
}
