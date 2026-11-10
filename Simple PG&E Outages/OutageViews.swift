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

// MARK: - Restore gauge

/// A semicircular gauge that fills from the outage's start time to its estimated restore time.
struct RestoreGauge: View {
    let outage: Outage

    var body: some View {
        // Re-evaluate every 30 seconds so the remaining time stays current.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            RestoreGaugeContent(outage: outage, now: context.date)
        }
    }
}

private struct RestoreGaugeContent: View {
    let outage: Outage
    let now: Date

    @State private var displayedProgress = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let progress = outage.progress(at: now)
        Gauge(value: displayedProgress) {
            Text("Estimated fix")
        } currentValueLabel: {
            Text(outage.remainingText(at: now) ?? String(localized: "Unknown"))
                .contentTransition(.numericText())
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
        .animation(reduceMotion ? nil : .default, value: outage.remainingText(at: now))
        .onAppear { setProgress(progress) }
        .onChange(of: progress) { _, newValue in setProgress(newValue) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Estimated fix")
        .accessibilityValue(outage.remainingText(at: now).map { String(localized: "\($0) remaining") } ?? String(localized: "Unknown"))
    }

    /// Sweeps the arc to its value, or jumps there when Reduce Motion is on.
    private func setProgress(_ value: Double) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 1)) {
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

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(outage.distanceText(from: origin) ?? "—", systemImage: "mappin.and.ellipse")
                    OutageKindBadge(isPlanned: outage.isPlanned)
                }
                Spacer()
                if let remaining = outage.remainingText(at: context.date) {
                    Text(remaining)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                Gauge(value: outage.progress(at: context.date)) {
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
}

// MARK: - Detail

/// Full information about an outage reached from the nearby list.
struct OutageDetailView: View {
    let outage: Outage
    let origin: CLLocationCoordinate2D?

    var body: some View {
        List {
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
        .navigationTitle(outage.distanceText(from: origin).map { String(localized: "Outage \($0) Away") } ?? String(localized: "Nearby Outage"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Summary") {
    let store = OutageStore.preview()
    List {
        if let outage = store.outages.first {
            OutageSummary(outage: outage)
        }
        ForEach(store.nearby) { outage in
            NearbyOutageRow(outage: outage, origin: store.location?.coordinate)
        }
    }
}
