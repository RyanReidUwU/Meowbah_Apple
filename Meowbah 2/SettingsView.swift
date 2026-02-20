import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@available(*, deprecated, message: "SettingsView was removed. Replace usages with inline @AppStorage controls or open system Settings.")
struct SettingsView: View {
    var body: some View {
        #if os(iOS)
        VStack(spacing: 16) {
            Text("Settings have moved")
                .font(.headline)
            Text("This screen is a temporary placeholder. Settings are now managed inline in the app or via the system Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            #if canImport(UIKit)
            Button("Open System Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            #endif
        }
        .padding()
        .frame(maxWidth: 480)
        .navigationTitle("Settings")
        #else
        VStack(spacing: 12) {
            Text("Settings have moved")
                .font(.headline)
            Text("This screen is a temporary placeholder. Settings are now managed inline or via platform preferences.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: 480)
        .navigationTitle("Settings")
        #endif
    }
}

#Preview {
    SettingsView()
}
