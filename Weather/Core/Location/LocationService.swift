import CoreLocation

protocol LocationServicing: AnyObject {
    func requestLocation() async -> CLLocationCoordinate2D
}

final class LocationService222: NSObject, LocationServicing {
    static let fallbackMoscow = CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173)

    private let manager: CLLocationManager
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Never>?

    override init() {
        self.manager = CLLocationManager()
        super.init()
//        self.manager.delegate = self
        self.manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() async -> CLLocationCoordinate2D {
        let status = manager.authorizationStatus

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return await requestOneShotLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            return await withCheckedContinuation { cont in
                self.continuation = cont
            }
        case .restricted, .denied:
            return Self.fallbackMoscow
        @unknown default:
            return Self.fallbackMoscow
        }
    }

    private func requestOneShotLocation() async -> CLLocationCoordinate2D {
        let existing = manager.location?.coordinate
        if let existing { return existing }

        return await withCheckedContinuation { cont in
            self.continuation = cont
            self.manager.requestLocation()
        }
    }
}

extension LocationService222: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            self.continuation = nil
            Task { [weak self] in
                guard let self else { return }
                continuation.resume(returning: await self.requestOneShotLocation())
            }
        case .restricted, .denied:
            self.continuation = nil
            continuation.resume(returning: Self.fallbackMoscow)
        case .notDetermined:
            break
        @unknown default:
            self.continuation = nil
            continuation.resume(returning: Self.fallbackMoscow)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: locations.last?.coordinate ?? Self.fallbackMoscow)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: Self.fallbackMoscow)
    }
}

@MainActor
final class LocationService333: NSObject, LocationServicing {
    static let fallbackMoscow = CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173)

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Never>?

    override init() {
        super.init()
//        self.manager.delegate = self
        self.manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() async -> CLLocationCoordinate2D {
        // If a request is already in progress, you might want to return the same task
        // or cancel the old one. For now, we ensure we don't leak.
        continuation?.resume(returning: Self.fallbackMoscow)
        continuation = nil

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
}

extension LocationService333: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            // Don't create a new continuation!
            // Just tell the manager to get the location.
            // didUpdateLocations will resume the existing continuation.
            self.manager.requestLocation()
        case .restricted, .denied:
            self.continuation = nil
            continuation.resume(returning: Self.fallbackMoscow)
        case .notDetermined:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: locations.last?.coordinate ?? Self.fallbackMoscow)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: Self.fallbackMoscow)
    }
}


@MainActor
final class LocationService: NSObject, LocationServicing {
    static let fallbackMoscow = CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173)

    private let manager: CLLocationManager
    // Используем CheckedContinuation для связи делегата с async-методом
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Never>?

    override init() {
        self.manager = CLLocationManager()
        super.init()
        self.manager.delegate = self
        self.manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() async -> CLLocationCoordinate2D {
        // 1. Если уже есть активный запрос, завершаем его (защита от двойного вызова)
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
        // Если локация уже известна и свежая — возвращаем сразу
        if let location = manager.location?.coordinate {
            return location
        }

        return await withCheckedContinuation { cont in
            self.continuation = cont
            self.manager.requestLocation()
        }
    }

    // Вспомогательный метод для безопасного завершения континуации
    private func resumeAndClear(with coordinate: CLLocationCoordinate2D) {
        continuation?.resume(returning: coordinate)
        continuation = nil
    }
}

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard let continuation else { return }

            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                // Важно: просто просим локацию, resume случится в didUpdateLocations
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
