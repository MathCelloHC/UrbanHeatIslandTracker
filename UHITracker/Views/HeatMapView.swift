//
//  HeatMapView.swift
//  Shows all crowd-sourced surface readings on a map. Pins are colored
//  along the same continuous thermal scale used everywhere else in the
//  app, rather than a few discrete buckets, so the map reads like an
//  actual thermal map.
//

import SwiftUI
import SwiftData
import MapKit

struct HeatMapView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @Query(sort: \SurfaceReading.timestamp, order: .reverse) private var readings: [SurfaceReading]

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedReading: SurfaceReading?

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition, selection: $selectedReading) {
                ForEach(readings) { reading in
                    Annotation(reading.surfaceType.rawValue, coordinate: reading.coordinate) {
                        ThermalPin(reading: reading)
                            .onTapGesture { selectedReading = reading }
                    }
                    .tag(reading)
                }

                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .overlay {
                if readings.isEmpty {
                    EmptyStateView(icon: "map", title: "No readings on the map yet",
                                   message: "Submit or record a reading and it will appear here.")
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(40)
                }
            }
            .navigationTitle("Heat Map")
            .sheet(item: $selectedReading) { reading in
                ReadingDetailSheet(reading: reading)
                    .presentationDetents([.medium])
            }
            .onAppear {
                if let coordinate = locationManager.currentLocation {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    )
                }
            }
        }
    }
}

/// A small thermometer-shaped marker filled with the continuous thermal
/// color for this reading's delta, rather than a stock map pin.
struct ThermalPin: View {
    let reading: SurfaceReading

    private var color: Color {
        reading.uhiDeltaC.map(Theme.deltaColor) ?? Theme.asphaltGray
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            Image(systemName: Theme.surfaceIcon(for: reading.surfaceType))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

struct ReadingDetailSheet: View {
    let reading: SurfaceReading

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: Theme.surfaceIcon(for: reading.surfaceType))
                    .foregroundStyle(Theme.surfaceTint(for: reading.surfaceType))
                Text(reading.surfaceType.rawValue)
                    .font(Theme.labelFont(.title2, weight: .semibold))
            }

            HStack(alignment: .firstTextBaseline, spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.1f°C", reading.surfaceTempC))
                        .font(Theme.readoutFont(28))
                    Text("Surface")
                        .font(Theme.labelFont(.caption))
                        .foregroundStyle(.secondary)
                }
                if let ambient = reading.ambientAirTempC {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.1f°C", ambient))
                            .font(Theme.readoutFont(28))
                            .foregroundStyle(.secondary)
                        Text("Air")
                            .font(Theme.labelFont(.caption))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let delta = reading.uhiDeltaC {
                ThermalGauge(value: delta)
                    .frame(height: 10)
                Text(delta >= 0
                     ? "\(String(format: "%.1f", delta))°C hotter than ambient air — a local hotspot."
                     : "\(String(format: "%.1f", abs(delta)))°C cooler than ambient air.")
                    .font(Theme.labelFont(.subheadline))
                    .foregroundStyle(.secondary)
            }

            if !reading.notes.isEmpty {
                Text(reading.notes).font(Theme.labelFont(.body))
            }

            Spacer()

            HStack {
                Label(reading.source.rawValue, systemImage: "checkmark.seal")
                Spacer()
                Text(reading.timestamp.formatted(date: .abbreviated, time: .shortened))
            }
            .font(Theme.labelFont(.caption))
            .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    HeatMapView()
        .environmentObject(LocationManager())
        .modelContainer(for: SurfaceReading.self, inMemory: true)
}
