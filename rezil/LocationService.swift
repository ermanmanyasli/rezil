import Foundation
import CoreLocation
import Combine
import MapKit

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @Published var locationText = "Konum belirleniyor"
    @Published private(set) var hasResolvedLocation = false
    @Published private(set) var hasError = false
    private let manager = CLLocationManager()

    init(initialCoordinate: CLLocationCoordinate2D? = nil) {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        if let initialCoordinate, CoordinateValidation.isValid(initialCoordinate) {
            coordinate = initialCoordinate
            hasResolvedLocation = true
            locationText = "Seçilen konum"
        }
    }
    func requestLocation() {
        hasError = false
        locationText = "Konum belirleniyor…"
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            hasError = true
            locationText = "Konum izni kapalı — Ayarlar'dan aç"
        @unknown default:
            hasError = true
            locationText = "Konum alınamadı — haritadan seç"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways else { return }
        manager.requestLocation()
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        guard CoordinateValidation.isValid(latest.coordinate) else { return }
        coordinate = latest.coordinate
        hasResolvedLocation = true
        hasError = false
        locationText = "Adres belirleniyor…"
        resolveName(for: latest)
    }

    func useManualLocation(_ coordinate: CLLocationCoordinate2D) {
        guard CoordinateValidation.isValid(coordinate) else { return }
        self.coordinate = coordinate
        hasResolvedLocation = true
        hasError = false
        locationText = "Adres belirleniyor…"
        resolveName(for: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    private func resolveName(for location: CLLocation) {
        Task { @MainActor [weak self] in
            guard let request = MKReverseGeocodingRequest(location: location) else {
                self?.locationText = "Seçilen konum"
                return
            }
            let items = try? await request.mapItems
            self?.locationText = items?.first?.name ?? "Seçilen konum"
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        hasError = true
        hasResolvedLocation = false
        locationText = "Konum alınamadı — haritadan seç"
    }
}
