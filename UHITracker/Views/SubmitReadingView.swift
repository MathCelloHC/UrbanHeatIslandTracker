import SwiftUI
import SwiftData

struct SubmitReadingView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var bluetoothManager: BluetoothManager
    @EnvironmentObject private var weatherService: WeatherService
    @Environment(\.modelContext) private var modelContext

    @State private var manualTempText: String = ""
    @State private var surfaceType: SurfaceType = .asphalt
    @State private var notes: String = ""
    @State private var useSensorValue = true
    @State private var didSave = false

    private var isSensorConnected: Bool {
        if case .connected = bluetoothManager.state { return true }
        return false
    }

    private var effectiveTemperature: Double? {
        if useSensorValue, isSensorConnected {
            return bluetoothManager.latestTemperatureC
        }
        return Double(manualTempText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Surface Temperature") {
                    if isSensorConnected {
                        Toggle("Use connected sensor reading", isOn: $useSensorValue)
                        if useSensorValue {
                            HStack {
                                Text("Live Sensor Value")
                                Spacer()
                                if let temp = bluetoothManager.latestTemperatureC {
                                    Text(String(format: "%.1f°C", temp))
                                        .font(Theme.readoutFont(17))
                                        .foregroundStyle(Theme.ambientColor(temp))
                                } else {
                                    Text("Waiting for data…").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if !useSensorValue || !isSensorConnected {
                        HStack {
                            TextField("Temperature (°C)", text: $manualTempText)
                                .keyboardType(.decimalPad)
                                .font(Theme.readoutFont(17))
                            Text("°C")
                        }
                    }
                }

                Section("Surface Type") {
                    surfaceTypeGrid
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                }

                Section("Location & Ambient Conditions") {
                    if let coordinate = locationManager.currentLocation {
                        Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                            .font(Theme.readoutFont(12))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Locating…").font(Theme.labelFont(.caption)).foregroundStyle(.secondary)
                    }
                    if let weather = weatherService.current {
                        Text("Ambient: \(String(format: "%.1f°C", weather.temperatureC)), \(String(format: "%.0f%%", weather.humidityPercent)) humidity, \(String(format: "%.0f km/h", weather.windSpeedKph)) wind")
                            .font(Theme.labelFont(.caption))
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        Label("Submit Reading", systemImage: "checkmark.circle.fill")
                            .font(Theme.labelFont(.body, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .tint(Theme.heatAmber)
                    .disabled(effectiveTemperature == nil || locationManager.currentLocation == nil)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ThermalBackground(temperature: weatherService.current?.temperatureC))
            .navigationTitle("Submit Reading")
            .task {
                locationManager.requestPermission()
                locationManager.requestOneTimeLocation()
            }
            .alert("Reading Saved", isPresented: $didSave) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your surface temperature reading has been saved to your local log.")
            }
        }
    }

    private var surfaceTypeGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], spacing: 10) {
            ForEach(SurfaceType.allCases) { type in
                let selected = type == surfaceType
                Button {
                    surfaceType = type
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: Theme.surfaceIcon(for: type))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(selected ? .white : Theme.surfaceTint(for: type))
                        Text(type.rawValue)
                            .font(Theme.labelFont(.caption2, weight: .medium))
                            .foregroundStyle(selected ? .white : .primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selected ? Theme.surfaceTint(for: type) : Theme.surfaceTint(for: type).opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func submit() {
        guard let temp = effectiveTemperature, let coordinate = locationManager.currentLocation else { return }

        let reading = SurfaceReading(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            surfaceTempC: temp,
            source: (useSensorValue && isSensorConnected) ? .arduinoSensor : .manualEntry,
            surfaceType: surfaceType,
            notes: notes,
            ambientAirTempC: weatherService.current?.temperatureC,
            ambientHumidityPercent: weatherService.current?.humidityPercent,
            ambientWindSpeedKph: weatherService.current?.windSpeedKph
        )
        modelContext.insert(reading)

        manualTempText = ""
        notes = ""
        didSave = true
    }
}

#Preview {
    SubmitReadingView()
        .environmentObject(LocationManager())
        .environmentObject(BluetoothManager())
        .environmentObject(WeatherService())
        .modelContainer(for: SurfaceReading.self, inMemory: true)
}
