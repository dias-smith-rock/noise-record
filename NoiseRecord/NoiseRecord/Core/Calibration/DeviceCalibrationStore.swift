import Foundation
import UIKit

enum WeightingType: String, CaseIterable, Codable, Sendable {
    case a = "A"
    case c = "C"
    case z = "Z"

    var displayName: String {
        switch self {
        case .a: "dBA (A计权)"
        case .c: "dBC (C计权)"
        case .z: "dBZ (Z计权)"
        }
    }
}

struct DeviceCalibrationStore: Sendable {
    private static let userOffsetKey = "calibration.userOffset"
    private static let weightingKey = "settings.weighting"

    static let defaultOffset: Float = 100.0

    private static let deviceLookup: [String: Float] = [
        "iPhone16,1": 102.0,
        "iPhone16,2": 102.0,
        "iPhone15,4": 101.5,
        "iPhone15,5": 101.5,
        "iPhone15,2": 101.0,
        "iPhone15,3": 101.0,
        "iPhone14,7": 100.5,
        "iPhone14,8": 100.5,
        "iPhone14,2": 100.0,
        "iPhone14,3": 100.0,
        "iPhone13,2": 99.5,
        "iPhone13,3": 99.5,
        "iPad13,18": 98.0,
        "iPad13,19": 98.0,
    ]

    static var deviceModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "unknown"
            }
        }
    }

    static var lookupOffset: Float {
        deviceLookup[deviceModelIdentifier] ?? defaultOffset
    }

    static var userOffset: Float? {
        get {
            let value = UserDefaults.standard.object(forKey: userOffsetKey) as? Float
            return value
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: userOffsetKey)
            } else {
                UserDefaults.standard.removeObject(forKey: userOffsetKey)
            }
        }
    }

    static var totalOffset: Float {
        (userOffset ?? lookupOffset)
    }

    static var weightingType: WeightingType {
        get {
            guard let raw = UserDefaults.standard.string(forKey: weightingKey),
                  let type = WeightingType(rawValue: raw) else { return .a }
            return type
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: weightingKey)
        }
    }

    /// Calibrate against a reference SPL meter reading (e.g. 94 dB @ 1 kHz).
    static func calibrate(referenceSPL: Float, measuredDBFS: Float) {
        userOffset = referenceSPL - measuredDBFS
    }

    static func resetCalibration() {
        userOffset = nil
    }
}
