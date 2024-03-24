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
            Image("eye")
                .resizable()
                .foregroundStyle(.tint)
                .aspectRatio(contentMode: .fit)
                .frame(width: 25)
            Text("SixthSense")
            ViewContainer()
                .edgesIgnoringSafeArea(.all)
        }
    }
}

#Preview {
    ContentView()
}
