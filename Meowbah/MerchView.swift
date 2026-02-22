//
//  MerchView.swift
//  Meowbah
//
//  Created by Ryan Reid on 20/02/2026.
//


import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Platform-safe system colors
private enum PlatformColors {
    static var systemBackground: Color {
        #if os(tvOS)
        return Color.black
        #elseif canImport(UIKit)
        return Color(UIColor.systemBackground)
        #else
        return Color(.windowBackgroundColor)
        #endif
    }

    static var secondaryBackground: Color {
        #if os(tvOS)
        return Color.black.opacity(0.22)
        #elseif canImport(UIKit)
        return Color(UIColor.secondarySystemBackground)
        #else
        return Color.gray.opacity(0.15)
        #endif
    }
}

struct MerchView: View {

    struct MerchItem: Identifiable, Equatable, Hashable {
        let id: String
        let name: String
        let description: String
        let price: String
        let imageName: String
        let storeUrl: String

        var storeURL: URL? {
            URL(string: storeUrl.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    @State private var merchItems: [MerchItem] = SampleMerchData.items

    @State private var selectedMerch: MerchItem?
    @State private var selectedFilter: String? = "All"

    private static let presetFilters: [String] = [
        "All",
        "Hoodies",
        "Sweatshirts",
        "Jackets",
        "Shirts",
        "Posters",
        "Stickers",
        "Mugs & Cups",
        "Cases",
        "Notebooks & Journals",
        "Pins & Patches",
        "Magnets",
        "Blankets",
        "Pillows",
        "Flags",
        "Keychains",
        "Other"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header()
                aiFiltersBar()

                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(filteredItems) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(PlatformColors.secondaryBackground)
                                .overlay(
                                    ZStack {
                                        LinearGradient(
                                            colors: [Color.primary.opacity(0.15), PlatformColors.secondaryBackground.opacity(0.2)],
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
                                            Image(systemName: "bag")
                                                .font(.system(size: 28))
                                                .foregroundStyle(Color.secondary)
                                                .opacity(0.25)
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

                            Text(item.name)
                                .font(.headline)
                                .foregroundStyle(Color.primary)
                                .lineLimit(2)

                            Text(item.price)
                                .font(.subheadline)
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1)
                        }
                        .padding(12)
                        .background(PlatformColors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(radius: 4, y: 2)
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onTapGesture {
                            selectedMerch = item
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
        .background(PlatformColors.systemBackground.ignoresSafeArea())
#if !os(tvOS)
        .navigationTitle("Merch")
#endif
        .sheet(item: $selectedMerch) { item in
            MerchDetailSheet(item: item)
        }
    }

    private var filteredItems: [MerchItem] {
        guard let selectedFilter, !selectedFilter.isEmpty, selectedFilter != "All" else {
            return merchItems
        }

        func contains(_ item: MerchItem, _ needle: String) -> Bool {
            let text = (item.name + " " + item.description).lowercased()
            return text.contains(needle)
        }

        return merchItems.filter { item in
            switch selectedFilter {
            case "Hoodies":
                return contains(item, "hoodie")
            case "Sweatshirts":
                return contains(item, "sweatshirt")
            case "Jackets":
                return contains(item, "jacket")
            case "Shirts":
                return contains(item, "shirt") || contains(item, "budget shirt")
            case "Posters":
                return contains(item, "poster")
            case "Stickers":
                return contains(item, "sticker")
            case "Mugs & Cups":
                return contains(item, "mug") || contains(item, "cup")
            case "Cases":
                return contains(item, "case")
            case "Notebooks & Journals":
                return contains(item, "notebook") || contains(item, "journal")
            case "Pins & Patches":
                return contains(item, " pin") || contains(item, "pin ") || contains(item, "patch")
            case "Magnets":
                return contains(item, "magnet")
            case "Blankets":
                return contains(item, "blanket")
            case "Pillows":
                return contains(item, "pillow") || contains(item, "dakimakura")
            case "Flags":
                return contains(item, "flag")
            case "Keychains":
                return contains(item, "keychain")
            case "Other":
                // Anything that doesn't match the main buckets
                let matchesKnown = (
                    contains(item, "hoodie") ||
                    contains(item, "sweatshirt") ||
                    contains(item, "jacket") ||
                    contains(item, "shirt") ||
                    contains(item, "poster") ||
                    contains(item, "sticker") ||
                    contains(item, "mug") ||
                    contains(item, "cup") ||
                    contains(item, "case") ||
                    contains(item, "notebook") ||
                    contains(item, "journal") ||
                    contains(item, "pin") ||
                    contains(item, "patch") ||
                    contains(item, "magnet") ||
                    contains(item, "blanket") ||
                    contains(item, "pillow") ||
                    contains(item, "dakimakura") ||
                    contains(item, "flag") ||
                    contains(item, "keychain")
                )
                return !matchesKnown
            default:
                // Fallback: substring match
                return contains(item, selectedFilter.lowercased())
            }
        }
    }

    @ViewBuilder
    private func aiFiltersBar() -> some View {
        let filters = Self.presetFilters
        if !filters.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Suggested filters")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    if selectedFilter != nil && selectedFilter != "All" {
                        Button("All") {
                            selectedFilter = "All"
                        }
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.primary)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(filters, id: \.self) { filter in
                            let isSelected = (selectedFilter == filter)
                            Button {
                                selectedFilter = isSelected ? "All" : filter
                            } label: {
                                Text(filter)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(isSelected ? Color.primary.opacity(0.12) : PlatformColors.secondaryBackground)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(isSelected ? Color.primary.opacity(0.35) : PlatformColors.secondaryBackground.opacity(0.0), lineWidth: 1)
                                    )
                                    .foregroundStyle(isSelected ? Color.primary : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.top, 4)
        }
    }


    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 160), spacing: 16)]
    }

    @ViewBuilder
    private func header() -> some View {
        HStack {
            Text("Tap an item to view it larger — or use filters below")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
            Spacer()
        }
    }
}

private struct MerchDetailSheet: View {
    let item: MerchView.MerchItem

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PlatformColors.systemBackground.ignoresSafeArea()

                VStack(spacing: 16) {
                    GeometryReader { geo in
                        let w = max(0, geo.size.width - 32)
                        let h = max(0, geo.size.height - 32)

                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(PlatformColors.secondaryBackground)

#if canImport(UIKit)
                            if let uiImage = UIImage(named: item.imageName) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(12)
                                    .frame(width: w, height: h)
                            } else {
                                Image(systemName: "bag")
                                    .font(.system(size: 44))
                                    .foregroundStyle(Color.secondary)
                                    .opacity(0.25)
                            }
#else
                            Image(item.imageName)
                                .resizable()
                                .scaledToFit()
                                .padding(12)
                                .frame(width: w, height: h)
#endif
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(16)
                    }
                    .frame(maxHeight: 360)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.name)
                            .font(.title3)
                            .bold()
                            .foregroundStyle(Color.primary)

                        Text(item.price)
                            .font(.headline)
                            .foregroundStyle(Color.primary)

                        if !item.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(item.description)
                                .font(.body)
                                .foregroundStyle(Color.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let url = item.storeURL {
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "cart")
                                    Text("Open Store")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.primary.opacity(0.12))
                                .foregroundStyle(Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
            }
            .navigationTitle(item.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                #if !os(tvOS)
                if let url = item.storeURL {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                #endif
            }
#if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }
}

enum SampleMerchData {
    static let items: [MerchView.MerchItem] = [
        .init(
            id: "merch_001",
            name: "Meowbah Dakimakura",
            description: "Character: Meowbah\nPartner/Artist: Meowbah\nMaterial: 2-Way Tricot\nSize: 150 x 50 cm or 160 x 50 cm",
            price: "$88.10 (Approx)",
            imageName: "bodypillow",
            storeUrl: "https://cuddlyoctopus.com/product/meowbah/"
        ),
        .init(
            id: "merch_002",
            name: "Meowbah Plush (Not Yet Available)",
            description: "Nyahallo! Meowbah is here~ your super kawaii neko friend! Do you ever sit in your room thinking, \"I love Meowbah. Meow meow. I love Meowbah. Meow meow meow\"? Well, now you can really love Meowbah with— A MEOWBAH PLUSH! LOTS OF MEOWBAH TO MEOWBAH HERE! This will be your best purchase choice of all time!! (Meowbah approved)",
            price: "TBD",
            imageName: "meowplush",
            storeUrl: "https://idolized.co/products/meowbah-plush"
        ),
        .init(
            id: "merch_003",
            name: "PRE ORDER - Acrylic Keychain (limited)",
            description: "Meowbah keychain :3!\n1. This keychain is limited! Once pre-orders end it won't be purchasable anymore\n2. Only if 50+ pre-orders are placed, then it will go into production :3\n3. If it goes into production meow will release Meowgod keychain next >_>\nPre-order Ends: January 3rd, 2026\nEstimated Ship Date: January 2026",
            price: "$8",
            imageName: "keychain",
            storeUrl: "https://meowbah-shop.fourthwall.com/en-usd/products/pre-order-acrylic-keychain-limited"
        ),
        .init(
            id: "merch_004",
            name: "THE HOLY MEOWBLE - Prayer Journal ed.",
            description: "Journal version of The Holy Meowble :3\nYou can write all your Meowist prayers and draw kawaii stuffs! Maybe meowgod will hear your prayers?",
            price: "$15",
            imageName: "meowble",
            storeUrl: "https://meowbah-shop.fourthwall.com/products/the-holy-meowble-prayer-journal-ed"
        ),
        .init(
            id: "merch_005",
            name: "Lucky Neko! - jacket",
            description: "Designed by: Meowbah\nArtist: @ririnyannn + Meowbah",
            price: "$55",
            imageName: "neko_hoodie",
            storeUrl: "https://meowbah-shop.fourthwall.com/products/lucky-neko-jacket"
        ),
        .init(
            id: "merch_006",
            name: "Stars 4 Meowbah - jacket",
            description: "so stylish desu!\nDesigned by: Meowbah\nArtist: @ririnyannn + Meowbah",
            price: "$55",
            imageName: "stars_hoodie",
            storeUrl: "https://meowbah-shop.fourthwall.com/products/stars-4-meowbah-jacket"
        ),
        .init(
            id: "merch_007",
            name: "LUV♡MEOWBAH - hoodie",
            description: "Merch design contest winner 1 :3\nDesigned by: @kittypur1\nArtist: Meowbah",
            price: "$45",
            imageName: "love_hoodie",
            storeUrl: "https://meowbah-shop.fourthwall.com/products/luvmeowbah-hoodie"
        ),
        .init(
            id: "merch_008",
            name: "Meowrei Kei - hoodie",
            description: "Merch design contest winner 2 :3\nDesigned by: @ririnyannn\nArtist: Meowbah",
            price: "$45",
            imageName: "meowrai_hoodie",
            storeUrl: "https://meowbah-shop.fourthwall.com/products/meowrei-kei-hoodie"
        ),
        .init(
            id: "merch_009",
            name: "Peekameow! - hoodie",
            description: "Merch design contest winner 3 :3\nDesigned by: @rorychuua\nArtist: Meowbah",
            price: "$45",
            imageName: "peekameow_hoodie",
            storeUrl: "https://meowbah-shop.fourthwall.com/products/peekameow-hoodie"
        ),
        .init(
            id: "merch_010",
            name: "OBEY & WORSHIP v1 - hoodie",
            description: "Merch design contest winner 4 :3\nDesigned by: @ririnyannn\nArtist: Meowbah",
            price: "$45",
            imageName: "worshipv1_hoodie",
            storeUrl: "https://meowbah-shop.fourthwall.com/products/obey-worship-v1-hoodie"
        ),
        .init(
            id: "merch_011",
            name: "OBEY & WORSHIP v2 - hoodie",
            description: "Merch design contest winner 4 :3\nDesigned by: @ririnyannn\nArtist: Meowbah",
            price: "$40",
            imageName: "worshipv2_hoodie",
            storeUrl: "https://meowbah-shop.fourthwall.com/products/obey-worship-v2-hoodie"
        ),
        .init(
            id: "merch_012",
            name: "True Meowist - hoodie",
            description: "Meowists are the most oppressed people on this planet. The world wants to silence your beliefs! Don't worry little meowling.....comehere................... meow has this awesome. super cool. meowist hoodie!!!! the meowist symbol is very subtle so theres only a 0.1% of you getting jumped for wearing it!\nMerch design contest winner 5 :3\nDesigned by: @nm1a.0\nArtist: Meowbah",
            price: "$45",
            imageName: "meowist_hoodie",
            storeUrl: "https://meowbah-shop.fourthwall.com/products/true-meowist-hoodie"
        ),
        .init(
            id: "merch_013",
            name: "Double Trouble - poster (BIG)",
            description: "God Meowbah and normal Meowbah :3 This poster is bigger than the others\nSize: 18\" x 24\"\nArtist: @AyahosiYuki",
            price: "$20",
            imageName: "trouble_poster",
            storeUrl: "https://meowbah-shop.fourthwall.com/products/double-trouble-poster-big"
        ),
        .init(
            id: "merch_014",
            name: "Meowbah World Domination - poster",
            description: "Size: 12\" x 18\"\nArtist: @3k14r0",
            price: "$15",
            imageName: "world_poster",
            storeUrl: "https://meowbah-shop.fourthwall.com/products/meowbah-world-domination-poster"
        ),
        .init(
            id: "merch_015",
            name: "Kawaiiest Meowbah - poster",
            description: "Meowbah with magical girl weapon :3\nSize: 18\" x 12\"\nArtist: @AyahosiYuki",
            price: "$15",
            imageName: "kawaii_poster",
            storeUrl: "https://meowbah-shop.fourthwall.com/products/kawaiiest-meowbah-poster"
        ),
        .init(
            id: "merch_016",
            name: "Our True God - poster",
            description: "Meowgod\nSize: 18\" x 12\"\nArtist: @sorano_haku",
            price: "$15",
            imageName: "god_poster",
            storeUrl: "https://meowbah-shop.fourthwall.com/products/our-true-god-poster"
        ),
        .init(
            id: "merch_017",
            name: "Meowbah Loves U! - poster",
            description: "kawaii meowbah chan :3\nSize: 12\" x 18\"\nArtist: @wakamekame112",
            price: "$15",
            imageName: "loves_poster",
            storeUrl: "https://meowbah-shop.fourthwall.com/products/meowbah-loves-u-poster"
        ),
        .init(
            id: "merch_018",
            name: "OBEY & WORSHIP - poster",
            description: "NYAA!!!\nSize: 12\" x 18\"\nArtist: Meowbah",
            price: "$15",
            imageName: "worship_poster",
            storeUrl: "https://meowbah-shop.fourthwall.com/products/obey-worship-poster"
        ),
        .init(
            id: "merch_019",
            name: "All Eyes on Meowbah - poster",
            description: ">Meow luv u\nSize: 18\" x 12\"\nArtist: @awa_ben_0521",
            price: "$15",
            imageName: "eyes_poster",
            storeUrl: "https://meowbah-shop.fourthwall.com/products/all-eyes-on-meowbah-poster"
        ),
        .init(
            id: "merch_020",
            name: "Magical Girlz ⋆˙⟡ - poster",
            description: "Magical girl Meowbah and Madoka :D\nSize: 12\" x 18\"\nArtist: @4kiMizuki",
            price: "$15",
            imageName: "girls_poster",
            storeUrl: "https://meowbah-shop.fourthwall.com/products/magical-girlz-poster"
        ),
        .init(id: "merch_021", name: "Magical Meow! - iphone case", description: "SO MAGICAL SO MEOWBAH\nArtist: @gi_irst", price: "$16", imageName: "magical_iphone", storeUrl: "https://meowbah-shop.fourthwall.com/products/magical-meow-iphone-case"),
        .init(id: "merch_022", name: "Lucky Neko! - iphone case", description: "luckyluckymeow", price: "$16", imageName: "neko_iphone", storeUrl: "https://meowbah-shop.fourthwall.com/products/lucky-neko-iphone-case"),
        .init(id: "merch_023", name: "Chibi Meowgod - samsung case", description: "for the android users (derogatory)", price: "$16", imageName: "chibi_samsung", storeUrl: "https://meowbah-shop.fourthwall.com/products/chibi-meowgod-samsung-case"),
        .init(id: "merch_024", name: "Rainy Day Meowbah - iphone case", description: "Meowbah on da go\nArtist: @ueji_bun", price: "$16", imageName: "rainy_iphone", storeUrl: "https://meowbah-shop.fourthwall.com/products/rainy-day-meowbah-iphone-case"),
        .init(id: "merch_025", name: "Meowrei Kei - iphone case", description: "Artist: Meowbah", price: "$16", imageName: "meowrei_iphone", storeUrl: "https://meowbah-shop.fourthwall.com/products/meowrei-kei-iphone-case"),
        .init(id: "merch_026", name: "Chibi Meowgod - iphone case", description: "chibi miau\nArtist: Meowbah", price: "$16", imageName: "chibi_iphone", storeUrl: "https://meowbah-shop.fourthwall.com/products/chibi-meowgod-iphone-case"),
        .init(id: "merch_027", name: "My Maid Meowbah - notebook", description: ":3", price: "$15", imageName: "maid_notepad", storeUrl: "https://meowbah-shop.fourthwall.com/products/my-maid-meowbah-notebook"),
        .init(id: "merch_028", name: "Magical Meow! - notebook", description: "kawwaaaaiiiiiii", price: "$15", imageName: "magical_notepad", storeUrl: "https://meowbah-shop.fourthwall.com/products/magical-meow-notebook"),
        .init(id: "merch_029", name: "Rainy Day Meowbah - notebook", description: "draw kawaii things in your kawaii notebook\nArtist: @ueji_bun", price: "$15", imageName: "rainy_notepad", storeUrl: "https://meowbah-shop.fourthwall.com/products/rainy-day-meowbah-notebook"),
        .init(id: "merch_030", name: "Magical Girlz ⋆˙⟡ - notebook", description: "meowbah and meguca\nArtist: @4kiMizuki", price: "$15", imageName: "girls_notepad", storeUrl: "https://meowbah-shop.fourthwall.com/products/magical-girlz-notebook"),
        .init(id: "merch_031", name: "OBEY & WORSHIP - notebook", description: "starts drawing ooo ahh\nArtist: Meowbah", price: "$15", imageName: "worship_notepad", storeUrl: "https://meowbah-shop.fourthwall.com/products/obey-worship-notebook-2"),
        .init(id: "merch_032", name: "Meowist Flag", description: "meowist 4 life", price: "$25", imageName: "holy_flag", storeUrl: "https://meowbah-shop.fourthwall.com/products/meowist-flag"),
        .init(id: "merch_033", name: "Meowbahsexual Flag", description: "meowba h pride!\nartist: @unagi", price: "$25", imageName: "meow_flag", storeUrl: "https://meowbah-shop.fourthwall.com/products/meowbahsexual-flag"),
        .init(id: "merch_034", name: "Cyber Neko - sweatshirt", description: "meows\nDesigned by: Meowbah\nArtist: @perperogero", price: "$40", imageName: "cyber_sweatshirt", storeUrl: "https://meowbah-shop.fourthwall.com/products/cyber-neko-sweatshirt"),
        .init(id: "merch_035", name: "My Maid Meowbah - sweatshirt", description: "kyun kyun kyun :3\nDesigned by: Meowbah\nArtist: Meowbah", price: "$40", imageName: "maid_sweatshirt", storeUrl: "https://meowbah-shop.fourthwall.com/products/my-maid-meowbah-sweatshirt"),
        .init(id: "merch_036", name: "MEOWIST ANGEL - sweatshirt", description: "la kawaii\nDesigned by: Meowbah\nArtist: Meowbah", price: "$40", imageName: "angel_sweatshirt", storeUrl: "https://meowbah-shop.fourthwall.com/products/meowist-angel-sweatshirt"),
        .init(id: "merch_037", name: "Meowist Lives Matter - shirt", description: "MLM", price: "$20", imageName: "lives_shirt", storeUrl: "https://meowbah-shop.fourthwall.com/products/meowist-lives-matter-shirt"),
        .init(id: "merch_038", name: "i <3 meowbah - shirt", description: "aw...... :3", price: "$20", imageName: "heart_shirt", storeUrl: "https://meowbah-shop.fourthwall.com/products/i-3-meowbah-shirt"),
        .init(id: "merch_039", name: "Meowist Routine - shirt", description: "real", price: "$28", imageName: "routine_shirt", storeUrl: "https://meowbah-shop.fourthwall.com/products/meowist-routine-shirt"),
        .init(id: "merch_040", name: "Internet Angel - shirt", description: "lol\nArtist: @hanyan_001", price: "$25", imageName: "angel_shirt", storeUrl: "https://meowbah-shop.fourthwall.com/products/internet-angel-shirt"),
        .init(id: "merch_041", name: "OBEY & WORSHIP - shirt", description: "Cheaper alternative of OBEY & WORSHIP hoodie :3\nArtist: Meowbah", price: "$25", imageName: "worship_shirt", storeUrl: "https://meowbah-shop.fourthwall.com/products/obey-worship-shirt"),
        .init(id: "merch_042", name: "Chibi Meow - shirt", description: "black k", price: "$20", imageName: "chibi_shirt", storeUrl: "https://meowbah-shop.fourthwall.com/products/chibi-meow-shirt"),
        .init(id: "merch_043", name: "Magical Meow! - shirt", description: "magical girl : 3\nArtist: @gi_irst", price: "$26", imageName: "magical_shirt", storeUrl: "https://meowbah-shop.fourthwall.com/products/magical-meow-shirt"),
        .init(id: "merch_044", name: "Cyber Neko - budget shirt", description: "Cheaper alternative of Cyber Neko sweatshirt :3", price: "$20", imageName: "cyber_shirt", storeUrl: "https://meowbah-shop.fourthwall.com/products/cyber-neko-budget-shirt"),
        .init(id: "merch_045", name: "OBEY & WORSHIP - budget shirt", description: "Cheaper alternative of OBEY & WORSHIP hoodie :3\nArtist: Meowbah", price: "$20", imageName: "worship_shirt2", storeUrl: "https://meowbah-shop.fourthwall.com/products/obey-worship-budget-shirt"),
        .init(id: "merch_046", name: "LUV♡MEOWBAH - budget shirt", description: "Cheaper alternative of LUV♡MEOWBAH hoodie :3\nArtist: Meowbah", price: "$20", imageName: "loves_shirt", storeUrl: "https://meowbah-shop.fourthwall.com/products/luvmeowbah-budget-shirt"),
        .init(id: "merch_047", name: "Meowrei Kei - budget shirt", description: "Cheaper alternative of Meowrei Kei hoodie :3\nArtist: Meowbah", price: "$20", imageName: "meowrei_shirt", storeUrl: "https://meowbah-shop.fourthwall.com/products/meowrei-kei-budget-shirt"),
        .init(id: "merch_048", name: "Peekameow! - budget shirt", description: "Cheaper alternative of Peekameow! hoodie :3\nArtist: Meowbah", price: "$20", imageName: "peekameow_shirt", storeUrl: "https://meowbah-shop.fourthwall.com/products/peekameow-budget-shirt"),
        .init(id: "merch_049", name: "LUV♡MEOWBAH - mug", description: "mug\nArtist: Meowbah", price: "$12", imageName: "loves_mug", storeUrl: "https://meowbah-shop.fourthwall.com/products/luvmeowbah-mug"),
        .init(id: "merch_050", name: "Peekameow! - mug", description: "anothr mug\nArtist: Meowbah", price: "$12", imageName: "peekameow_mug", storeUrl: "https://meowbah-shop.fourthwall.com/products/peekameow-mug"),
        .init(id: "merch_051", name: "OBEY & WORSHIP - mug", description: "lil meowgod\nArtist: Meowbah", price: "$12", imageName: "chibi_mug", storeUrl: "https://meowbah-shop.fourthwall.com/products/obey-worship-mug"),
        .init(id: "merch_052", name: "Meowrei Kei - mug", description: "drink\nArtist: Meowbah", price: "$12", imageName: "meowrei_mug", storeUrl: "https://meowbah-shop.fourthwall.com/products/meowrei-kei-mug"),
        .init(id: "merch_053", name: "OBEY & WORSHIP - cup", description: "drink watr", price: "$25", imageName: "worship_cup", storeUrl: "https://meowbah-shop.fourthwall.com/products/obey-worship-cup"),
        .init(id: "merch_054", name: "Meowist Lives Matter - patch", description: "embroidary patch bro.", price: "$12", imageName: "lives_patch", storeUrl: "https://meowbah-shop.fourthwall.com/products/meowist-lives-matter-patch"),
        .init(id: "merch_055", name: "i <3 meowbah - patch", description: "luv is luv", price: "$12", imageName: "love_patch", storeUrl: "https://meowbah-shop.fourthwall.com/products/i-3-meowbah-patch"),
        .init(id: "merch_056", name: "Meow!Online - magnet", description: "meowputer\nArtist: Meowbah", price: "$7", imageName: "online_magnet", storeUrl: "https://meowbah-shop.fourthwall.com/products/meow-online-magnet"),
        .init(id: "merch_057", name: "Chibi Meowgod - magnet", description: "!!!!!!!!!!!!!!\nArtist: Meowbah", price: "$7", imageName: "god_magnet", storeUrl: "https://meowbah-shop.fourthwall.com/products/chibi-meowgod-magnet"),
        .init(id: "merch_058", name: "Chibi Meowbah - magnet", description: ":3!!!\nArtist: Meowbah", price: "$7", imageName: "chibi_magnet", storeUrl: "https://meowbah-shop.fourthwall.com/products/chibi-meowbah-magnet"),
        .init(id: "merch_059", name: "Meowrei Kei - magnet", description: "the kawaii ever\nArtist: Meowbah", price: "$7", imageName: "meowrei_magnet", storeUrl: "https://meowbah-shop.fourthwall.com/products/jirai-meowbah-magnet"),
        .init(id: "merch_060", name: "LUV♡MEOWBAH - magnet", description: "meowbaaaaaaaah\nArtist: Meowbah", price: "$7", imageName: "loves_magnet", storeUrl: "https://meowbah-shop.fourthwall.com/products/luvmeowbah-magnet"),
        .init(id: "merch_061", name: "Peekameow! - magnet", description: "yay\nArtist: Meowbah", price: "$7", imageName: "peekameow_magnet", storeUrl: "https://meowbah-shop.fourthwall.com/products/peekameow-magnet"),
        .init(id: "merch_062", name: "Meowbah Pin Pack!", description: "yay\nArtist: Meowbah", price: "$13", imageName: "pin_pack_1", storeUrl: "https://meowbah-shop.fourthwall.com/products/meowbah-pin-pack"),
        .init(id: "merch_063", name: "Meowist Pin Pack!", description: "WE MATTER !!!!!!!!!!!!!!!!!!!!\nArtist: @kittenex", price: "$13", imageName: "pin_pack_2", storeUrl: "https://meowbah-shop.fourthwall.com/products/meowist-pin-pack"),
        .init(id: "merch_064", name: "Meowcord Pin Pack!", description: "meowcord pin pack :3\nArtist: @hhomura + meowbah", price: "$13", imageName: "pin_pack_3", storeUrl: "https://meowbah-shop.fourthwall.com/products/meowcord-pin-pack"),
        .init(id: "merch_065", name: "Many Meows - pillow", description: "it is back\nArtist: @ririnyannn", price: "$100", imageName: "many_meows", storeUrl: "https://meowbah-shop.fourthwall.com/products/many-meows-pillow"),
        .init(id: "merch_067", name: "Chibi meows - pillow", description: "doubl the meow......", price: "$100", imageName: "chibi_pillow", storeUrl: "https://meowbah-shop.fourthwall.com/products/chibi-meows-pillow"),
        .init(id: "merch_068", name: "Meowrei Kei - pillow", description: "everyone: this is totally worth $100\nArtist: Meowbah", price: "$100", imageName: "meowrei_pillow", storeUrl: "https://meowbah-shop.fourthwall.com/products/meowrei-kei-pillow"),
        .init(id: "merch_069", name: "Many Meows - blanket", description: "soft mm\nArtist: @ririnyannn", price: "$30", imageName: "meows_blanket", storeUrl: "https://meowbah-shop.fourthwall.com/products/many-meows-blanket"),
        .init(id: "merch_070", name: "All Eyes on Meowbah - deskmat (large)", description: "meowbah meowbah meowbah meowbah\n15.5 x 31.5 inches / 40cm x 80cm\nArtist: @awa_ben_0521", price: "$20", imageName: "eyes_mousepad_large", storeUrl: "https://meowbah-shop.fourthwall.com/products/all-eyes-on-meowbah-deskmat-large"),
        .init(id: "merch_071", name: "All Eyes on Meowbah - deskmat (medium)", description: "nyannyanyan\n12.8\" x 22.6\" inches / 33cm x 58cm\nArtist: @awa_ben_0521", price: "$18", imageName: "eyes_mousepad_medium", storeUrl: "https://meowbah-shop.fourthwall.com/products/all-eyes-on-meowbah-deskmat-medium"),
        .init(id: "merch_072", name: "Chibi Meowbah - sticker", description: "the kawaii\nArtist: Meowbah", price: "$6", imageName: "chibi_meow_sticker", storeUrl: "https://meowbah-shop.fourthwall.com/products/chibi-meowbah-sticker"),
        .init(id: "merch_073", name: "Chibi Momo - sticker", description: "R3D Momo :3\nArtist: Meowbah", price: "$6", imageName: "chibi_momo_sticker", storeUrl: "https://meowbah-shop.fourthwall.com/products/chibi-momo-sticker"),
        .init(id: "merch_074", name: "Chibi Commotion - sticker", description: "Commotionsickness :3\nArtist: Meowbah", price: "$6", imageName: "chibi_commotion_sticker", storeUrl: "https://meowbah-shop.fourthwall.com/products/chibi-commotion-sticker"),
        .init(id: "merch_075", name: "Mod Sticker bundle", description: "discord moment", price: "$14.40", imageName: "mod_sticker_pack", storeUrl: "https://meowbah-shop.fourthwall.com/products/mod-sticker-bundle"),
        .init(id: "merch_076", name: "Meow!Online - sticker", description: "meowber on the computr\nArtist: Meowbah", price: "$6", imageName: "online_sticker", storeUrl: "https://meowbah-shop.fourthwall.com/products/meow-online-sticker"),
        .init(id: "merch_077", name: "Chibi Meowgod - sticker", description: "the lord and saviour\nArtist: Meowbah", price: "$6", imageName: "god_sticker", storeUrl: "https://meowbah-shop.fourthwall.com/products/chibi-meowgod-sticker"),
        .init(id: "merch_078", name: "OBEY & WORSHIP - sticker", description: "she run\nArtist: Meowbah", price: "$6", imageName: "worship_sticker", storeUrl: "https://meowbah-shop.fourthwall.com/products/obey-worship-sticker"),
        .init(id: "merch_079", name: "Meowbah Sticker Sheet!", description: "very sugoi!!!\nArtist: @ririnyannn", price: "$10", imageName: "meowbah_sticker_sheet", storeUrl: "https://meowbah-shop.fourthwall.com/products/meowbah-sticker-sheet"),
        .init(id: "merch_080", name: "Meowist Sticker Sheet!", description: "", price: "$10", imageName: "meowist_sticker_sheet", storeUrl: "https://meowbah-shop.fourthwall.com/products/meowist-sticker-sheet")
    ]
}

#Preview {
    NavigationStack {
        MerchView()
    }
}
