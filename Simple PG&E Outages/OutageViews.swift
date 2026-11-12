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

    func distanceText(from coordinate: CLLocationCoordinate2D?) -> String? {
        guard let coordinate, let distance = distance(from: coordinate) else { return nil }
        return distance.formatted(.measurement(width: .abbreviated, usage: .road))
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

/// Draws a gauge as an arc over the top half of a circle, with the value in the middle
/// and the minimum and maximum labels beneath each end.
struct RestoreArcGaugeStyle: GaugeStyle {
    var tint: Color
    var lineWidth: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                HalfArc(inset: lineWidth / 2)
                    .stroke(.quaternary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                HalfArc(inset: lineWidth / 2)
                    .trim(from: 0, to: configuration.value)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                VStack(spacing: 2) {
                    configuration.label
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    configuration.currentValueLabel
                        .font(.largeTitle.weight(.light))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .padding(.horizontal, lineWidth * 2.5)
            }
            .aspectRatio(2, contentMode: .fit)

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

/// The upper half of a circle, sitting on the bottom edge of its frame.
private struct HalfArc: Shape {
    var inset: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.maxY - inset)
        let radius = min(rect.width / 2, rect.height) - inset
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        return path
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
                Label {
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
                } icon: {
                    Image(systemName: "mappin.and.ellipse")
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
                Text("Restore progress")
            } currentValueLabel: {
                Image(systemName: outage.isPlanned ? "wrench.fill" : "bolt.fill")
                    .foregroundStyle(outage.tint)
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
    let origin: CLLocationCoordinate2D?
    var placeName: String?

    var body: some View {
        List {
            Group {
                Section {
                    OutageSummary(outage: outage)
                }
                Section("Details") {
                    if let customers = outage.impactedCustomers {
                        LabeledContent("Customers affected", value: customers, format: .number)
                    }
                    if let start = outage.start {
                        LabeledContent("Started", value: start, format: .dateTime.weekday().hour().minute())
                    }
                    if let county = outage.county {
                        LabeledContent("County", value: county.capitalized)
                    }
                }
            }
            .listRowBackground(Color.cardBackground)
        }
        .scrollContentBackground(.hidden)
        .background(Color.pageBackground)
        .navigationTitle(outage.distanceText(from: origin).map { String(localized: "Outage \($0) Away") } ?? String(localized: "Nearby Outage"))
        .navigationSubtitle(placeName ?? "")
        .toolbar {
            ToolbarItem(placement: .largeSubtitle) {
                LargeSubtitle(text: placeName ?? "")
            }
        }
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Large subtitle

/// An address shown under a large navigation title, aligned with it. Regular weight keeps the
/// title as the single primary heading, while the size keeps the address easy to read.
struct LargeSubtitle: View {
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(.title3)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentTransition(.opacity)
            .animation(reduceMotion ? nil : .default, value: text)
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
                    OutageDetailView(outage: outage, origin: store.location?.coordinate, placeName: "105 El Cerrito Ave, San Rafael")
                }
            }
    }
}
