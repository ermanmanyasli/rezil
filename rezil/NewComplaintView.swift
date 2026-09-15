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
    @ObservedObject var store: ComplaintStore
    @ObservedObject var draft: ComplaintDraft
    @State private var isLoadingPhoto = false
    @State private var isSubmitting = false
    @State private var submissionError: String?
    @FocusState private var isDescriptionFocused: Bool
    let onPublished: (Complaint) -> Void

    /// Pushed details step. A binding (not the enum directly) so the
    /// system swipe-back gesture syncs `draft.step` on pop.
    private var showDetails: Binding<Bool> {
        Binding(
            get: { draft.step == .details },
            set: { if !$0 { draft.step = .location } }
        )
    }

    var body: some View {
        NavigationStack {
            // Location step is the stack root and is never destroyed, so its
            // map (camera, gestures, search) is preserved pixel-identical
            // when navigating back from the details step.
            LocationPickerView(location: draft.location, camera: $draft.locationCamera) { coordinate in
                draft.location.useManualLocation(coordinate)
                withAnimation(.easeInOut) { draft.step = .details }
            }
            .navigationDestination(isPresented: showDetails) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        photoSection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ne gördün?").font(.headline)
                            TextField("1–2 cümle yeterli", text: $draft.text, axis: .vertical)
                                .lineLimit(2...4).padding(14).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                                .focused($isDescriptionFocused)
                                .accessibilityIdentifier("report-description")
                            Text("\(draft.text.count)/240").font(.caption).foregroundStyle(draft.text.count > 240 ? Color.rezilRed : .secondary).frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Kategori").font(.headline)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(ComplaintCategory.allCases) { item in
                                        Button { draft.category = item } label: {
                                            Label(item.rawValue, systemImage: item.icon).font(.subheadline.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 9)
                                                .foregroundStyle(draft.category == item ? .white : .primary)
                                                .background(draft.category == item ? Color.rezilRed : Color(.secondarySystemBackground), in: Capsule())
                                        }
                                    }
                                }
                            }
                        }
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
                                Text(submitLabel)
                            }
                            .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(canPublish ? Color.rezilRed : Color.secondary, in: RoundedRectangle(cornerRadius: 17))
                        }
                        .disabled(!canPublish || isSubmitting)
                        .accessibilityIdentifier("publish-report")
                    }.padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .overlay(alignment: .top) {
                    DraftStepIndicator(step: .details)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
                .navigationTitle("Şikâyet ekle").navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    if !draft.location.hasResolvedLocation { draft.location.requestLocation() }
                }
                .onChange(of: draft.photoItems) { _, newItems in
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
                            draft.imageData = Array(loaded.prefix(3))
                        } catch {
                            submissionError = "Fotoğraf yüklenemedi. Lütfen başka bir fotoğraf seç."
                        }
                    }
                }
                .fullScreenCover(isPresented: $draft.showCamera) { CameraPicker(imageData: $draft.cameraImage) }
                .onChange(of: draft.cameraImage) { _, newImage in if let newImage, draft.imageData.count < 3 { draft.imageData.append(newImage); draft.cameraImage = nil } }
                .interactiveDismissDisabled(isSubmitting)
            }
        }
        .onAppear {
            if !draft.location.hasResolvedLocation { draft.location.requestLocation() }
        }
    }

    private var canPublish: Bool {
        ReportDraftValidation.canPublish(text: draft.text, hasPhoto: !draft.imageData.isEmpty, hasLocation: draft.location.hasResolvedLocation)
            && draft.location.hasResolvedName
    }

    private var submitLabel: String {
        guard isSubmitting else { return "Gönder" }
        switch store.photoPhase {
        case .preparing: return "Fotoğraf hazırlanıyor…"
        case .uploading, .idle: return "Yayınlanıyor…"
        }
    }

    private var photoSection: some View {
        Group {
            if !draft.imageData.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 10) {
                    ForEach(Array(draft.imageData.enumerated()), id: \.offset) { index, data in
                        if let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill().frame(width: 150, height: 150).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(alignment: .topTrailing) { Button { draft.imageData.remove(at: index) } label: { Image(systemName: "xmark").padding(7).background(.ultraThinMaterial, in: Circle()) }.padding(6) } }
                    }
                } }
            } else {
                ZStack {
                    HStack(spacing: 12) {
                        Button { draft.showCamera = true } label: { photoButton(icon: "camera.fill", title: "Fotoğraf çek") }
                        PhotosPicker(selection: $draft.photoItems, maxSelectionCount: 3, matching: .images) { photoButton(icon: "photo.on.rectangle", title: "Galeriden seç") }
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
                let complaint = try await store.add(description: draft.text.trimmingCharacters(in: .whitespacesAndNewlines), category: draft.category, coordinate: draft.location.coordinate, locationName: draft.location.locationText, images: draft.imageData)
                // NOTE: no dismiss() here — inside a pushed destination it
                // would only pop. ContentView closes the sheet (draft = nil).
                onPublished(complaint)
            } catch {
                submissionError = "Şikâyet yayınlanamadı: \(error.localizedDescription)"
                isSubmitting = false
            }
        }
    }
}

/// Slim wizard progress pill: "1 Konum → 2 Detay", current step highlighted.
private struct DraftStepIndicator: View {
    let step: DraftStep

    var body: some View {
        HStack(spacing: 6) {
            stepItem(number: "1", title: "Konum", active: step == .location)
            Capsule()
                .frame(width: 14, height: 2)
                .foregroundStyle(.secondary.opacity(0.4))
            stepItem(number: "2", title: "Detay", active: step == .details)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }

    private func stepItem(number: String, title: String, active: Bool) -> some View {
        HStack(spacing: 4) {
            Text(number)
                .frame(width: 16, height: 16)
                .background(active ? Color.rezilRed : Color.secondary.opacity(0.35), in: Circle())
                .foregroundStyle(.white)
            Text(title)
                .foregroundStyle(active ? .primary : .secondary)
        }
    }
}

private struct LocationPickerView: View {
    @ObservedObject var location: LocationService
    @Binding var camera: MapCameraPosition
    @State private var hasAutoCenteredOnLive = false
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var isProgrammaticCameraChange = false
    let onConfirm: (CLLocationCoordinate2D) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Map(position: $camera, interactionModes: .all) {
                    UserAnnotation()
                }
                .mapStyle(.standard(elevation: .realistic))
                .onMapCameraChange(frequency: .onEnd) { context in
                    if isProgrammaticCameraChange {
                        isProgrammaticCameraChange = false
                        return
                    }
                    // User-driven move: lock the pin to the map center so later
                    // GPS updates can never overwrite it, and re-resolve the name.
                    if CoordinateValidation.isValid(context.region.center) {
                        location.useManualLocation(context.region.center)
                    }
                }
                .onChange(of: location.hasResolvedLocation) { _, isResolved in
                    guard isResolved, !hasAutoCenteredOnLive else { return }
                    guard CoordinateValidation.isValid(location.coordinate) else { return }
                    hasAutoCenteredOnLive = true
                    isProgrammaticCameraChange = true
                    withAnimation(.snappy) { camera = .region(.init(center: location.coordinate, span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01))) }
                }
                .mapControls {
                    MapCompass()
                    MapUserLocationButton()
                }
                .overlay(alignment: .top) {
                    DraftStepIndicator(step: .location)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
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
                                        // Lock to the searched pin (ignores later GPS updates)
                                        // and resolve its display name.
                                        location.useManualLocation(coordinate)
                                        isProgrammaticCameraChange = true
                                        camera = .region(.init(center: coordinate, span: .init(latitudeDelta: 0.008, longitudeDelta: 0.008)))
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
            .safeAreaInset(edge: .bottom) {
                Button("Devam") { onConfirm(location.coordinate) }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(location.hasResolvedLocation ? Color.rezilRed : Color.secondary, in: RoundedRectangle(cornerRadius: 17))
                    .padding(.horizontal)
                    .background(.bar)
                    .disabled(!location.hasResolvedLocation)
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
        guard CoordinateValidation.isValid(location.coordinate) else { return }
        request.region = MKCoordinateRegion(center: location.coordinate, span: .init(latitudeDelta: 0.5, longitudeDelta: 0.5))
        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = response.mapItems
        } catch {
            searchResults = []
        }
    }
}