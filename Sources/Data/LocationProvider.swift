import Foundation
import CoreLocation

/// Wraps CLLocationManager. Asks for authorization once at init, then keeps an
/// up-to-date snapshot of the Mac's location + a reverse-geocoded place name.
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared = LocationProvider()

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private(set) var currentLocation: CLLocation?
    private(set) var placeName: String = "—"
    private var lastGeocodeAt: Date = .distantPast

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100  // only update on ≥100m moves
    }

    func start() {
        let status = CLLocationManager.authorizationStatus()
        switch status {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        case .authorized, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            // Denied / restricted — we just leave placeName as "—"
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorized || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        currentLocation = loc

        // Reverse-geocode at most every 60 seconds to avoid rate-limit
        let now = Date()
        if now.timeIntervalSince(lastGeocodeAt) >= 60 {
            lastGeocodeAt = now
            geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
                guard let p = placemarks?.first else { return }
                let city = p.locality ?? p.subAdministrativeArea ?? "—"
                let region = p.administrativeArea ?? ""
                self?.placeName = region.isEmpty ? city : "\(city), \(region)"
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // No-op; widget will just show "—"
    }
}
