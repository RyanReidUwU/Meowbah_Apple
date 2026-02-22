import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ArtView: View {
    struct FanArt: Identifiable, Equatable, Hashable {
        let id: String
        let imageName: String
        let title: String
        let category: String
    }

    // Publishes the art catalog to the App Group for watch access
    private func publishArtCatalogToAppGroup(_ items: [FanArt]) {
        let payload: [[String: Any]] = items.map { item in
            [
                "id": item.id,
                "title": item.title,
                // Use category as description for now
                "description": item.category,
                // Local iOS asset name
                "imageName": item.imageName,
                // No remote URL; watch will request bytes from iPhone
                "imageURL": "",
                // Optional deep link / URL (leave empty for now)
                "url": ""
            ]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8)
        else { return }

        let defaults = UserDefaults(suiteName: "group.meowbah") ?? .standard
        defaults.set(json, forKey: "art.catalogJSON")
    }

    @State private var fanArts: [FanArt] = [
        FanArt(id: "1", imageName: "quran", title: "Meow Reads The Quran", category: "Animation"),
        FanArt(id: "2", imageName: "friends", title: "Meow and CommotionSickness", category: "Commotion"),
        FanArt(id: "3", imageName: "girlgirl", title: "HEAVY METAL LOVER Animation", category: "Animation"),
        FanArt(id: "4", imageName: "hikari", title: "Hikari from Blue Archive", category: "Blue Archive"),
        FanArt(id: "5", imageName: "meowcommotion", title: "More Meow and Commotion Shenanigans", category: "Commotion"),
        FanArt(id: "6", imageName: "mayanotopgun", title: "Mayano Top Gun from Umamusume: Pretty Derby", category: "Umasusume"),
        FanArt(id: "7", imageName: "moe", title: "Moe Art (Whatever That Means)", category: "Art"),
        FanArt(id: "8", imageName: "nyan", title: "NYAN NYAN NIHAO NYAN", category: "Animation"),
        FanArt(id: "9", imageName: "oldart", title: "Old Meowbah Art", category: "Art"),
        FanArt(id: "10", imageName: "plush", title: "Meowbah Made A Plush!!", category: "Art"),
        FanArt(id: "11", imageName: "meowgod", title: "Holy Meowgod From Above!!", category: "Art"),
        FanArt(id: "12", imageName: "meowmomo", title: "Meow and R3D Momo", category: "Momo"),
        FanArt(id: "13", imageName: "miyu", title: "Miyu from Blue Archive", category: "Blue Archive"),
        FanArt(id: "14", imageName: "refsheet", title: "Meowbah's Reference Sheet", category: "Art")
    ]

    @State private var selectedFanArt: FanArt?

#if os(tvOS)
    init() {
        #if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black

        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().standardAppearance = appearance
        if #available(tvOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        #endif
    }
#endif

    private var secondaryBG: Color {
        #if os(tvOS)
        return Color.black.opacity(0.2)
        #else
        return Color(.secondarySystemBackground)
        #endif
    }

    private var systemBG: Color {
        #if os(tvOS)
        return Color.black
        #else
        return Color(.systemBackground)
        #endif
    }

    @ViewBuilder
    private func header() -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "scribble.variable")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Discover Art")
                    .font(.title2).bold()
                    .foregroundStyle(Color.primary)

                Text("Here is some kawaii art from Meowbah (more coming soon)")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()
        }
    }

    var body: some View {
#if os(tvOS)
        ZStack {
            // Match VideosView: paint background and ignore safe areas.
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Grid (match VideosView tvOS grid pattern)
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 48),
                        GridItem(.flexible(), spacing: 48)
                    ], spacing: 48) {
                        ForEach(fanArts) { item in
                            Button {
                                selectedFanArt = item
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(secondaryBG)
                                        .overlay(
                                            ZStack {
                                                LinearGradient(
                                                    colors: [Color.primary.opacity(0.12), secondaryBG.opacity(0.2)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                                .allowsHitTesting(false)

#if canImport(UIKit)
                                                if let uiImage = UIImage(named: item.imageName) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .padding(8)
                                                } else {
                                                    Image(systemName: "photo")
                                                        .font(.system(size: 28))
                                                        .foregroundStyle(Color.secondary)
                                                        .opacity(0.15)
                                                }
#else
                                                Image(item.imageName)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .padding(8)
#endif
                                            }
                                        )
                                        .aspectRatio(1, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                    Text(item.title)
                                        .font(.headline)
                                        .foregroundStyle(Color.primary)
                                        .lineLimit(2)
                                }
                                .padding(8)
                                .background(secondaryBG)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(radius: 4, y: 2)
                                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 28)
                }
                .background(Color.black)
                .scrollClipDisabled(true)
            }
        }
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.black, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .fullScreenCover(item: $selectedFanArt) { art in
            FanArtDetailSheet(art: art)
        }
        .onAppear {
            publishArtCatalogToAppGroup(fanArts)
        }
#else
        // Non-tvOS keeps the previous layout.
        ScrollView {
            LazyVStack(spacing: 0) {
                header()
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    .background(systemBG)
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(fanArts) { item in
                        Button {
                            selectedFanArt = item
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(secondaryBG)
                                    .overlay(
                                        ZStack {
                                            LinearGradient(
                                                colors: [Color.primary.opacity(0.12), secondaryBG.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                            .allowsHitTesting(false)

#if canImport(UIKit)
                                            if let uiImage = UIImage(named: item.imageName) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .padding(8)
                                            } else {
                                                Image(systemName: "photo")
                                                    .font(.system(size: 28))
                                                    .foregroundStyle(Color.secondary)
                                                    .opacity(0.15)
                                            }
#else
                                            Image(item.imageName)
                                                .resizable()
                                                .scaledToFit()
                                                .padding(8)
#endif
                                        }
                                    )
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                Text(item.title)
                                    .font(.headline)
                                    .foregroundStyle(Color.primary)
                                    .lineLimit(2)
                            }
                            .padding(8)
                            .background(secondaryBG)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(radius: 4, y: 2)
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
        }
        .background(systemBG.ignoresSafeArea())
        .sheet(item: $selectedFanArt) { art in
            FanArtDetailSheet(art: art)
#if os(iOS)
            #if targetEnvironment(macCatalyst)
            .presentationDragIndicator(.hidden)
            #else
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            #endif
#endif
        }
        .onAppear {
            publishArtCatalogToAppGroup(fanArts)
        }
#endif
    }
}

private struct FanArtDetailSheet: View {
    let art: ArtView.FanArt

    @Environment(\.dismiss) private var dismiss

    private var secondaryBG: Color {
        #if os(tvOS)
        return Color.black.opacity(0.2)
        #else
        return Color(.secondarySystemBackground)
        #endif
    }

    var body: some View {
        NavigationStack {
            ZStack {
#if os(tvOS)
                Color.black.ignoresSafeArea()
#else
                Color(.systemBackground).ignoresSafeArea()
#endif

                GeometryReader { geo in
                    let w = max(0, geo.size.width - 32)
                    let h = max(0, geo.size.height - 32)
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(secondaryBG)

#if canImport(UIKit)
                        if let uiImage = UIImage(named: art.imageName) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .padding(12)
                                .frame(width: w, height: h)
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 44))
                                .foregroundStyle(Color.secondary)
                                .opacity(0.25)
                        }
#else
                        Image(art.imageName)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                            .frame(width: w, height: h)
#endif
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
#if !os(tvOS)
            #if targetEnvironment(macCatalyst)
            .navigationTitle("Art")
            #else
            .navigationTitle(art.title)
            #endif
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                    #if targetEnvironment(macCatalyst)
                    .keyboardShortcut(.cancelAction)
                    #endif
                }
                ToolbarItem(placement: .primaryAction) {
#if canImport(UIKit)
                    if let uiImage = UIImage(named: art.imageName) {
                        ShareLink(item: Image(uiImage: uiImage), preview: SharePreview(art.title, image: Image(uiImage: uiImage))) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        ShareLink(item: art.title) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
#else
                    ShareLink(item: art.title) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
#endif
                }
            }
#endif
        }
    }
}

#Preview {
    NavigationStack {
        ArtView()
    }
}
