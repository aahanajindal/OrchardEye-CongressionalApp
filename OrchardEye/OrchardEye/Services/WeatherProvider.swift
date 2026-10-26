//
//  WeatherProvider.swift
//  OrchardEye
//
//  Pulls weather from the free, key-less Open-Meteo API and caches the last
//  value so voice guidance still works offline. Always falls back to a typical
//  central-WA snapshot — a scan must never depend on the network.
//

import Foundation

final class WeatherProvider {

    // Default to Wenatchee, WA (major apple-growing region) when no GPS is available.
    private let defaultLat = 47.42
    private let defaultLon = -120.31
    private let cacheKey = "cachedWeather"

    func current(lat: Double? = nil, lon: Double? = nil) async -> WeatherSnapshot {
        let latitude = lat ?? defaultLat
        let longitude = lon ?? defaultLon

        if let live = try? await fetch(lat: latitude, lon: longitude) {
            cache(live)
            return live
        }
        return cached() ?? Self.fallback()
    }

    // MARK: - Network

    private func fetch(lat: Double, lon: Double) async throws -> WeatherSnapshot {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(lat)),
            .init(name: "longitude", value: String(lon)),
            .init(name: "current", value: "temperature_2m,relative_humidity_2m,precipitation"),
            .init(name: "hourly", value: "precipitation"),
            // Next 12 hours from NOW (not 00:00 of the calendar day), so the
            // "rain expected" tip reflects the actual spray window.
            .init(name: "forecast_hours", value: "12")
        ]
        guard let url = comps.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(OMResponse.self, from: data)

        // `forecast_hours=12` already scopes the array to the next 12 h.
        let forecast = (decoded.hourly?.precipitation.reduce(0, +)) ?? 0
        let temp = decoded.current.temperature_2m
        let humidity = decoded.current.relative_humidity_2m

        // Reject NaN/inf or out-of-range sentinels (e.g. a provider -9999) so garbage
        // can't flow into diseasePressure math, the CSV, or "nan°" in the UI.
        guard temp.isFinite, humidity.isFinite,
              (-60...60).contains(temp), (0...100).contains(humidity), forecast.isFinite else {
            throw URLError(.cannotParseResponse)
        }

        return WeatherSnapshot(
            tempC: temp,
            humidityPct: humidity,
            precipRecentMM: decoded.current.precipitation,
            precipForecastMM: forecast,
            summary: Self.summarize(temp: temp, humidity: humidity, forecast: forecast),
            capturedAt: Date())
    }

    private struct OMResponse: Codable {
        struct Current: Codable {
            let temperature_2m: Double
            let relative_humidity_2m: Double
            let precipitation: Double
        }
        struct Hourly: Codable { let precipitation: [Double] }
        let current: Current
        let hourly: Hourly?
    }

    // MARK: - Cache & fallback

    private func cache(_ s: WeatherSnapshot) {
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func cached() -> WeatherSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let s = try? JSONDecoder().decode(WeatherSnapshot.self, from: data) else { return nil }
        return s
    }

    static func fallback() -> WeatherSnapshot {
        WeatherSnapshot(tempC: 24, humidityPct: 45, precipRecentMM: 0, precipForecastMM: 0,
                        summary: "Warm and dry (typical seasonal estimate — offline)", capturedAt: Date())
    }

    static func summarize(temp: Double, humidity: Double, forecast: Double) -> String {
        let t = String(format: "%.0f°C", temp)
        let h = String(format: "%.0f%% RH", humidity)
        if forecast > 1 { return "\(t), \(h), rain expected" }
        if humidity >= 70 { return "\(t), \(h), humid" }
        return "\(t), \(h), dry"
    }
}
