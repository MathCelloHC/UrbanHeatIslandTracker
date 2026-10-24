import SwiftUI
import SwiftData
import CoreLocation

struct RecordView: View {
    @EnvironmentObject private var bluetoothManager: BluetoothManager
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherService: WeatherService
    @EnvironmentObject private var session: RecordingSession
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    liveReadout
                        .listRowBackground(Color.clear)
                }

                if !session.isRecording {
                    Section("Survey Settings") {
                        Picker("Surface", selection: $session.surfaceType) {
                            ForEach(SurfaceType.allCases) { type in
                                Label(type.rawValue, systemImage: Theme.surfaceIcon(for: type))
                                    .tag(type)
                            }
                        }

                        Picker("Log every", selection: $session.interval) {
                            Text("5 seconds").tag(TimeInterval(5))
                            Text("10 seconds").tag(TimeInterval(10))
                            Text("30 seconds").tag(TimeInterval(30))
                            Text("1 minute").tag(TimeInterval(60))
                        }

                        Picker("Only after moving", selection: $session.minimumDistance) {
                            Text("Any distance").tag(CLLocationDistance(0))
                            Text("10 m").tag(CLLocationDistance(10))
                            Text("25 m").tag(CLLocationDistance(25))
                            Text("50 m").tag(CLLocationDistance(50))
                        }
                    }

                    Section {
                        Button {
                            session.start(modelContext: modelContext)
                        } label: {
                            Label("Start Recording", systemImage: "record.circle")
                                .font(Theme.labelFont(.body, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .tint(Theme.blazeRed)
                        .disabled(!session.canStart)
                    } footer: {
                        if !session.canStart {
                            Text("Connect the sensor on the Sensor tab to start recording.")
                        } else {
                            Text("Readings are logged automatically and mirrored on the board's LCD. Keep the app open while surveying.")
                        }
                    }
                } else {
                    Section("Session") {
                        LabeledContent("Points logged") {
                            Text("\(session.pointsLogged)")
                                .font(Theme.readoutFont(17))
                        }
                        LabeledContent("Surface") {
                            Text(session.surfaceType.rawValue)
                        }
                        if let last = session.lastLoggedAt {
                            LabeledContent("Last point") {
                                Text(last.formatted(date: .omitted, time: .standard))
                                    .font(Theme.readoutFont(13))
                            }
                        }
                        if let reason = session.skipReason {
                            Label(reason, systemImage: "pause.circle")
                                .font(Theme.labelFont(.caption))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            session.stop()
                        } label: {
                            Label("Stop Recording", systemImage: "stop.circle")
                                .font(Theme.labelFont(.body, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ThermalBackground(temperature: weatherService.current?.temperatureC))
            .navigationTitle("Record")
            .task {
                session.configure(
                    bluetoothManager: bluetoothManager,
                    locationManager: locationManager,
                    weatherService: weatherService
                )
                locationManager.requestPermission()
                if let coordinate = locationManager.currentLocation, weatherService.current == nil {
                    await weatherService.fetchCurrentWeather(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                }
            }
        }
    }

    private var liveReadout: some View {
        VStack(spacing: 6) {
            if let temp = bluetoothManager.latestTemperatureC {
                Text(String(format: "%.1f°C", temp))
                    .font(Theme.readoutFont(44))
                    .foregroundStyle(Theme.ambientColor(temp))
            } else {
                Text("--.-°C")
                    .font(Theme.readoutFont(44))
                    .foregroundStyle(.secondary)
            }

            if session.isRecording {
                Label("Recording", systemImage: "record.circle.fill")
                    .font(Theme.labelFont(.caption, weight: .semibold))
                    .foregroundStyle(Theme.blazeRed)
            } else {
                Text(session.canStart ? "Sensor connected" : "Sensor not connected")
                    .font(Theme.labelFont(.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

#Preview {
    RecordView()
        .environmentObject(BluetoothManager())
        .environmentObject(LocationManager())
        .environmentObject(WeatherService())
        .environmentObject(RecordingSession())
        .modelContainer(for: SurfaceReading.self, inMemory: true)
}
