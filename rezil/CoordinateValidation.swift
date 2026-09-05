import CoreLocation

enum CoordinateValidation {
    static func isValid(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude.isFinite && coordinate.longitude.isFinite &&
        (-90...90).contains(coordinate.latitude) && (-180...180).contains(coordinate.longitude) &&
        !(coordinate.latitude == 0 && coordinate.longitude == 0)
    }
}
