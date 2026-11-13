import SwiftUI

/// The first screen people see before they've chosen a location, in the style of Apple's
/// own first-launch screens: a title, what the app does, and one clear action.
struct WelcomeView: View {
    var isLocating: Bool
    var onUseLocation: () -> Void
    var onSearch: () -> Void

    /// Heights used to decide whether the actions can stay pinned to the bottom.
    @State private var actionsHeight: CGFloat = 0
    @State private var availableHeight: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                VStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text("Welcome to")
                        Text(Self.appName)
                            .foregroundStyle(.pgeOrange)
                    }
                    .font(.largeTitle.bold())
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    Text("Covering PG&E in California")
                        .font(.title3)
                }
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 28) {
                    FeatureRow(
                        systemImage: "house.fill",
                        title: "Your Address",
                        detail: "See whether an outage is affecting your home right now."
                    )
                    FeatureRow(
                        systemImage: "timer",
                        title: "Estimated Fix Time",
                        detail: "Count down to when your power should be back."
                    )
                    FeatureRow(
                        systemImage: "mappin.and.ellipse",
                        title: "Nearby Outages",
                        detail: "See what’s happening around you, with street names."
                    )
                }

                if !pinsActions {
                    actions
                }
            }
            // White text with a PG&E orange accent, as on the outages screen. The tint and gray
            // secondary text would disappear into the blue background.
            .foregroundStyle(.white)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 72)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            if pinsActions {
                actions
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { availableHeight = $0 }
        // A deeper blue than the outages screen in light mode, so white text and the orange
        // accent meet accessibility contrast guidelines. Dark mode matches the outages screen.
        .background { Color.welcomeBackground.ignoresSafeArea() }
        .animation(reduceMotion ? nil : .default, value: pinsActions)
    }

    /// The actions stay pinned within thumb reach unless they'd cover too much of the screen,
    /// as on a short display with large text. Then they scroll after the features instead.
    private var pinsActions: Bool {
        availableHeight == 0 || actionsHeight < availableHeight * 0.4
    }

    private var actions: some View {
        VStack(spacing: 16) {
            Button {
                onUseLocation()
            } label: {
                Label("Use My Location", systemImage: "location.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            // The bright dark-mode accent is too light behind white text, so the fill stays
            // the deeper PG&E blue in both appearances.
            .tint(.prominentButton)
            .controlSize(.extraLarge)
            .disabled(isLocating)

            // Plain glass brightens the blue behind it, so it's tinted with the background color
            // to keep the white label within accessibility contrast guidelines.
            Button {
                onSearch()
            } label: {
                Label("Search for an Address", systemImage: "magnifyingglass")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass(.regular.tint(.welcomeBackground)))
            .controlSize(.extraLarge)

            VStack(spacing: 6) {
                Text("Your location is only used to look up outages.")
                    .foregroundStyle(.white)
                OfficialOutagesNotice()
            }
            .font(.subheadline)
            .multilineTextAlignment(.center)
        }
        // Pinned or scrolling, the actions get the same width, so their height is stable.
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { actionsHeight = $0 }
    }

    /// The name shown on the Home Screen, so the title follows any rename.
    private static var appName: String {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleDisplayName"] as? String)
            ?? (info?["CFBundleName"] as? String)
            ?? "Outages"
    }
}

/// One feature on the welcome screen: an icon with a short title and description.
private struct FeatureRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(.pgeOrange)
                .frame(width: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomeView(isLocating: false, onUseLocation: {}, onSearch: {})
        .background { PageBackground() }
        .tint(Color("AccentColor"))
}
