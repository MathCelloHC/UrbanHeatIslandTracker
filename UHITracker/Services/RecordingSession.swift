import Foundation
import SwiftData
import CoreLocation
import SwiftUI

@MainActor
final class RecordingSession: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var pointsLogged = 0
    @Published private(set) var lastLoggedAt: Date?
    @Published private(set) var skipReason: String?

    @Published var interval: TimeInterval = 10
    @Published var minimumDistance: CLLocationDistance = 10
    @Published var surfaceType: SurfaceType = .asphalt

    private var timer: Timer?
    private var lastLoggedLocation: CLLocation?
    private var bluetoothManager: BluetoothManager?
    private var locationManager: LocationManager?
    private var weatherService: WeatherService?

    func configure(
        bluetoothManager: BluetoothManager,
        locationManager: LocationManager,
        weatherService: WeatherService
    ) {
        self.bluetoothManager = bluetoothManager
        self.locationManager = locationManager
        self.weatherService = weatherService
    }

    var canStart: Bool {
        guard let bluetoothManager else { return false }
        if case .connected = bluetoothManager.state { return true }
        return false
    }

    func start(modelContext: ModelContext) {
        guard !isRecording, canStart,
              let bluetoothManager, let locationManager else { return }

        isRecording = true
        pointsLogged = 0
        lastLoggedLocation = nil
        skipReason = nil

        locationManager.startContinuousUpdates()
        bluetoothManager.sendStatusToDisplay("REC 0 pts")

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick(modelContext: modelContext)
            }
        }
    }

    func stop() {
        isRecording = false
        timer?.invalidate()
        timer = nil
        locationManager?.stopContinuousUpdates()
        bluetoothManager?.sendStatusToDisplay("Done: \(pointsLogged) pts")
    }

    private func tick(modelContext: ModelContext) {
        guard let bluetoothManager, let locationManager else {
            stop()
            return
        }

        guard case .connected = bluetoothManager.state else {
            skipReason = "Sensor disconnected"
            stop()
            return
        }

        guard let temperature = bluetoothManager.latestTemperatureC else {
            skipReason = "Waiting for sensor data"
            return
        }

        guard let coordinate = locationManager.currentLocation else {
            skipReason = "Waiting for GPS fix"
            return
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        if minimumDistance > 0, let previous = lastLoggedLocation {
            let moved = location.distance(from: previous)
            if moved < minimumDistance {
                skipReason = String(format: "Moved %.0f m of %.0f m", moved, minimumDistance)
                return
            }
        }

        let reading = SurfaceReading(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            surfaceTempC: temperature,
            source: .autoLogged,
            surfaceType: surfaceType,
            notes: "",
            ambientAirTempC: weatherService?.current?.temperatureC,
            ambientHumidityPercent: weatherService?.current?.humidityPercent,
            ambientWindSpeedKph: weatherService?.current?.windSpeedKph
        )
        modelContext.insert(reading)

        pointsLogged += 1
        lastLoggedAt = .now
        lastLoggedLocation = location
        skipReason = nil

        bluetoothManager.sendStatusToDisplay("REC \(pointsLogged) pts")
    }
}
