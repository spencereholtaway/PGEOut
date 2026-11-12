import SwiftUI
import MapKit

/// A sheet for finding an address, opened from the welcome screen. Search is active as soon
/// as it appears, and picking a suggestion hands it back and closes the sheet.
struct AddressSearchSheet: View {
    @Bindable var completer: AddressCompleter
    var onSelect: (MKLocalSearchCompletion) -> Void

    @State private var isSearchActive = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(completer.results, id: \.self) { completion in
                Button {
                    onSelect(completion)
                } label: {
                    AddressSuggestionLabel(completion: completion)
                }
                .tint(.primary)
            }
            .overlay {
                if completer.results.isEmpty {
                    ContentUnavailableView(
                        "Find Your Address",
                        systemImage: "house",
                        description: Text("Start typing a street address in PG&E’s service area.")
                    )
                }
            }
            .navigationTitle("Search for an Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .searchable(text: $completer.query, isPresented: $isSearchActive, prompt: "Street address")
            // Keeps the title and Cancel in place while searching, so one tap closes the sheet
            // and the field doesn't jump up as search activates.
            .searchPresentationToolbarBehavior(.avoidHidingContent)
            .task { isSearchActive = true }
        }
    }
}

/// A search suggestion's street on the first line and its city on the second.
struct AddressSuggestionLabel: View {
    let title: String
    let subtitle: String

    init(completion: MKLocalSearchCompletion) {
        self.init(title: completion.title, subtitle: completion.subtitle)
    }

    init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        // One Text holding both lines, because on wide displays, such as the inner display of
        // iPhone Duo, search suggestions keep only the first Text of a row and drop the city.
        if subtitle.isEmpty {
            Text(title)
        } else {
            Text("\(title)\n\(Text(subtitle).font(.subheadline).foregroundStyle(.secondary))")
        }
    }
}

#Preview("Suggestions") {
    NavigationStack {
        Color.clear
            .navigationTitle("Outages")
            .searchable(text: .constant("214 alpine"), isPresented: .constant(true))
            .searchSuggestions {
                ForEach(["San Rafael, CA, United States", "Mammoth Lakes, CA, United States"], id: \.self) { city in
                    Button {} label: {
                        AddressSuggestionLabel(title: "214 Alpine St", subtitle: city)
                    }
                    .tint(.primary)
                }
            }
    }
}
