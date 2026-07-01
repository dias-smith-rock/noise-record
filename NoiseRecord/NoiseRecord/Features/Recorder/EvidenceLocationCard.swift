import CoreLocation
import MapKit
import SwiftUI

struct EvidenceLocationCard: View {
    let latitude: Double
    let longitude: Double
    var addressLine: String?
    var secondaryLine: String?
    var theme: ModeVisualTheme

    @State private var cameraPosition: MapCameraPosition

    init(
        latitude: Double,
        longitude: Double,
        addressLine: String?,
        secondaryLine: String?,
        theme: ModeVisualTheme
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.addressLine = addressLine
        self.secondaryLine = secondaryLine
        self.theme = theme
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var body: some View {
        ProCard(theme: theme) {
            VStack(spacing: 0) {
                Map(position: $cameraPosition, interactionModes: []) {
                    Marker("", coordinate: coordinate)
                        .tint(theme.accent)
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button(action: openInMaps) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(addressLine ?? L10n.mediaDetailLocationUnknown)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            if let secondaryLine, !secondaryLine.isEmpty {
                                Text(secondaryLine)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func openInMaps() {
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = addressLine
        item.openInMaps()
    }
}

enum EvidenceGeocoder {
    static func resolveAddress(
        latitude: Double,
        longitude: Double
    ) async -> (title: String, subtitle: String?) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else {
                return (formatCoordinate(latitude: latitude, longitude: longitude), nil)
            }

            let title = [
                placemark.subThoroughfare,
                placemark.thoroughfare
            ]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

            let subtitleParts = [
                placemark.locality,
                placemark.administrativeArea,
                placemark.country
            ]
            .compactMap { $0 }

            let resolvedTitle = title.isEmpty
                ? (placemark.name ?? formatCoordinate(latitude: latitude, longitude: longitude))
                : title
            let subtitle = subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: ", ")
            return (resolvedTitle, subtitle)
        } catch {
            return (formatCoordinate(latitude: latitude, longitude: longitude), nil)
        }
    }

    private static func formatCoordinate(latitude: Double, longitude: Double) -> String {
        String(format: "%.4f, %.4f", latitude, longitude)
    }
}
