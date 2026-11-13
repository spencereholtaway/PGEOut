import SwiftUI
import CoreLocation

// MARK: - Formatting

extension Outage {
    var tint: Color { isPlanned ? .green : .orange }

    /// Time left until the estimated restore, such as "1h 30m".
    func remainingText(at now: Date) -> String? {
        guard let estimatedRestore else { return nil }
        let seconds = max(0, estimatedRestore.timeIntervalSince(now))
        return Duration.seconds(seconds)
            .formatted(.units(allowed: [.days, .hours, .minutes], width: .narrow, maximumUnitCount: 2))
    }

    /// Distance to the outage, such as "0.3 mi", "4.1 mi" or "14 mi". Feet are only used under
    /// 0.1 mi, where tenths of a mile stop being meaningful. Metric locales keep the system's road units.
    func distanceText(from coordinate: CLLocationCoordinate2D?) -> String? {
        guard let coordinate, let distance = distance(from: coordinate) else { return nil }
        guard Locale.current.measurementSystem != .metric else {
            return distance.formatted(.measurement(width: .abbreviated, usage: .road))
        }
        let miles = distance.converted(to: .miles)
        if miles.value < 0.1 {
            // Nearest 10 ft, since more precision than that would be false.
            let feet = (distance.converted(to: .feet).value / 10).rounded() * 10
            return Measurement(value: feet, unit: UnitLength.feet)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))
        }
        let decimals = miles.value < 10 ? 1 : 0
        return miles.formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(decimals))))
    }
}

// MARK: - Badge

/// A small capsule reading "Planned" or "Unplanned".
struct OutageKindBadge: View {
    let isPlanned: Bool

    var body: some View {
        let tint: Color = isPlanned ? .green : .orange
        Text(isPlanned ? "Planned" : "Unplanned")
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15), in: .capsule)
    }
}

// MARK: - Clock

extension EnvironmentValues {
    /// The time countdowns are drawn for. `ContentView` advances it on each minute from one
    /// shared timeline, since labels only show minutes.
    @Entry var now: Date = .now
}

// MARK: - Restore gauge

/// A semicircular gauge that fills from the outage's start time to its estimated restore time.
struct RestoreGauge: View {
    let outage: Outage

    @State private var displayedProgress = 0.0
    @Environment(\.now) private var now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let progress = outage.progress(at: now)
        let remaining = outage.remainingText(at: now)
        Gauge(value: displayedProgress) {
            Text("Estimated fix")
        } currentValueLabel: {
            Text(remaining ?? String(localized: "Unknown"))
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .default, value: remaining)
        } minimumValueLabel: {
            if let start = outage.start {
                Text(start, format: timeFormat(for: start))
            }
        } maximumValueLabel: {
            if let restore = outage.estimatedRestore {
                Text(restore, format: timeFormat(for: restore))
            }
        }
        .gaugeStyle(RestoreArcGaugeStyle(tint: outage.tint))
        .onAppear { setProgress(progress, animated: true) }
        .onChange(of: progress) { oldValue, newValue in
            // Each minute the arc moves a hair, too little to see, so skip a second-long animation
            // for it. Visible moves, like a new estimate, still sweep.
            setProgress(newValue, animated: abs(newValue - oldValue) > 0.02)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Estimated fix")
        .accessibilityValue(remaining.map { String(localized: "\($0) remaining") } ?? String(localized: "Unknown"))
    }

    /// Sweeps the arc to its value, or jumps there when Reduce Motion is on.
    private func setProgress(_ value: Double, animated: Bool) {
        withAnimation(animated && !reduceMotion ? .easeOut(duration: 1) : nil) {
            displayedProgress = value
        }
    }

    /// Shows only the time for today, and adds the weekday for other days.
    private func timeFormat(for date: Date) -> Date.FormatStyle {
        Calendar.current.isDate(date, inSameDayAs: now)
            ? .dateTime.hour().minute()
            : .dateTime.weekday(.abbreviated).hour().minute()
    }
}

/// Draws a gauge as an arc over the top half of a circle, with the value centered inside it
/// and the minimum and maximum labels beneath each end.
struct RestoreArcGaugeStyle: GaugeStyle {
    var tint: Color

    /// The arc's thickness for an arc of the given width: 16 pt on a full-size gauge, thinner as a
    /// short card shrinks the arc, so a small arc keeps the same proportions instead of turning chunky.
    static func lineWidth(forArcWidth width: CGFloat) -> CGFloat {
        min(16, max(6, width / 22))
    }

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 6) {
            ZStack {
                HalfArc()
                    .fill(.quaternary)
                HalfArc(progress: configuration.value)
                    .fill(tint)
            }
            .aspectRatio(2, contentMode: .fit)
            .overlay {
                ArcCenterLabels {
                    configuration.label
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } value: {
                    configuration.currentValueLabel
                        .font(.largeTitle.weight(.light))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                }
                .lineLimit(1)
            }

            HStack {
                configuration.minimumValueLabel
                Spacer()
                configuration.maximumValueLabel
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}

/// The caption and value inside the arc, set a little below its middle so they look centered under
/// the dome rather than riding high. They keep their natural size
/// when they fit. In a smaller arc the caption fades out first, then the value scales down, so the
/// text never crowds the arc or turns tiny.
private struct ArcCenterLabels<Caption: View, Value: View>: View {
    @ViewBuilder var caption: Caption
    @ViewBuilder var value: Value

    /// The arc's frame.
    @State private var available = CGSize.zero
    @State private var captionSize = CGSize.zero
    @State private var valueSize = CGSize.zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let captionSpacing: CGFloat = 2
    /// How far down the arc's frame the text centers. A dome's open space sits low, so true center
    /// looks too high.
    private let verticalPosition: CGFloat = 0.6

    var body: some View {
        let showsCaption = self.showsCaption
        Color.clear
            .onGeometryChange(for: CGSize.self) { $0.size } action: { available = $0 }
            .overlay {
                value
                    .fixedSize()
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { valueSize = $0 }
                    .overlay(alignment: .top) {
                        caption
                            .fixedSize()
                            .onGeometryChange(for: CGSize.self) { $0.size } action: { captionSize = $0 }
                            .alignmentGuide(.top) { $0[.bottom] + captionSpacing }
                            .opacity(showsCaption ? 1 : 0)
                    }
                    .scaleEffect(showsCaption ? 1 : valueScale)
                    // Centers the caption and value together, or the value alone, at the optical center.
                    .offset(y: (showsCaption ? (captionSize.height + captionSpacing) / 2 : 0)
                        + available.height * (verticalPosition - 0.5))
            }
            .animation(reduceMotion ? nil : .default, value: showsCaption)
    }

    /// True when the caption and value both fit at their natural size.
    private var showsCaption: Bool {
        let width = max(captionSize.width, valueSize.width)
        let height = captionSize.height + captionSpacing + valueSize.height
        return fittingScale(width: width, height: height) >= 1
    }

    /// The value's scale when it's shown alone, never enlarged.
    private var valueScale: CGFloat {
        min(1, fittingScale(width: valueSize.width, height: valueSize.height))
    }

    /// The largest scale at which a box of this size, centered at the optical center, stays clear of
    /// the arc's inner edge.
    private func fittingScale(width: CGFloat, height: CGFloat) -> CGFloat {
        guard width > 0, height > 0, available.width > 0 else { return 1 }
        let lineWidth = RestoreArcGaugeStyle.lineWidth(forArcWidth: available.width)
        // The arc's inner edge, less a margin so text doesn't touch it.
        let radius = min(available.width / 2, available.height) - lineWidth - 6
        // The box's center, measured up from the arc's center on the bottom edge.
        let middle = available.height * (1 - verticalPosition)
        guard radius > middle else { return 0 }
        // The box's top corners, at (±s·w/2, middle + s·h/2) from the arc's center, must lie
        // within the radius: solve a·s² + b·s + c = 0 for the largest s.
        let a = (width / 2) * (width / 2) + (height / 2) * (height / 2)
        let b = middle * height
        let c = middle * middle - radius * radius
        let corners = (-b + (b * b - 4 * a * c).squareRoot()) / (2 * a)
        // Its bottom must also stay above the arc's ends.
        let bottom = 2 * middle / height
        return max(min(corners, bottom), 0)
    }
}

/// The upper half of a circle, sitting on the bottom edge of its frame, drawn as a filled stroke
/// whose thickness follows the arc's size. `progress` trims it from the left end and animates.
private struct HalfArc: Shape {
    var progress: Double = 1

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let lineWidth = RestoreArcGaugeStyle.lineWidth(forArcWidth: rect.width)
        let center = CGPoint(x: rect.midX, y: rect.maxY - lineWidth / 2)
        let radius = min(rect.width / 2, rect.height) - lineWidth / 2
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        guard progress > 0 else { return Path() }
        return path
            .trimmedPath(from: 0, to: min(progress, 1))
            .strokedPath(StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
}

// MARK: - Summary

/// The kind, cause and restore estimate for one outage.
struct OutageSummary: View {
    let outage: Outage

    var body: some View {
        VStack(spacing: 16) {
            OutageKindBadge(isPlanned: outage.isPlanned)
            Text(outage.causeDescription)
                .font(.title3)
                .multilineTextAlignment(.center)
            RestoreGauge(outage: outage)
                .frame(maxWidth: 360)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Nearby row

/// A list row with an outage's distance, kind and restore progress.
struct NearbyOutageRow: View {
    let outage: Outage
    let origin: CLLocationCoordinate2D?
    /// Roughly where the outage is, once it has been looked up.
    var placeName: String?

    @Environment(\.now) private var now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(outage.distanceText(from: origin) ?? "—")
                    if let placeName {
                        Text(Places.streetAndCity(placeName))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .transition(.opacity)
                    }
                }
                OutageKindBadge(isPlanned: outage.isPlanned)
            }
            .animation(reduceMotion ? nil : .default, value: placeName)
            Spacer()
            if let remaining = outage.remainingText(at: now) {
                Text(remaining)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Gauge(value: outage.progress(at: now)) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(outage.tint)
            .scaleEffect(0.6)
            .frame(width: 36, height: 36)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Detail

/// Full information about an outage reached from the nearby list.
struct OutageDetailView: View {
    let outage: Outage
    var placeName: String?

    @State private var isWiderThanTall = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// The side the system moves the bars to, as on the outer display of iPhone Duo, or nil.
    @Environment(\.toolbarVerticalEdge) private var toolbarVerticalEdge

    var body: some View {
        content
            .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height } action: {
                isWiderThanTall = $0
            }
            .scrollContentBackground(.hidden)
        .background { PageBackground() }
        .modifier(AdaptiveNavigationTitle(
            title: title,
            subtitle: placeName ?? "",
            placement: isSideBySide ? .bar : pinsTitle ? .pinned : .list
        ))
    }

    /// True when the list pins its own title, as the main screen does, because the navigation bar
    /// shows no title once the large title scrolls away.
    private var pinsTitle: Bool {
        !isSideBySide && toolbarVerticalEdge != nil
    }

    /// Just "Outage" before the address, without the distance.
    private var title: String {
        String(localized: "Outage")
    }

    private var isSideBySide: Bool {
        horizontalSizeClass == .regular && isWiderThanTall
    }

    @ViewBuilder
    private var content: some View {
        if isSideBySide {
            // On a wide display, such as the inner display of iPhone Duo in landscape, the restore
            // gauge and the details sit in their own panes, clear of the fold, instead of one list
            // stretched across both halves with the details pushed off the bottom.
            ArrangementView {
                List {
                    summarySection(header: "Status")
                        .listRowBackground(Color.cardBackground)
                }
                // Half the system gutter on the shared edge, so the cards sit a standard spacing apart.
                .contentMargins(.trailing, 10, for: .scrollContent)
            } secondary: {
                List {
                    detailsSection
                        .listRowBackground(Color.cardBackground)
                }
                .contentMargins(.leading, 10, for: .scrollContent)
            }
            .arrangementViewStyle(.split.axes(.horizontal))
            // Both cards usually fit, so the panes stay still unless large text makes them overflow.
            .scrollBounceBehavior(.basedOnSize)
        } else {
            List {
                if !pinsTitle {
                    ListTitle(title: title, detail: placeName ?? "")
                }
                Group {
                    summarySection(header: nil)
                    detailsSection
                }
                .listRowBackground(Color.cardBackground)
            }
            .modifier(PinnedTitle(title: title, detail: placeName ?? "", isActive: pinsTitle))
        }
    }

    /// The restore gauge card. Beside the details it gets a header too, so both cards start level.
    private func summarySection(header: LocalizedStringKey?) -> some View {
        Section {
            OutageSummary(outage: outage)
        } header: {
            if let header {
                // White stays readable on the blue background.
                Text(header)
                    .foregroundStyle(.white)
            }
        }
    }

    private var detailsSection: some View {
        OutageDetailsSection(outage: outage)
    }
}

// MARK: - Details section

/// Customers affected, start time and county for an outage, shared by the main screen and the
/// detail screen. Left out entirely when the feed has none of them, so no empty card shows.
struct OutageDetailsSection: View {
    let outage: Outage

    var body: some View {
        if outage.impactedCustomers != nil || outage.start != nil || outage.county != nil {
            Section {
                if let customers = outage.impactedCustomers {
                    LabeledContent("Customers affected", value: customers, format: .number)
                }
                if let start = outage.start {
                    LabeledContent("Started", value: start, format: .dateTime.weekday().hour().minute())
                }
                if let county = outage.county {
                    LabeledContent("County", value: county.capitalized)
                }
            } header: {
                // White stays readable on the blue background.
                Text("Details")
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview("Summary") {
    let store = OutageStore.preview()
    List {
        if let outage = store.outages.first {
            OutageSummary(outage: outage)
        }
        ForEach(store.nearby) { outage in
            NearbyOutageRow(outage: outage, origin: store.location?.coordinate, placeName: store.placeNames[outage.id])
        }
    }
}

#Preview("Detail") {
    let store = OutageStore.preview()
    // Pushed onto a root screen, as in the app, so the back button shows.
    NavigationStack {
        Text("Outages")
            .navigationTitle("Outages")
            .navigationDestination(isPresented: .constant(true)) {
                if let outage = store.nearby.first {
                    OutageDetailView(outage: outage, placeName: "105 El Cerrito Ave, San Rafael")
                }
            }
    }
}

// MARK: - Navigation title

/// Where a screen shows its run-on title.
enum TitlePlacement {
    /// The first row of the screen's list, with the bar showing a compact title once it scrolls
    /// away. It slides with its screen when navigating, as the bar's large title area doesn't:
    /// with custom content there, the bar draws both screens' titles on top of each other.
    case list
    /// Pinned above the list with `PinnedTitle`, so the bar shows no title at all.
    case pinned
    /// The bar's large title area, above side-by-side panes.
    case bar
}

/// The navigation title for a screen with the run-on title, in orange and white, as the year
/// follows the month in Calendar. The address never truncates and wraps onto as many lines as it
/// needs. The navigation title still names the screen for the back button and accessibility.
struct AdaptiveNavigationTitle: ViewModifier {
    let title: String
    let subtitle: String
    var placement: TitlePlacement

    /// True once the list's title has scrolled under the bar.
    @State private var isListTitleHidden = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far the list scrolls before the bar shows its compact title, about one title line.
    private static let compactTitleOffset: CGFloat = 32

    func body(content: Content) -> some View {
        content
            // Still named, for the back button's menu and accessibility.
            .navigationTitle(title)
            .toolbarTitleDisplayMode(placement == .bar ? .large : .inline)
            // The list's title starts just below the bar, where a large title sits.
            .contentMargins(placement == .list ? .top : [], 0, for: .scrollContent)
            // Only reports a change when the title crosses under the bar, not on every frame.
            .onScrollGeometryChange(for: Bool.self) { geometry in
                placement == .list && geometry.contentOffset.y + geometry.contentInsets.top > Self.compactTitleOffset
            } action: { _, isHidden in
                withAnimation(reduceMotion ? nil : .default) {
                    isListTitleHidden = isHidden
                }
            }
            // The system's edge effect draws a frosted block that the content shows through. The
            // bar takes the page's flat blue instead, fading in once the list's title is gone.
            .scrollEdgeEffectHidden(placement == .list, for: .top)
            .overlay(alignment: .top) {
                if placement == .list {
                    BarScrim()
                        .opacity(isListTitleHidden ? 1 : 0)
                        .allowsHitTesting(false)
                }
            }
            .toolbar {
                if placement == .pinned {
                    // An empty title view, so the bar doesn't repeat the pinned title above it.
                    ToolbarItem(placement: .principal) {
                        Color.clear
                            .frame(width: 0, height: 0)
                            .accessibilityHidden(true)
                    }
                } else if placement == .list {
                    // Empty while the list's own title shows, then fades in as it scrolls away.
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 0) {
                            Text(title)
                                .font(.headline)
                            if !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                        }
                        // White stays readable on the blue background.
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .opacity(isListTitleHidden ? 1 : 0)
                        .accessibilityHidden(!isListTitleHidden)
                    }
                } else {
                    ToolbarItem(placement: .largeTitle) {
                        SideBarTitle(title: title, detail: subtitle)
                    }
                    // Once scrolling collapses the large title, the bar shows only the plain title,
                    // so the address follows as secondary text beneath it. This slot is only used
                    // inline, so the expanded run-on title is unchanged.
                    if !subtitle.isEmpty {
                        ToolbarItem(placement: .subtitle) {
                            Text(subtitle)
                        }
                    }
                }
            }
    }
}

/// Pins the run-on title above a list, for displays where the system moves the bars to the side,
/// such as the outer display of iPhone Duo. There the navigation bar shows no title once the large
/// title scrolls away, so the address would leave the screen. Content fades out under the title
/// and, more lightly, at the bottom edge.
struct PinnedTitle: ViewModifier {
    let title: String
    let detail: String
    var isActive: Bool

    func body(content: Content) -> some View {
        content
            .safeAreaBar(edge: .top) {
                if isActive {
                    SideBarTitle(title: title, detail: detail)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, PaneScrim.titleBottomSpacing)
                        .background { PaneScrim() }
                }
            }
            // The scrims replace the system's edge effects, which barely show over white cards.
            .scrollEdgeEffectHidden(isActive, for: [.top, .bottom])
            // Room below the last row, so it can scroll clear of the fade.
            .contentMargins(isActive ? .bottom : [], PaneScrim.edgeFadeHeight, for: .scrollContent)
            .overlay(alignment: .bottom) {
                if isActive {
                    // Nothing sits at the bottom with the bars at the side, so a short, light
                    // fade is enough.
                    PaneScrim(edge: .bottom)
                        .frame(height: PaneScrim.edgeFadeHeight)
                        .opacity(0.8)
                        .allowsHitTesting(false)
                }
            }
    }
}

/// The page's flat blue behind the navigation bar, from the top of the screen to the bar's bottom
/// edge, then fading out over the content below.
private struct BarScrim: View {
    private static let fadeHeight: CGFloat = 16

    var body: some View {
        LinearGradient(colors: [.pageBackground, .pageBackground.opacity(0)], startPoint: .top, endPoint: .bottom)
            .frame(height: Self.fadeHeight)
            .background(alignment: .bottom) {
                // Reaches up through the bar and the status bar.
                Color.pageBackground
                    .padding(.bottom, Self.fadeHeight)
                    .ignoresSafeArea(edges: .top)
            }
    }
}

/// The run-on title as the first row of a list, where the large title would sit, so it scrolls
/// and slides with the screen's content.
struct ListTitle: View {
    let title: String
    let detail: String

    var body: some View {
        // A section header rather than a row, as rows clip their content, cutting off the
        // overhang of the first letter on each line.
        Section {
        } header: {
            SideBarTitle(title: title, detail: detail)
                .textCase(nil)
                .listRowInsets(EdgeInsets())
        }
        // As close to the first card as a large title sits.
        .listSectionSpacing(8)
    }
}

/// The title in PG&E orange followed by the detail in white, such as "Outages Van Ness, San Francisco".
/// The detail wraps onto more lines rather than truncating, so the full address always shows.
struct SideBarTitle: View {
    let title: String
    let detail: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("\(Text(title).foregroundStyle(.pgeOrange)) \(Text(detail).foregroundStyle(.white))")
            // The size the system uses for large titles inside the bar, as in Files.
            .font(.title.bold())
            .fixedSize(horizontal: false, vertical: true)
            // Fill the title slot so the text starts at the leading edge, as in Files.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentTransition(.opacity)
            .animation(reduceMotion ? nil : .default, value: detail)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Page background

/// A flat PG&E blue, or PG&E navy in dark mode.
struct PageBackground: View {
    var body: some View {
        Color.pageBackground
            .ignoresSafeArea()
    }
}

// MARK: - Disclaimer

/// Makes clear this isn't PG&E's app and points people to PG&E's own outage map for safety.
struct OfficialOutagesNotice: View {
    private static let officialURL = URL(string: "https://pgealerts.alerts.pge.com/outage-tools/outage-map/")!

    var body: some View {
        Text("This is not an official PG&E app. If safety is a concern, please visit \(link).")
            .foregroundStyle(.white)
            // Blue link text gets lost on the blue background, so the link is white and underlined.
            .tint(.white)
    }

    private var link: AttributedString {
        var link = AttributedString(localized: "PG&E’s official outages service")
        link.link = Self.officialURL
        link.underlineStyle = .single
        return link
    }
}
