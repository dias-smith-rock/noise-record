import CoreLocation
import MapKit
import XCTest
@testable import NoiseRecord

final class EvidenceGeocoderTests: XCTestCase {
    func testAbbreviatedPlaceNamePrefersDistrictAndCity() {
        let placemark = MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
            addressDictionary: [
                "SubLocality": "Chaoyang District",
                "City": "Beijing",
                "State": "Beijing",
            ]
        )

        XCTAssertEqual(
            EvidenceGeocoder.abbreviatedPlaceName(from: placemark),
            "Chaoyang District, Beijing"
        )
    }

    func testAbbreviatedPlaceNameUsesSingleLocalityWhenNeeded() {
        let placemark = MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198),
            addressDictionary: [
                "City": "Singapore",
            ]
        )

        XCTAssertEqual(
            EvidenceGeocoder.abbreviatedPlaceName(from: placemark),
            "Singapore"
        )
    }
}
