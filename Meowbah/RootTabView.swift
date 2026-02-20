import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        TabView {
            NavigationStack { VideosView() }
                .tabItem {
                    Label("Videos", systemImage: "play.rectangle.fill")
                }

            NavigationStack { MerchView() }
                .tabItem {
                    Label("Merch", systemImage: "bag.fill")
                }

            NavigationStack { ArtView() }
                .tabItem {
                    Label("Art", systemImage: "paintpalette.fill")
                }

            NavigationStack { MeowTalkView() }
                .tabItem {
                    Label("MeowTalk", systemImage: "message.fill")
                }
        }
        .tint(palette.primary)
        .background(palette.background.ignoresSafeArea())
    }
}

#Preview {
    RootTabView()
        .environmentObject(ThemeManager())
}
