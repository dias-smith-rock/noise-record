import CoreLocation
import Foundation

enum LocationAccessPromptAction: Sendable {
    case none
    case requestSystemAuthorization
    case showSettingsPrompt
}

/// 基于定位与 Open-Meteo 的温湿度快照，供监测页与全屏 LED 看板共享。
@MainActor
@Observable
final class AmbientEnvironmentProvider: NSObject, CLLocationManagerDelegate {
    private(set) var humidityPercent: Int?
    private(set) var temperatureCelsius: Double?
    private(set) var isUpdating = false
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()
    private var refreshTask: Task<Void, Never>?
    private var lastCoordinate: CLLocationCoordinate2D?

    private var usesFahrenheit: Bool {
        AppAppearanceSettings.shared.temperatureUnitPreference.usesFahrenheit
    }

    var humidityDisplay: String {
        guard let humidityPercent else { return "--" }
        return "\(humidityPercent)%"
    }

    var temperatureDisplay: String {
        guard let temperatureCelsius else { return "--" }
        if usesFahrenheit {
            let fahrenheit = temperatureCelsius * 9 / 5 + 32
            return String(format: "%.0f°F", fahrenheit)
        }
        return String(format: "%.0f°C", temperatureCelsius)
    }

    var fullscreenTemperatureDisplay: String {
        guard let temperatureCelsius else { return "--" }
        if usesFahrenheit {
            let fahrenheit = temperatureCelsius * 9 / 5 + 32
            return String(format: "%.0f °F", fahrenheit)
        }
        return String(format: "%.0f °C", temperatureCelsius)
    }

    var fullscreenHumidityDisplay: String {
        guard let humidityPercent else { return "--" }
        return "\(humidityPercent) %"
    }

    var ledTemperatureValue: String {
        guard let temperatureCelsius else { return "--" }
        if usesFahrenheit {
            let fahrenheit = temperatureCelsius * 9 / 5 + 32
            return String(format: "%.0f", fahrenheit)
        }
        return String(format: "%.0f", temperatureCelsius)
    }

    var ledTemperatureUnit: String {
        guard temperatureCelsius != nil else { return "" }
        return usesFahrenheit ? "°F" : "°C"
    }

    var ledHumidityValue: String {
        guard let humidityPercent else { return "--" }
        return "\(humidityPercent)"
    }

    var ledHumidityUnit: String {
        humidityPercent == nil ? "" : "%"
    }

    var latitude: Double? { lastCoordinate?.latitude }
    var longitude: Double? { lastCoordinate?.longitude }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = locationManager.authorizationStatus
    }

    func permissionPromptAction() -> LocationAccessPromptAction {
        switch authorizationStatus {
        case .notDetermined:
            return .requestSystemAuthorization
        case .denied, .restricted:
            return .showSettingsPrompt
        case .authorizedWhenInUse, .authorizedAlways:
            return .none
        @unknown default:
            return .none
        }
    }

    func requestSystemLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    private var isLocationAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    func startUpdating() {
        guard refreshTask == nil else { return }
        if isLocationAuthorized {
            locationManager.startUpdatingLocation()
        }

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refreshWeatherIfPossible()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    func stopUpdating() {
        refreshTask?.cancel()
        refreshTask = nil
        locationManager.stopUpdatingLocation()
    }

    private func refreshWeatherIfPossible() async {
        guard let lastCoordinate else { return }
        guard !isUpdating else { return }

        isUpdating = true
        defer { isUpdating = false }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(lastCoordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(lastCoordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]

        guard let url = components.url else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return
            }
            let decoded = try JSONDecoder().decode(OpenMeteoCurrentWeather.self, from: data)
            humidityPercent = decoded.current.relativeHumidity2m
            temperatureCelsius = decoded.current.temperature2m
        } catch {
            return
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse
                || manager.authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            } else {
                manager.stopUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            lastCoordinate = location.coordinate
            await refreshWeatherIfPossible()
        }
    }
}

private struct OpenMeteoCurrentWeather: Decodable {
    struct Current: Decodable {
        let temperature2m: Double
        let relativeHumidity2m: Int

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case relativeHumidity2m = "relative_humidity_2m"
        }
    }

    let current: Current
}
