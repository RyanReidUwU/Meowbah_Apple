import SwiftUI

struct RootTabView: View {

    var body: some View {
#if os(tvOS)
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                if #available(tvOS 16.0, *) {
                    TabView {
                        NavigationStack { VideosView() }
                            .tabItem { Label("Videos", systemImage: "play.rectangle.fill") }

                        NavigationStack { ArtView() }
                            .tabItem { Label("Art", systemImage: "paintpalette.fill") }
                    }
                    // Best-effort: keep the native tab bar visible on tvOS.
                    .toolbar(.visible, for: .tabBar)
                    .toolbarBackground(.visible, for: .tabBar)
                } else {
                    TabView {
                        NavigationStack { VideosView() }
                            .tabItem { Label("Videos", systemImage: "play.rectangle.fill") }

                        NavigationStack { ArtView() }
                            .tabItem { Label("Art", systemImage: "paintpalette.fill") }
                    }
                }
            }
        }
#else
        TabView {
            NavigationStack { VideosView() }
                .tabItem { Label("Videos", systemImage: "play.rectangle.fill") }

            #if !os(tvOS)
            NavigationStack { MerchView() }
                .tabItem { Label("Merch", systemImage: "bag.fill") }
            #endif

            NavigationStack { ArtView() }
                .tabItem { Label("Art", systemImage: "paintpalette.fill") }

            #if !os(tvOS)
            NavigationStack { MeowTalkView() }
                .tabItem { Label("MeowTalk", systemImage: "message.fill") }
            #endif
        }
#if os(iOS)
        .background(Color(UIColor.systemBackground))
        .ignoresSafeArea()
#elseif os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        .ignoresSafeArea()
#else
        .background(Color.clear)
        .ignoresSafeArea()
#endif
#endif
    }
}

#Preview {
    RootTabView()
}
