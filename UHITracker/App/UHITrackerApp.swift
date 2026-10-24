import SwiftUI
import SwiftData

@main
struct UHITrackerApp: App {
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SurfaceReading.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @StateObject private var locationManager = LocationManager()
    @StateObject private var bluetoothManager = BluetoothManager()
    @StateObject private var weatherService = WeatherService()
    @StateObject private var recordingSession = RecordingSession()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(locationManager)
                .environmentObject(bluetoothManager)
                .environmentObject(weatherService)
                .environmentObject(recordingSession)
        }
        .modelContainer(sharedModelContainer)
    }
}
