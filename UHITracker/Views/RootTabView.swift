import SwiftUI
import SwiftData

struct RootTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "thermometer.sun") }

            HeatMapView()
                .tabItem { Label("Map", systemImage: "map") }

            SubmitReadingView()
                .tabItem { Label("Submit", systemImage: "plus.circle") }

            RecordView()
                .tabItem { Label("Record", systemImage: "record.circle") }

            SensorView()
                .tabItem { Label("Sensor", systemImage: "dot.radiowaves.left.and.right") }
        }
        .tint(Theme.heatAmber)
    }
}

#Preview {
    RootTabView()
        .environmentObject(LocationManager())
        .environmentObject(BluetoothManager())
        .environmentObject(WeatherService())
        .environmentObject(RecordingSession())
        .modelContainer(for: SurfaceReading.self, inMemory: true)
}
