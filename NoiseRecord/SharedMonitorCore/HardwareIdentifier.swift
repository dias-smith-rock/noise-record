import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum HardwareIdentifier {
    private static let marketingNames: [String: String] = [
        // iPhone 12
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        // iPhone 13
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd generation)",
        // iPhone 14
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        // iPhone 15
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        // iPhone 16
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e",
        // iPad (common)
        "iPad13,18": "iPad (10th generation)",
        "iPad13,19": "iPad (10th generation)",
        "iPad14,3": "iPad Pro 11-inch (4th generation)",
        "iPad14,4": "iPad Pro 11-inch (4th generation)",
        "iPad14,5": "iPad Pro 12.9-inch (6th generation)",
        "iPad14,6": "iPad Pro 12.9-inch (6th generation)",
        "iPad14,8": "iPad Air (5th generation)",
        "iPad14,9": "iPad Air (5th generation)",
        "iPad14,10": "iPad Air (5th generation)",
        "iPad14,11": "iPad Air (5th generation)",
    ]

    static var machineIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "unknown"
            }
        }
    }

    static var marketingName: String {
        marketingName(for: machineIdentifier)
    }

    static func marketingName(for machineIdentifier: String) -> String {
        marketingNames[machineIdentifier] ?? machineIdentifier
    }

    static var pdfHardwareDescription: String {
        let name = marketingName
        if marketingNames[machineIdentifier] != nil {
            return name
        }
        return "Consumer iOS device (\(machineIdentifier))"
    }

    static var pdfDeviceMetadataLine: String {
        var parts = [pdfHardwareDescription, "iOS \(systemVersion)", "built-in microphone"]
        if let appVersion = appVersionString {
            parts.append("Decibel Meter Pro \(appVersion)")
        }
        return parts.joined(separator: " · ")
    }

    static var pdfCollectionPersonnelLine: String {
        "Automated collection via Decibel Meter Pro on \(pdfHardwareDescription) (iOS \(systemVersion))"
    }

    private static var systemVersion: String {
        #if canImport(UIKit)
        UIDevice.current.systemVersion
        #else
        ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    private static var appVersionString: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
