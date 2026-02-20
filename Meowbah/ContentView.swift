//
//  ContentView.swift
//  Meowbah
//
//  Created by Ryan Reid on 25/08/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = theme.palette(for: colorScheme)

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
        .tint(palette.primary)
        .accentColor(palette.primary)
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager())
}
