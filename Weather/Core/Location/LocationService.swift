import CoreLocation

protocol LocationServicing: AnyObject {
    func requestLocation() async -> CLLocationCoordinate2D
}

@MainActor
final class LocationService: NSObject, LocationServicing {
    static let fallbackMoscow = CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173)

    private let manager: CLLocationManager
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Never>?

    override init() {
        self.manager = CLLocationManager()
        super.init()
        self.manager.delegate = self
        self.manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() async -> CLLocationCoordinate2D {
        resumeAndClear(with: Self.fallbackMoscow)

        let status = manager.authorizationStatus

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return await requestOneShotLocation()

        case .notDetermined:
            return await withCheckedContinuation { cont in
                self.continuation = cont
                manager.requestWhenInUseAuthorization()
            }

        case .restricted, .denied:
            return Self.fallbackMoscow
        @unknown default:
            return Self.fallbackMoscow
        }
    }

    private func requestOneShotLocation() async -> CLLocationCoordinate2D {
        if let location = manager.location?.coordinate {
            return location
        }

        return await withCheckedContinuation { cont in
            self.continuation = cont
            self.manager.requestLocation()
        }
    }

    private func resumeAndClear(with coordinate: CLLocationCoordinate2D) {
        continuation?.resume(returning: coordinate)
        continuation = nil
    }
}

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard continuation != nil else { return }

            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                self.manager.requestLocation()
            case .restricted, .denied:
                resumeAndClear(with: Self.fallbackMoscow)
            case .notDetermined:
                resumeAndClear(with: Self.fallbackMoscow)
            @unknown default:
                resumeAndClear(with: Self.fallbackMoscow)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            let result = locations.last?.coordinate ?? Self.fallbackMoscow
            resumeAndClear(with: result)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            resumeAndClear(with: Self.fallbackMoscow)
        }
    }
}
