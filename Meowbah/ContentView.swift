//
//  ContentView.swift
//  Meowbah
//
//  Created by Ryan Reid on 25/08/2025.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TabView {
            VideosView()
                .tabItem {
                    Image(systemName: "play.rectangle.fill")
                    Text("Videos")
                }

            // Temporarily hidden Fan Art tab for testing.
            // To restore, uncomment this block.
            /*
            FanArtView()
                .tabItem {
                    Image(systemName: "paintpalette.fill")
                    Text("Fan Art")
                }
            */
        }
        .background(Color.clear)      // ensure TabView doesn't paint a bg
    }
}

#Preview {
    ContentView()
}
