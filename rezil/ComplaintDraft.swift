import Foundation
import Combine
import SwiftUI
import PhotosUI
import MapKit
import CoreLocation

/// Add-complaint wizard steps: pick a location first, then fill details.
enum DraftStep {
    case location, details
}

@MainActor
final class ComplaintDraft: ObservableObject, Identifiable {
    let id = UUID()
    let location: LocationService
    @Published var text = ""
    @Published var category: ComplaintCategory = .other
    @Published var imageData: [Data] = []
    @Published var photoItems: [PhotosPickerItem] = []
    @Published var cameraImage: Data?
    @Published var showCamera = false
    @Published var step = DraftStep.location
    @Published var locationCamera: MapCameraPosition

    var canPublish: Bool {
        ReportDraftValidation.canPublish(text: text, hasPhoto: !imageData.isEmpty, hasLocation: location.hasResolvedLocation)
    }

    init(initialCoordinate: CLLocationCoordinate2D?) {
        location = LocationService(initialCoordinate: initialCoordinate)
        if let initialCoordinate, CoordinateValidation.isValid(initialCoordinate) {
            locationCamera = .region(.init(center: initialCoordinate, span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)))
        } else {
            locationCamera = .region(.init(center: CLLocationCoordinate2D(latitude: 39.0, longitude: 35.0), span: .init(latitudeDelta: 18, longitudeDelta: 18)))
        }
    }
}