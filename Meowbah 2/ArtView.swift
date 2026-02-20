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

    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(palette: palette)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(fanArts) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(palette.card)
                                .overlay(
                                    ZStack {
                                        LinearGradient(colors: [palette.primary.opacity(0.25), palette.card.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
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
                                                .foregroundStyle(palette.textSecondary)
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
                                .foregroundStyle(palette.textPrimary)
                                .lineLimit(2)
                        }
                        .padding(8)
                        .background(palette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(radius: 4, y: 2)
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onTapGesture {
                            selectedFanArt = item
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
        .background(palette.background.ignoresSafeArea())
        .sheet(item: $selectedFanArt) { art in
            FanArtDetailSheet(art: art)
                .environmentObject(theme)
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func header(palette: ThemePalette) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "scribble.variable")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(palette.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Discover Art")
                    .font(.title2).bold()
                    .foregroundStyle(palette.textPrimary)
                Text("Curated kawaii illustrations and concepts")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer()
        }
    }
}

private struct FanArtDetailSheet: View {
    let art: ArtView.FanArt

    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        NavigationStack {
            ZStack {
                palette.background.ignoresSafeArea()

                GeometryReader { geo in
                    let w = max(0, geo.size.width - 32)
                    let h = max(0, geo.size.height - 32)
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(palette.card)

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
                                .foregroundStyle(palette.textSecondary)
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
            
            .navigationTitle(art.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    NavigationStack {
        ArtView()
            .environmentObject(ThemeManager())
    }
}
