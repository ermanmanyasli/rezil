import SwiftUI
import PhotosUI
import MapKit

enum ReportDraftValidation {
    static func canPublish(text: String, hasPhoto: Bool, hasLocation: Bool = true) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 240 && hasPhoto && hasLocation
    }

    static func canUploadImageCount(_ count: Int) -> Bool { (1...3).contains(count) }
}

struct NewComplaintView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ComplaintStore
    @StateObject private var location = LocationService()
    @State private var text = ""
    @State private var category: ComplaintCategory = .other
    @State private var imageData: [Data] = []
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var cameraImage: Data?
    @State private var showCamera = false
    @State private var isLocationStep = true
    @State private var isLoadingPhoto = false
    @State private var isSubmitting = false
    @State private var submissionError: String?
    @FocusState private var isDescriptionFocused: Bool
    let onPublished: (Complaint) -> Void

    private var canPublish: Bool { ReportDraftValidation.canPublish(text: text, hasPhoto: !imageData.isEmpty, hasLocation: location.hasResolvedLocation) }

    init(store: ComplaintStore, initialCoordinate: CLLocationCoordinate2D? = nil, onPublished: @escaping (Complaint) -> Void = { _ in }) {
        self.store = store
        self.onPublished = onPublished
        _location = StateObject(wrappedValue: LocationService(initialCoordinate: initialCoordinate))
    }

    var body: some View {
        NavigationStack {
            if isLocationStep {
                LocationPickerView(coordinate: $location.coordinate, initialCoordinate: location.coordinate) { coordinate in
                    location.useManualLocation(coordinate)
                    withAnimation(.easeInOut) { isLocationStep = false }
                }
            } else {
                ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    photoSection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ne gördün?").font(.headline)
                        TextField("1–2 cümle yeterli", text: $text, axis: .vertical)
                            .lineLimit(2...4).padding(14).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                            .focused($isDescriptionFocused)
                            .accessibilityIdentifier("report-description")
                        Text("\(text.count)/240").font(.caption).foregroundStyle(text.count > 240 ? Color.rezilRed : .secondary).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kategori").font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(ComplaintCategory.allCases) { item in
                                    Button { category = item } label: {
                                        Label(item.rawValue, systemImage: item.icon).font(.subheadline.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 9)
                                            .foregroundStyle(category == item ? .white : .primary)
                                            .background(category == item ? Color.rezilRed : Color(.secondarySystemBackground), in: Capsule())
                                    }
                                }
                            }
                        }
                    }
                    Button { isLocationStep = true } label: {
                        HStack {
                            Image(systemName: "location.fill").foregroundStyle(Color.rezilRed)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Konum").font(.headline)
                                Text(location.locationText).font(.caption).foregroundStyle(location.hasError ? Color.rezilRed : .secondary)
                            }
                            Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }.padding(14).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    }.foregroundStyle(.primary)

                    if let submissionError {
                        Label(submissionError, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color.rezilRed)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("report-error")
                    }
                    Button(action: publish) {
                        HStack(spacing: 10) {
                            if isSubmitting { ProgressView().tint(.white) }
                            Text(isSubmitting ? "Yayınlanıyor…" : "Gönder")
                        }
                        .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(canPublish ? Color.rezilRed : Color.secondary, in: RoundedRectangle(cornerRadius: 17))
                    }
                    .disabled(!canPublish || isSubmitting)
                    .accessibilityIdentifier("publish-report")
                }.padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Şikâyet ekle").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() }.disabled(isSubmitting) }
            }
            .onAppear {
                if !location.hasResolvedLocation { location.requestLocation() }
            }
            .onChange(of: photoItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                isLoadingPhoto = true
                submissionError = nil
                Task {
                    defer { isLoadingPhoto = false }
                    do {
                        var loaded: [Data] = []
                        for item in newItems.prefix(3) {
                            guard let data = try await item.loadTransferable(type: Data.self), UIImage(data: data) != nil else { continue }
                            loaded.append(data)
                        }
                        guard !loaded.isEmpty else { throw SupabaseError.invalidResponse }
                        imageData = Array(loaded.prefix(3))
                    } catch {
                        submissionError = "Fotoğraf yüklenemedi. Lütfen başka bir fotoğraf seç."
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) { CameraPicker(imageData: $cameraImage) }
            .onChange(of: cameraImage) { _, newImage in if let newImage, imageData.count < 3 { imageData.append(newImage); cameraImage = nil } }
            .interactiveDismissDisabled(isSubmitting)
            }
        }
        .onAppear {
            if !location.hasResolvedLocation { location.requestLocation() }
        }
    }

    private var photoSection: some View {
        Group {
            if !imageData.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 10) {
                    ForEach(Array(imageData.enumerated()), id: \.offset) { index, data in
                        if let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill().frame(width: 150, height: 150).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(alignment: .topTrailing) { Button { imageData.remove(at: index) } label: { Image(systemName: "xmark").padding(7).background(.ultraThinMaterial, in: Circle()) }.padding(6) } }
                    }
                } }
            } else {
                ZStack {
                    HStack(spacing: 12) {
                        Button { showCamera = true } label: { photoButton(icon: "camera.fill", title: "Fotoğraf çek") }
                        PhotosPicker(selection: $photoItems, maxSelectionCount: 3, matching: .images) { photoButton(icon: "photo.on.rectangle", title: "Galeriden seç") }
                    }
                    if isLoadingPhoto {
                        RoundedRectangle(cornerRadius: 20).fill(.regularMaterial)
                        ProgressView("Fotoğraf hazırlanıyor…")
                    }
                }
            }
        }
    }

    private func photoButton(icon: String, title: String) -> some View {
        VStack(spacing: 10) { Image(systemName: icon).font(.title); Text(title).font(.subheadline.bold()) }
            .foregroundStyle(Color.rezilRed).frame(maxWidth: .infinity).frame(height: 150)
            .background(Color.rezilRed.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
    }

    private func publish() {
        guard canPublish, !isSubmitting else { return }
        isDescriptionFocused = false
        isSubmitting = true
        submissionError = nil
        Task {
            do {
                let complaint = try await store.add(description: text.trimmingCharacters(in: .whitespacesAndNewlines), category: category, coordinate: location.coordinate, locationName: location.locationText, images: imageData)
                onPublished(complaint)
                dismiss()
            } catch {
                submissionError = "Şikâyet yayınlanamadı: \(error.localizedDescription)"
                isSubmitting = false
            }
        }
    }
}

private struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var coordinate: CLLocationCoordinate2D
    @State private var position: MapCameraPosition
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    let onConfirm: (CLLocationCoordinate2D) -> Void
    init(coordinate: Binding<CLLocationCoordinate2D>, initialCoordinate: CLLocationCoordinate2D? = nil, onConfirm: @escaping (CLLocationCoordinate2D) -> Void) {
        _coordinate = coordinate
        let candidate = initialCoordinate ?? coordinate.wrappedValue
        let initial = CoordinateValidation.isValid(candidate) ? candidate : .init(latitude: 41.01, longitude: 28.97)
        _position = State(initialValue: .region(.init(center: initial, span: .init(latitudeDelta: 0.008, longitudeDelta: 0.008))))
        if !CoordinateValidation.isValid(coordinate.wrappedValue) { _coordinate.wrappedValue = initial }
        self.onConfirm = onConfirm
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Map(position: $position, interactionModes: .all) {
                    UserAnnotation()
                }
                .mapStyle(.standard(elevation: .realistic))
                .onMapCameraChange(frequency: .continuous) { context in
                    if CoordinateValidation.isValid(context.region.center) { coordinate = context.region.center }
                }
                .mapControls {
                    MapCompass()
                    MapUserLocationButton()
                }
                .overlay(alignment: .center) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.rezilRed)
                        .offset(y: -22)
                        .allowsHitTesting(false)
                }

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Bir yer ara", text: $searchText)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.search)
                        if isSearching {
                            ProgressView().controlSize(.small)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                    if !searchResults.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(Array(searchResults.enumerated()), id: \.offset) { _, item in
                                    Button {
                                        let coordinate = item.placemark.coordinate
                                        guard CoordinateValidation.isValid(coordinate) else { return }
                                        self.coordinate = coordinate
                                        position = .region(.init(center: coordinate, span: .init(latitudeDelta: 0.008, longitudeDelta: 0.008)))
                                        searchText = item.name ?? item.placemark.title ?? "Seçilen konum"
                                        searchResults = []
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name ?? "Bilinmeyen yer").font(.subheadline.weight(.semibold))
                                            Text([item.placemark.title, item.placemark.subtitle].compactMap { $0 }.joined(separator: ", "))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                    }

                }
                .padding()
            }
            .navigationTitle("Konumu seç").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Devam") { onConfirm(coordinate) }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.rezilRed, in: RoundedRectangle(cornerRadius: 17))
                    .padding(.horizontal)
                    .background(.bar)
            }
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                let query = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else {
                    searchResults = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    await searchPlaces(query: query)
                }
            }
        }
    }

    @MainActor
    private func searchPlaces(query: String) async {
        isSearching = true
        defer { isSearching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        guard CoordinateValidation.isValid(coordinate) else { return }
        request.region = MKCoordinateRegion(center: coordinate, span: .init(latitudeDelta: 0.5, longitudeDelta: 0.5))
        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = response.mapItems
        } catch {
            searchResults = []
        }
    }
}
