import SwiftUI
import MapKit

struct ContentView: View {
    @State private var store: OutageStore
    @State private var completer = AddressCompleter()
    @State private var isSearching = false
    @State private var isLocating = false
    @State private var errorMessage: String?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let reportURL = URL(string: "https://www.pge.com/en/contact-us/report-an-issue/report-electric-issue.html")!

    init(store: OutageStore = OutageStore()) {
        _store = State(initialValue: store)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Outages")
                .navigationSubtitle(addressLine)
                .navigationDestination(for: Outage.self) { outage in
                    OutageDetailView(outage: outage, origin: store.location?.coordinate)
                }
                .searchable(text: $completer.query, isPresented: $isSearching, prompt: "Search for an address")
                .searchSuggestions { suggestions }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Use My Location", systemImage: "location", action: useCurrentLocation)
                            .disabled(isLocating)
                    }
                }
                .refreshable { await store.load() }
                .alert("Couldn’t Find Location", isPresented: .constant(errorMessage != nil)) {
                    Button("OK") { errorMessage = nil }
                } message: {
                    Text(errorMessage ?? "")
                }
        }
        .animation(reduceMotion ? nil : .default, value: store.status)
        .animation(reduceMotion ? nil : .default, value: store.nearby)
        .task {
            if store.location == nil {
                isSearching = true
            } else {
                await store.load()
            }
        }
        .task {
            // Check for new outage data every 15 minutes while the app is open.
            while !Task.isCancelled {
                try? await Task.sleep(for: OutageStore.refreshInterval)
                await store.refreshIfChanged()
            }
        }
    }

    // MARK: - Layout

    @ViewBuilder
    private var content: some View {
        if store.location == nil && store.status == .idle {
            welcome
        } else if horizontalSizeClass == .regular {
            // Wide layouts, such as the iPhone Duo inner display, keep the
            // outage status and the nearby list on either side of the fold.
            ArrangementView {
                List { statusSection }
            } secondary: {
                List {
                    nearbySection
                    reportSection
                }
            }
            .arrangementViewStyle(.split.axes(.horizontal))
        } else {
            List {
                statusSection
                nearbySection
                reportSection
            }
        }
    }

    private var welcome: some View {
        ContentUnavailableView {
            Label("Search for Outages", systemImage: "bolt.slash")
        } description: {
            Text("Enter your address or use your location to find outages near you.")
        } actions: {
            Button("Use My Location", systemImage: "location.fill", action: useCurrentLocation)
                .buttonStyle(.borderedProminent)
                .disabled(isLocating)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var statusSection: some View {
        Section {
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
    }

    @ViewBuilder
    private var nearbySection: some View {
        if (store.status == .outages || store.status == .none) && !store.nearby.isEmpty {
            Section("Nearby Outages") {
                ForEach(store.nearby) { outage in
                    NavigationLink(value: outage) {
                        NearbyOutageRow(outage: outage, origin: store.location?.coordinate)
                    }
                }
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
                VStack(alignment: .leading, spacing: 4) {
                    if let lastChecked = store.lastChecked {
                        Text("Last updated \(lastChecked, format: .dateTime.hour().minute())")
                    }
                    Text("Designed and built (with Claude), Spencer Holtaway 2026")
                }
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
                VStack(alignment: .leading) {
                    Text(completion.title)
                    if !completion.subtitle.isEmpty {
                        Text(completion.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tint(.primary)
        }
    }

    private var addressLine: String {
        guard let location = store.location else { return "" }
        return [location.title, location.subtitle].compactMap(\.self).joined(separator: ", ")
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

#Preview("Outage") {
    ContentView(store: .preview())
}

#Preview("No Outages") {
    ContentView(store: .preview(status: .none))
}

#Preview("Welcome") {
    ContentView(store: OutageStore(location: nil))
}
