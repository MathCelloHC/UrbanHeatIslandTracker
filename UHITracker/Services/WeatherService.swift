import Foundation

struct WeatherSnapshot: Equatable {
    let temperatureC: Double
    let humidityPercent: Double
    let windSpeedKph: Double
    let fetchedAt: Date
}

@MainActor
final class WeatherService: ObservableObject {
    @Published var current: WeatherSnapshot?
    @Published var isLoading = false
    @Published var errorMessage: String?

    
    func fetchCurrentWeather(latitude: Double, longitude: Double) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,wind_speed_10m"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components.url else {
            errorMessage = "Invalid weather request URL."
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                errorMessage = "Weather API returned an unexpected response."
                return
            }
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            current = WeatherSnapshot(
                temperatureC: decoded.current.temperature_2m,
                humidityPercent: decoded.current.relative_humidity_2m,
                windSpeedKph: decoded.current.wind_speed_10m,
                fetchedAt: .now
            )
        } catch {
            errorMessage = "Couldn't fetch weather: \(error.localizedDescription)"
        }
    }
}



private struct OpenMeteoResponse: Decodable {
    let current: CurrentBlock

    struct CurrentBlock: Decodable {
        let temperature_2m: Double
        let relative_humidity_2m: Double
        let wind_speed_10m: Double
    }
}
