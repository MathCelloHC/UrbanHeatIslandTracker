import Foundation
import SwiftData
import CoreLocation

enum ReadingSource: String, Codable, CaseIterable, Identifiable {
    case arduinoSensor = "Arduino Sensor (BLE)"
    case autoLogged = "Auto-recorded (BLE)"
    case manualEntry = "Manual Entry"

    var id: String { rawValue }
}

enum SurfaceType: String, Codable, CaseIterable, Identifiable {
    case asphalt = "Asphalt / Road"
    case concrete = "Concrete / Sidewalk"
    case grass = "Grass / Park"
    case rooftop = "Rooftop"
    case treeShade = "Tree Shade"
    case water = "Water"
    case other = "Other"

    var id: String { rawValue }
}

@Model
final class SurfaceReading {
    var id: UUID
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var surfaceTempC: Double
    var sourceRaw: String
    var surfaceTypeRaw: String
    var notes: String

    
    
    
    var ambientAirTempC: Double?
    var ambientHumidityPercent: Double?
    var ambientWindSpeedKph: Double?

    init(
        timestamp: Date = .now,
        latitude: Double,
        longitude: Double,
        surfaceTempC: Double,
        source: ReadingSource,
        surfaceType: SurfaceType,
        notes: String = "",
        ambientAirTempC: Double? = nil,
        ambientHumidityPercent: Double? = nil,
        ambientWindSpeedKph: Double? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.surfaceTempC = surfaceTempC
        self.sourceRaw = source.rawValue
        self.surfaceTypeRaw = surfaceType.rawValue
        self.notes = notes
        self.ambientAirTempC = ambientAirTempC
        self.ambientHumidityPercent = ambientHumidityPercent
        self.ambientWindSpeedKph = ambientWindSpeedKph
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var source: ReadingSource {
        ReadingSource(rawValue: sourceRaw) ?? .manualEntry
    }

    var surfaceType: SurfaceType {
        SurfaceType(rawValue: surfaceTypeRaw) ?? .other
    }

    var uhiDeltaC: Double? {
        guard let ambientAirTempC else { return nil }
        return surfaceTempC - ambientAirTempC
    }
}
