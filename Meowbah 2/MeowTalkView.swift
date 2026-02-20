import SwiftUI

struct MeowTalkView: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var message: String = ""

    private let phrases: [String] = [
        "Welcome to MeowTalk!",
        "Say hi to your fellow cats 🐾",
        "Meow means hello 🐱",
        "Stay pawsitive!",
        "Another day, another meow",
        "Cats rule the internet",
        "Purrfection achieved ✨",
        "Keep calm and meow on"
    ]

    @State private var selectedPhrase: String = ""

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        ZStack {
            palette.background
                .ignoresSafeArea()

            VStack {
                Spacer()

                Text(selectedPhrase)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.textPrimary)
                    .padding(24)

                Spacer()
            }
        }
        .onAppear {
            selectedPhrase = phrases.randomElement() ?? "Meow"
        }
        .navigationTitle("MeowTalk")
    }
}

#Preview {
    NavigationStack {
        MeowTalkView()
            .environmentObject(ThemeManager())
    }
}
