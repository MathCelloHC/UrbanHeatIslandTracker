import SwiftUI
import SwiftData
import CoreLocation

struct DashboardView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherService: WeatherService
    @Query(sort: \SurfaceReading.timestamp, order: .reverse) private var allReadings: [SurfaceReading]

    private var nearbyReadings: [SurfaceReading] {
        guard let userLocation = locationManager.currentLocation else { return [] }
        let userCL = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        return allReadings.filter { reading in
            let readingCL = CLLocation(latitude: reading.latitude, longitude: reading.longitude)
            return userCL.distance(from: readingCL) < 2000
        }
    }

    private var averageUHIDelta: Double? {
        let deltas = nearbyReadings.compactMap { $0.uhiDeltaC }
        guard !deltas.isEmpty else { return nil }
        return deltas.reduce(0, +) / Double(deltas.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                    uhiGaugeCard
                    recentReadingsSection
                }
                .padding()
            }
            .background(ThermalBackground(temperature: weatherService.current?.temperatureC))
            .navigationTitle("Urban Heat Island Tracker")
            .task { await refresh() }
            .refreshable { await refresh() }
            // GPS usually arrives after the first request, so fetch weather
            // the moment a fix lands instead of waiting for a manual refresh.
            .onChange(of: locationManager.currentLocation?.latitude) { _, _ in
                if weatherService.current == nil { Task { await loadWeather() } }
            }
        }
    }

    private func refresh() async {
        locationManager.requestPermission()
        locationManager.requestOneTimeLocation()
        await loadWeather()
    }

    private func loadWeather() async {
        if let coordinate = locationManager.currentLocation {
            await weatherService.fetchCurrentWeather(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    // MARK: - Hero: ambient weather, background gradient driven by live temp

    private var heroCard: some View {
        let temp = weatherService.current?.temperatureC
        return ZStack(alignment: .topLeading) {
            (temp.map { Theme.heroGradient(centeredOn: $0, min: 2, max: 34) }
                ?? Theme.heroGradient(centeredOn: 18, min: 2, max: 34))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 14) {
                Text("Ambient Air")
                    .font(Theme.labelFont(.footnote, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))

                if weatherService.isLoading {
                    ProgressView().tint(.white)
                        .padding(.vertical, 20)
                } else if let weather = weatherService.current {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.0f", weather.temperatureC))
                            .font(Theme.readoutFont(64, weight: .semibold))
                        Text("°C")
                            .font(Theme.readoutFont(28, weight: .medium))
                            .padding(.top, 8)
                    }
                    .foregroundStyle(.white)

                    HStack(spacing: 20) {
                        heroMetric(icon: "humidity.fill", value: String(format: "%.0f%%", weather.humidityPercent), label: "Humidity")
                        heroMetric(icon: "wind", value: String(format: "%.0f km/h", weather.windSpeedKph), label: "Wind")
                    }
                    Text("Updated \(weather.fetchedAt.formatted(date: .omitted, time: .shortened))")
                        .font(Theme.labelFont(.caption2))
                        .foregroundStyle(.white.opacity(0.8))
                } else if let error = weatherService.errorMessage {
                    Text(error).font(Theme.labelFont(.caption)).foregroundStyle(.white.opacity(0.85))
                } else {
                    HStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("Waiting for location…")
                            .font(Theme.labelFont(.subheadline))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
    }

    private func heroMetric(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.85))
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(Theme.readoutFont(15))
                    .foregroundStyle(.white)
                Text(label)
                    .font(Theme.labelFont(.caption2))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    // MARK: - UHI thermal gauge

    private var uhiGaugeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local Heat Island Index")
                .font(Theme.labelFont(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            if let delta = averageUHIDelta {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(delta >= 0 ? "+\(String(format: "%.1f", delta))°" : "\(String(format: "%.1f", delta))°")
                        .font(Theme.readoutFont(36))
                        .foregroundStyle(Theme.deltaColor(delta))
                    Text("vs. ambient air")
                        .font(Theme.labelFont(.subheadline))
                        .foregroundStyle(.secondary)
                }

                ThermalGauge(value: delta)
                    .frame(height: 14)

                Text("Based on \(nearbyReadings.count) reading\(nearbyReadings.count == 1 ? "" : "s") within ~2 km")
                    .font(Theme.labelFont(.caption))
                    .foregroundStyle(.secondary)
            } else {
                EmptyStateView(icon: "mappin.slash", title: "No nearby readings yet",
                               message: "Submit one from the Submit tab to see your local hotspot index.")
                ThermalGauge(value: nil)
                    .frame(height: 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var recentReadingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Submissions")
                .font(Theme.labelFont(.headline, weight: .semibold))

            if allReadings.isEmpty {
                EmptyStateView(icon: "tray", title: "No readings submitted yet",
                               message: "Readings you log will appear here.")
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(allReadings.prefix(5)) { reading in
                        ReadingRow(reading: reading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A horizontal bar spanning the full thermal scale with a marker
/// positioned at the current delta value — magnitude encoded as
/// position, not just color.
struct ThermalGauge: View {
    let value: Double?
    private let minValue = -2.0
    private let maxValue = 8.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                LinearGradient(
                    colors: [Theme.duskNavy, Theme.atmosphereTeal, Theme.heatAmber, Theme.blazeRed],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(Capsule())
                .opacity(value == nil ? 0.25 : 1.0)

                if let value {
                    let clamped = min(max(value, minValue), maxValue)
                    let fraction = (clamped - minValue) / (maxValue - minValue)
                    Circle()
                        .fill(.white)
                        .frame(width: 18, height: 18)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .offset(x: fraction * (geo.size.width - 18))
                }
            }
        }
    }
}

/// Muted icon + short message shown wherever there is no data yet.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(Theme.labelFont(.subheadline, weight: .semibold))
            Text(message)
                .font(Theme.labelFont(.caption))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct ReadingRow: View {
    let reading: SurfaceReading

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(reading.uhiDeltaC.map(Theme.deltaColor) ?? Theme.asphaltGray)
                .frame(width: 4)

            Image(systemName: Theme.surfaceIcon(for: reading.surfaceType))
                .foregroundStyle(Theme.surfaceTint(for: reading.surfaceType))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(reading.surfaceType.rawValue)
                    .font(Theme.labelFont(.subheadline, weight: .medium))
                Text(reading.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.labelFont(.caption2))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f°C", reading.surfaceTempC))
                    .font(Theme.readoutFont(15))
                if let delta = reading.uhiDeltaC {
                    Text(delta >= 0 ? "+\(String(format: "%.1f", delta))° Δ" : "\(String(format: "%.1f", delta))° Δ")
                        .font(Theme.readoutFont(11))
                        .foregroundStyle(Theme.deltaColor(delta))
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    DashboardView()
        .environmentObject(LocationManager())
        .environmentObject(BluetoothManager())
        .environmentObject(WeatherService())
        .modelContainer(for: SurfaceReading.self, inMemory: true)
}
