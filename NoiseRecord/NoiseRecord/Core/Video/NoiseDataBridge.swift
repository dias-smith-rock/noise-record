import Foundation

/// Thread-safe bridge for injecting live noise / GPS strings into the video pipeline.
final class NoiseDataBridge: @unchecked Sendable {
    private let lock = NSLock()

    private var _decibelString = String(localized: "overlay.decibel.default")
    private var _gpsString = String(localized: "overlay.gps.unavailable")
    private var _weightingLabel = "dBA"

    var decibelString: String {
        lock.lock()
        defer { lock.unlock() }
        return _decibelString
    }

    var gpsString: String {
        lock.lock()
        defer { lock.unlock() }
        return _gpsString
    }

    func update(decibel: Float, weighting: String) {
        lock.lock()
        _decibelString = String(format: "%.1f %@", decibel, weighting)
        _weightingLabel = weighting
        lock.unlock()
    }

    func updateGPS(latitude: Double?, longitude: Double?) {
        lock.lock()
        if let latitude, let longitude {
            _gpsString = String(format: "Lat: %.4f, Lon: %.4f", latitude, longitude)
        } else {
            _gpsString = String(localized: "overlay.gps.unavailable")
        }
        lock.unlock()
    }

    var overlayDecibelText: String {
        String(format: String(localized: "overlay.decibel.prefix"), decibelString)
    }
}
