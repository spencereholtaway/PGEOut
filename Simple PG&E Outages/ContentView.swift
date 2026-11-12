import SwiftUI
import MapKit

struct ContentView: View {
    @State private var store: OutageStore
    @State private var completer = AddressCompleter()
    @State private var isSearching = false
    @State private var isPickingAddress = false
    @State private var isLocating = false
    @State private var errorMessage: String?
    @State private var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var isWiderThanTall = false
    /// Space above the last-updated time and disclaimer, so they sit at the bottom when the list is short.
    @State private var footerGap: CGFloat = 0
    /// Where the section headers start, in global coordinates, so the pinned title lines up with them.
    @State private var paneHeaderLeading: CGFloat = 20
    /// Where the pinned title bar starts, in global coordinates.
    @State private var titleBarLeading: CGFloat = 0
    /// The pinned title's height, so the pane beside it starts its cards at the same level.
    @State private var paneTitleHeight: CGFloat = 0
    /// Space above the pinned title. In landscape the top safe area is nearly nothing, so this
    /// gives the title the room a large title has below the status bar, scaling with Dynamic Type.
    @ScaledMetric(relativeTo: .title) private var paneTitleTopPadding: CGFloat = 36

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// The side the system moves the bottom bar to, as on the outer display of iPhone Duo, or nil
    /// when it stays at the bottom.
    @Environment(\.toolbarVerticalEdge) private var toolbarVerticalEdge

    private static let reportURL = URL(string: "https://www.pge.com/en/contact-us/report-an-issue/report-electric-issue.html")!

    init(store: OutageStore = OutageStore()) {
        _store = State(initialValue: store)
    }

    var body: some View {
        // One shared clock for every countdown. Labels only show minutes, so it ticks on the minute,
        // and the system pauses it while the app isn't on screen.
        TimelineView(.everyMinute) { context in
            NavigationStack {
                content
                    .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height } action: {
                        isWiderThanTall = $0
                    }
                    .scrollContentBackground(.hidden)
                    .background { PageBackground() }
                    .modifier(AdaptiveNavigationTitle(title: String(localized: "Outages"), subtitle: addressLine))
                    .toolbar {
                        // Both ways of choosing a location sit together at the bottom, within thumb reach.
                        DefaultToolbarItem(kind: .search, placement: .bottomBar)
                        ToolbarSpacer(.fixed, placement: .bottomBar)
                        ToolbarItem(placement: .bottomBar) {
                            Button("Use My Location", systemImage: "location.fill", action: useCurrentLocation)
                                .disabled(isLocating)
                        }
                    }
                    .navigationDestination(for: Outage.self) { outage in
                        OutageDetailView(outage: outage, origin: store.location?.coordinate, placeName: store.placeNames[outage.id])
                    }
                    // The welcome screen has its own title and actions, and searches in a sheet,
                    // so the bars stay hidden until a location is chosen.
                    .toolbarVisibility(showsWelcome ? .hidden : .automatic, for: .bottomBar)
                    // Side by side, the title moves into the leading pane. In the bar it spanned
                    // both panes and the fold between them, and followed the scrolling of only one
                    // pane, so scrolling either one collapsed it and shifted both.
                    .toolbarVisibility(showsWelcome || usesPanes || pinsTitle ? .hidden : .automatic, for: .navigationBar)
                    .searchable(text: $completer.query, isPresented: $isSearching, prompt: "Search for an address")
                    .searchSuggestions { suggestions }
                    .sheet(isPresented: $isPickingAddress) {
                        AddressSearchSheet(completer: completer) { completion in
                            isPickingAddress = false
                            choose(completion)
                        }
                    }
                    .alert("Couldn’t Find Location", item: $errorMessage) { _ in
                        Button("OK") {}
                    } message: { message in
                        Text(message)
                    }
            }
            .environment(\.now, context.date)
        }
        // PG&E blue for links, buttons and icons, from the AccentColor asset.
        .tint(Color("AccentColor"))
        .animation(reduceMotion ? nil : .default, value: store.status)
        .animation(reduceMotion ? nil : .default, value: store.nearby)
        .animation(reduceMotion ? nil : .default, value: showsWelcome)
        // Runs while the app is in the foreground and is cancelled when it leaves, so nothing polls
        // in the background. Restarts when Low Power Mode changes.
        .task(id: AutoRefresh(isForeground: scenePhase != .background, isLowPowerMode: isLowPowerMode)) {
            guard scenePhase != .background else { return }
            // Loads on launch, and on return only if the data is older than the refresh interval.
            await store.refreshIfStale()
            // In Low Power Mode, refresh only on return to the app or with pull to refresh.
            // Read the setting directly in case it changed while the app was suspended.
            guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
            while true {
                do {
                    // The tolerance lets the system wake for this together with other work.
                    try await Task.sleep(for: OutageStore.refreshInterval, tolerance: .seconds(60))
                } catch {
                    return
                }
                await store.refreshIfChanged()
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .NSProcessInfoPowerStateDidChange) {
                isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }

    private struct AutoRefresh: Equatable {
        var isForeground: Bool
        var isLowPowerMode: Bool
    }

    // MARK: - Layout

    /// True before a location has been chosen.
    private var showsWelcome: Bool {
        store.location == nil && store.status == .idle
    }

    /// True when the single list pins its own title. With the bar moved to the side, the
    /// navigation bar shows no title once the large title scrolls away, so the address would
    /// leave the screen.
    private var pinsTitle: Bool {
        !usesPanes && toolbarVerticalEdge != nil
    }

    /// True when your status and the nearby outages sit side by side.
    private var usesPanes: Bool {
        horizontalSizeClass == .regular && isWiderThanTall
    }

    @ViewBuilder
    private var content: some View {
        if showsWelcome {
            WelcomeView(isLocating: isLocating, onUseLocation: useCurrentLocation) {
                isPickingAddress = true
            }
            .transition(.opacity)
        } else if usesPanes {
            // On a wide display, such as the inner display of iPhone Duo in landscape, your status
            // and the nearby outages sit side by side instead of in one stretched list, and each
            // pane stays clear of the fold. Taller spaces keep the single list, which reads top
            // to bottom without cutting the status card off at a pane edge.
            ArrangementView {
                StatusPane(
                    headerLeading: $paneHeaderLeading,
                    header: Text("At This Address")
                ) {
                    statusContent
                } details: {
                    detailsSection
                        .listRowBackground(Color.cardBackground)
                }
                // The title is pinned above this pane only, so it never scrolls and never reaches
                // the fold. Content fades out under it rather than frosting.
                .safeAreaBar(edge: .top) {
                    paneTitleBar
                        .background { PaneScrim() }
                }
            } secondary: {
                List {
                    Group {
                        nearbySection
                        if store.status != .loading && store.status != .idle && store.nearby.isEmpty {
                            Section {
                                ContentUnavailableView("No Nearby Outages", systemImage: "checkmark.circle")
                            } header: {
                                Text("Nearby Outages")
                                    .foregroundStyle(.white)
                            }
                        }
                        reportSection
                    }
                    .listRowBackground(Color.cardBackground)
                }
                .modifier(SplitPaneGutter(edge: .leading))
                .onScrollGeometryChange(for: CGFloat.self, of: footerSlack, action: updateFooterGap)
                // Only this pane refreshes, so pulling it leaves the status pane beside it still.
                .refreshable { await store.load() }
                // Empty space as tall as the title beside it, so both panes' cards start level,
                // with the same fade for content scrolling under it.
                .safeAreaBar(edge: .top) {
                    Color.clear
                        .frame(height: paneTitleHeight)
                        .background { PaneScrim() }
                }
            }
            .arrangementViewStyle(.split.axes(.horizontal))
            // The system's edge effect drew a lighter, hard-edged block behind the title, and only
            // over the pane that scrolled. The scrims above replace it.
            .scrollEdgeEffectHidden(true, for: .top)
        } else {
            List {
                Group {
                    statusSection
                    detailsSection
                    nearbySection
                    reportSection
                }
                .listRowBackground(Color.cardBackground)
            }
            .onScrollGeometryChange(for: CGFloat.self, of: footerSlack, action: updateFooterGap)
            .refreshable { await store.load() }
            // On the outer display the address would scroll away with no title left in the bar,
            // so it's pinned at the top instead.
            .modifier(PinnedTitle(title: String(localized: "Outages"), detail: addressLine, isActive: pinsTitle))
            // Cards scrolling under the bottom search field fade into the page, like the pane
            // titles do at the top. The system's soft edge effect barely shows over white cards.
            .scrollEdgeEffectHidden(!pinsTitle, for: .bottom)
            .overlay(alignment: .bottom) {
                if !pinsTitle {
                    // Tall enough to reach above the search field, and extends down past the
                    // home indicator.
                    PaneScrim(edge: .bottom)
                        .frame(height: 72)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    /// Empty space left below the list's content, or negative when it overflows.
    private func footerSlack(_ geometry: ScrollGeometry) -> CGFloat {
        geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom - geometry.contentSize.height
    }

    /// Grows the gap above the footer into any empty space, and shrinks it back as rows arrive, so
    /// the footer rests at the bottom of a short list and follows the content of a long one.
    private func updateFooterGap(_ oldSlack: CGFloat, _ slack: CGFloat) {
        let gap = max(0, footerGap + slack)
        guard abs(gap - footerGap) > 0.5 else { return }
        withAnimation(reduceMotion ? nil : .default) {
            footerGap = gap
        }
    }

    // MARK: - Sections

    /// The title and address, pinned above the status pane and lined up with its headers. It stays
    /// within the pane whether the display is fully open or partly folded, wrapping onto more lines
    /// as it needs.
    private var paneTitleBar: some View {
        let inset = max(paneHeaderLeading - titleBarLeading, 0)
        return SideBarTitle(title: String(localized: "Outages"), detail: addressLine)
            .padding(.horizontal, inset)
            .padding(.top, paneTitleTopPadding)
            // Room below for the scrim's fade, before the section headers.
            .padding(.bottom, PaneScrim.titleBottomSpacing)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                titleBarLeading = frame.minX
                paneTitleHeight = frame.height
            }
    }

    private var statusSection: some View {
        Section {
            // Keeps its natural size on every display, folded or not, so it never resizes as
            // the list scrolls.
            statusContent
        }
    }

    /// What's happening at the chosen location.
    @ViewBuilder
    private var statusContent: some View {
        switch store.status {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 200)
        case .outages:
            if let outage = store.outages.first {
                OutageSummary(outage: outage)
            }
        case .none:
            ContentUnavailableView(
                "No Outages Reported",
                systemImage: "bolt.fill",
                description: Text("No outages are reported at this location. Outage data refreshes about every 15 minutes, so check back soon if your power is out.")
            )
        case .outsideTerritory:
            ContentUnavailableView(
                "Outside Service Area",
                systemImage: "mappin.slash",
                description: Text("Outages can’t be shown for this location.")
            )
        case .failed:
            ContentUnavailableView {
                Label("Unable to Load Outages", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Try Again") { Task { await store.load() } }
            }
        }
    }

    /// Customers affected, start time and county for the outage at the chosen address.
    @ViewBuilder
    private var detailsSection: some View {
        if store.status == .outages, let outage = store.outages.first {
            OutageDetailsSection(outage: outage)
        }
    }

    @ViewBuilder
    private var nearbySection: some View {
        if (store.status == .outages || store.status == .none) && !store.nearby.isEmpty {
            Section {
                ForEach(store.nearby) { outage in
                    NavigationLink(value: outage) {
                        NearbyOutageRow(outage: outage, origin: store.location?.coordinate, placeName: store.placeNames[outage.id])
                    }
                    .task(id: outage.id) { await store.lookUpPlaceName(for: outage) }
                    .contextMenu {
                        if let centroid = outage.centroid {
                            Button("Open in Maps", systemImage: "map") {
                                openInMaps(centroid, name: store.placeNames[outage.id])
                            }
                        }
                    }
                }
            } header: {
                // White stays readable on the blue background.
                Text("Nearby Outages")
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private var reportSection: some View {
        if store.status != .loading {
            Section {
                Link(destination: Self.reportURL) {
                    Label("Report an Outage", systemImage: "exclamationmark.bubble")
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    if let lastChecked = store.lastChecked {
                        Text("Last updated \(lastChecked, format: .dateTime.hour().minute())")
                            .foregroundStyle(.white)
                    }
                    OfficialOutagesNotice()
                }
                .padding(.top, footerGap)
            }
        }
    }

    // MARK: - Search

    @ViewBuilder
    private var suggestions: some View {
        #if DEBUG
        // Typing "#12345" looks up a single outage by incident ID.
        if let match = completer.query.wholeMatch(of: /#(\d+)/), let id = Int(match.1) {
            Button("Fetch outage #\(id)", systemImage: "magnifyingglass") {
                isSearching = false
                Task { await store.lookUp(incidentID: id) }
            }
        }
        #endif
        ForEach(completer.results, id: \.self) { completion in
            Button {
                choose(completion)
            } label: {
                AddressSuggestionLabel(completion: completion)
            }
            .tint(.primary)
        }
    }

    private var addressLine: String {
        guard let location = store.location else { return "" }
        return [location.title, location.subtitle].compactMap(\.self).joined(separator: ", ")
    }

    /// Shows where an outage is in the Maps app.
    private func openInMaps(_ coordinate: CLLocationCoordinate2D, name: String?) {
        let item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
        item.name = name.map { String(localized: "Outage near \($0)") } ?? String(localized: "Outage")
        item.openInMaps()
    }

    private func choose(_ completion: MKLocalSearchCompletion) {
        isSearching = false
        completer.query = ""
        Task {
            do {
                await store.select(try await Places.resolve(completion))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func useCurrentLocation() {
        isSearching = false
        isLocating = true
        Task {
            defer { isLocating = false }
            do {
                await store.select(try await Places.currentLocation())
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Holds the status for the chosen address in one card of a set height, so it ends level with the
/// Report an Outage button beside it and never resizes as either pane scrolls.
private struct StatusPane<Content: View, Details: View>: View {
    /// Where the section headers start, in global coordinates, so a title above can line up with them.
    @Binding var headerLeading: CGFloat
    /// The card's header, such as "At This Address".
    let header: Text
    @ViewBuilder var content: Content
    /// Sections below the card, such as the outage's details.
    @ViewBuilder var details: Details

    /// The card's height, padding included, matching three nearby rows and the Report an Outage
    /// button. It scales with Dynamic Type, and grows rather than clips if the content needs more.
    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 376

    var body: some View {
        // A list, like the pane beside it, so the header, margins and card shape match exactly.
        List {
            Section {
                content
                    .padding(20)
                    .frame(maxWidth: .infinity, minHeight: cardHeight)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.cardBackground)
            } header: {
                header
                    .foregroundStyle(.white)
                    // One line, so the card starts level with the card beside it.
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .contentTransition(.opacity)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minX } action: {
                        headerLeading = $0
                    }
            }
            details
        }
        .modifier(SplitPaneGutter(edge: .trailing))
        // The pane never shows a scroll bar beside the fold.
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
    }
}

/// The page's flat blue behind a pinned bar, fading out at the bar's bottom edge, so content
/// scrolling under the bar fades away softly. On a flat background this reads the same as fading
/// the content itself, with no frosted block or hard line, and looks identical in both panes.
struct PaneScrim: View {
    /// The edge the bar sits on. The scrim is solid there and fades out toward the content.
    var edge: VerticalEdge = .top

    /// The space a pinned title leaves below itself, for the top scrim's fade.
    static let titleBottomSpacing: CGFloat = 32
    /// How far the top fade reaches below the bar. Kept small, so the section headers just below
    /// stay at full strength when the list is at rest.
    private static let topFadeOverhang: CGFloat = 8
    /// The top scrim's fade. It runs through the space below the title, so the scrim is solid
    /// behind the title itself and content never shows through it.
    private static let topFadeHeight: CGFloat = titleBottomSpacing + topFadeOverhang

    var body: some View {
        switch edge {
        case .top:
            VStack(spacing: 0) {
                Color.pageBackground
                Color.pageBackground
                    .mask {
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    }
                    .frame(height: Self.topFadeHeight)
            }
            .padding(.bottom, -Self.topFadeOverhang)
            .ignoresSafeArea(edges: .top)
        case .bottom:
            Color.pageBackground
                .mask {
                    LinearGradient(
                        stops: [.init(color: .black, location: 0.4), .init(color: .clear, location: 1)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

/// Adds the system gutter on the edge a pane shares with its neighbor, so side-by-side cards don't
/// touch at the center of the display. Stacked panes already get vertical spacing from their lists.
private struct SplitPaneGutter: ViewModifier {
    let edge: Edge.Set

    @Environment(\.splitArrangementAxis) private var axis

    func body(content: Content) -> some View {
        // Half the gutter on each pane, so the cards end up a standard spacing apart.
        content
            .contentMargins(axis == .horizontal ? edge : [], 10, for: .scrollContent)
    }
}

#Preview("Outage") {
    ContentView(store: .preview())
}

#Preview("No Outages") {
    ContentView(store: .preview(status: .none))
}

#Preview("Welcome") {
    ContentView(store: OutageStore(location: nil))
}
