import SwiftUI
import MapKit

struct ComplaintMapView: View {
    @ObservedObject var store: ComplaintStore
    @EnvironmentObject private var auth: AuthStore
    @Binding var mapCenter: CLLocationCoordinate2D?
    @Binding var position: MapCameraPosition
    @Binding var didCenterOnLiveLocation: Bool
    @Binding var focusedComplaintID: Complaint.ID?
    @State private var selectedComplaint: Complaint.ID?
    @State private var deletingComplaint: Complaint?
    @State private var showingDeleteConfirmation = false
    @StateObject private var liveLocation = LocationService()
    private let defaultCenter = CLLocationCoordinate2D(latitude: 39.0, longitude: 35.0)
    let authRequiredAction: () -> Void
    let addAction: (CLLocationCoordinate2D?) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position, selection: $selectedComplaint) {
                UserAnnotation()
                ForEach(store.complaints.filter { CoordinateValidation.isValid($0.coordinate) }) { complaint in
                    Annotation("", coordinate: complaint.coordinate, anchor: .bottom) {
                        ComplaintPin(complaint: complaint, selected: selectedComplaint == complaint.id)
                            .tag(complaint.id)
                            .onTapGesture { withAnimation(.snappy) { selectedComplaint = complaint.id } }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
            .mapControls { MapCompass(); MapUserLocationButton() }
            .onMapCameraChange(frequency: .onEnd) { context in
                guard CoordinateValidation.isValid(context.region.center) else { return }
                mapCenter = context.region.center
            }
            .onTapGesture { selectedComplaint = nil }
            .overlay { statusOverlay }
            HeaderView()
            .sheet(item: selectedComplaintBinding) { complaint in
                ReportDetailSheet(store: store, complaint: complaint, canDelete: complaint.authorID == auth.profile?.id, deleteAction: {
                    deletingComplaint = complaint
                    showingDeleteConfirmation = true
                }, supportAction: {
                    if auth.isAuthenticated { store.toggleSupport(for: complaint.id) } else { authRequiredAction() }
                }, authRequiredAction: authRequiredAction)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(Color(.systemBackground))
            }
        }
        .onAppear {
            liveLocation.requestLocation()
            // Focus may have been set while another tab was visible
            // (onChange doesn't fire for a pre-existing value).
            if focusedComplaintID != nil {
                selectedComplaint = focusedComplaintID
                focusedComplaintID = nil
            }
        }
        .onChange(of: liveLocation.hasResolvedLocation) { _, isResolved in
            guard isResolved, !didCenterOnLiveLocation else { return }
            didCenterOnLiveLocation = true
            centerOnLiveLocation()
        }
        .onChange(of: focusedComplaintID) { _, focusedID in
            guard let focusedID else { return }
            selectedComplaint = focusedID
            focusedComplaintID = nil
        }
        .confirmationDialog("Şikâyet silinsin mi?", isPresented: $showingDeleteConfirmation) {
            Button("Sil", role: .destructive) {
                if let complaint = deletingComplaint {
                    Task {
                        do {
                            try await store.delete(complaint)
                            selectedComplaint = nil
                        } catch {
                            store.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            Button("Vazgeç", role: .cancel) { }
        }
    }

    @ViewBuilder private var statusOverlay: some View {
        if store.isLoading && store.complaints.isEmpty {
            ProgressView("Çevrendeki şikâyetler yükleniyor…")
                .padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        } else if let error = store.errorMessage, store.complaints.isEmpty {
            ContentUnavailableView {
                Label("Şikâyetler yüklenemedi", systemImage: "wifi.exclamationmark")
            } description: { Text(error) } actions: {
                Button("Tekrar dene") { Task { await store.load() } }.buttonStyle(.borderedProminent)
            }
            .padding().background(.regularMaterial)
        } else if !store.isLoading && store.errorMessage == nil && store.complaints.isEmpty {
            ContentUnavailableView {
                Label("Henüz şikâyet yok", systemImage: "map")
            } description: { Text("İlk şikâyeti ekleyerek haritayı doldur.") } actions: {
                Button("Şikâyet ekle") { addAction(mapCenter) }.buttonStyle(.borderedProminent)
            }
            .padding().background(.regularMaterial)
        }
    }

    private func centerOnLiveLocation() {
        let coordinate = liveLocation.hasResolvedLocation && CoordinateValidation.isValid(liveLocation.coordinate) ? liveLocation.coordinate : defaultCenter
        position = .region(.init(center: coordinate, span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)))
        mapCenter = coordinate
    }

    private var selectedComplaintBinding: Binding<Complaint?> {
        Binding(
            get: { store.complaints.first(where: { $0.id == selectedComplaint }) },
            set: { selectedComplaint = $0?.id }
        )
    }
}



struct HeaderView: View {
    var body: some View {
        HStack {
            HStack(spacing: 0) {
                Text("REZ").foregroundStyle(.primary)
                Text("!").foregroundStyle(Color.rezilRed)
                Text("L").foregroundStyle(.primary)
            }
            .font(.system(size: 27, weight: .black, design: .rounded))
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

private struct ComplaintPin: View {
    let complaint: Complaint
    let selected: Bool
    var body: some View {
        VStack(spacing: 0) {
            Text("\(complaint.supportCount)").font(.caption.bold()).foregroundStyle(.white).padding(.horizontal, 9).frame(height: 34).background(Color.rezilRed, in: Capsule())
            Image(systemName: "triangle.fill").font(.system(size: 9)).foregroundStyle(Color.rezilRed).rotationEffect(.degrees(180)).offset(y: -3)
        }
        .scaleEffect(selected ? 1.18 : 1).shadow(color: .black.opacity(0.18), radius: 5, y: 3).animation(.snappy, value: selected)
        .accessibilityLabel("\(complaint.category.rawValue), \(complaint.supportCount) doğrulama")
    }
}

struct ComplaintCard: View {
    let complaint: Complaint
    var imageURLs: [URL] = []
    var canDelete = false
    var deleteAction: (() -> Void)?
    var isSupportPending = false
    var isCommentsPending = false
    var showsContainer = true
    var imageCornerRadius: CGFloat = 16
    let showCommentsAction: () -> Void
    let supportAction: () -> Void
    @State private var selectedImageIndex: Int?

    private var galleryIsPresented: Binding<Bool> {
        Binding(
            get: { selectedImageIndex != nil },
            set: { if !$0 { selectedImageIndex = nil } }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !imageURLs.isEmpty {
                TabView {
                    ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else if phase.error != nil {
                                Image(systemName: "photo").font(.title).foregroundStyle(.secondary)
                            } else {
                                ProgressView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { selectedImageIndex = index }
                    }
                }
                .frame(height: 170)
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius, style: .continuous))
            }

            HStack(spacing: 18) {
                Button(action: supportAction) {
                    HStack(spacing: 6) {
                        Image(systemName: complaint.isSupported ? "hand.thumbsup.fill" : "hand.thumbsup")
                        Text("\(complaint.supportCount)").fontWeight(.semibold)
                    }
                }
                .foregroundStyle(complaint.isSupported ? Color.rezilRed : .primary)
                .disabled(isSupportPending)
                .accessibilityLabel(complaint.isSupported ? "Desteği geri al" : "Şikâyeti destekle")
                .accessibilityHint(isSupportPending ? "Destek kaydediliyor" : "Bu sorunu destekle")

                Button(action: showCommentsAction) {
                    HStack(spacing: 6) {
                        if isCommentsPending { ProgressView().controlSize(.small) }
                        Image(systemName: "bubble.left")
                        Text("\(complaint.commentCount)").fontWeight(.semibold)
                    }
                }
                .foregroundStyle(.primary)

                Spacer()
                if canDelete, let deleteAction {
                    Button(role: .destructive, action: deleteAction) { Image(systemName: "trash") }
                        .accessibilityLabel("Şikâyeti sil")
                }
            }

            HStack(spacing: 7) {
                Image(systemName: "person.crop.circle.fill").foregroundStyle(Color.rezilRed)
                Text(complaint.authorProfile?.displayName ?? "REZİL kullanıcısı").font(.subheadline.weight(.semibold))
                Text("•").foregroundStyle(.tertiary)
                Text(RelativeTimestamp.string(from: complaint.createdAt)).font(.caption).foregroundStyle(.secondary)
            }
            Text(complaint.title).font(.body).foregroundStyle(.secondary).lineLimit(4)
            Text("\(complaint.category.rawValue) • \(complaint.locationName)").font(.caption).foregroundStyle(.tertiary)
        }
        .modifier(ComplaintCardContainer(isEnabled: showsContainer))
        .fullScreenCover(isPresented: galleryIsPresented) {
            ImageGalleryView(imageURLs: imageURLs, initialIndex: selectedImageIndex ?? 0)
        }
    }
}

struct ComplaintSheetContent: View {
    let complaint: Complaint
    let imageURLs: [URL]
    let avatarURL: URL?
    let canDelete: Bool
    let deleteAction: () -> Void
    let isSupportPending: Bool
    let isCommentsPending: Bool
    let scrollToCommentsAction: () -> Void
    let supportAction: () -> Void
    @State private var selectedImageIndex: Int?

    private var galleryIsPresented: Binding<Bool> {
        Binding(
            get: { selectedImageIndex != nil },
            set: { if !$0 { selectedImageIndex = nil } }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            authorHeader
            imageGallery
            actionRow
            details
        }
        .fullScreenCover(isPresented: galleryIsPresented) {
            ImageGalleryView(imageURLs: imageURLs, initialIndex: selectedImageIndex ?? 0)
        }
    }

    private var authorHeader: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
                Text(complaint.authorProfile?.displayName ?? "REZİL kullanıcısı")
                    .font(.headline)
                Text(RelativeTimestamp.string(from: complaint.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var imageGallery: some View {
        if !imageURLs.isEmpty {
            TabView {
                ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else if phase.error != nil {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture { selectedImageIndex = index }
                }
            }
            .frame(height: 170)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var actionRow: some View {
        HStack(spacing: 22) {
            Button(action: supportAction) {
                Label("\(complaint.supportCount)", systemImage: complaint.isSupported ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(complaint.isSupported ? Color.rezilRed : .primary)
            .disabled(isSupportPending)
            .accessibilityLabel(complaint.isSupported ? "Desteği geri al" : "Şikâyeti destekle")

            Button(action: scrollToCommentsAction) {
                HStack(spacing: 6) {
                    if isCommentsPending { ProgressView().controlSize(.small) }
                    Label("\(complaint.commentCount)", systemImage: "bubble.left")
                }
                .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.primary)
            Spacer()
            if canDelete {
                Button(role: .destructive, action: deleteAction) {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Şikâyeti sil")
            }
        }
        .buttonStyle(.plain)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(complaint.title)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }

    private var avatar: some View {
        Group {
            if let avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { Image(systemName: "person.crop.circle.fill").resizable().scaledToFit() }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(Circle())
        .foregroundStyle(Color.rezilRed)
    }
}

private struct ComplaintCardContainer: ViewModifier {
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        } else {
            content
        }
    }
}

private struct ImageGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    let imageURLs: [URL]
    let initialIndex: Int
    @State private var selectedIndex: Int

    init(imageURLs: [URL], initialIndex: Int) {
        self.imageURLs = imageURLs
        self.initialIndex = initialIndex
        _selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $selectedIndex) {
                ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else if phase.error != nil {
                            Image(systemName: "photo").font(.largeTitle).foregroundStyle(.white.opacity(0.7))
                        } else {
                            ProgressView().tint(.white)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.headline.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(.black.opacity(0.55), in: Circle())
            }
            .padding(.top, 18)
            .padding(.trailing, 18)
            .accessibilityLabel("Galeriyi kapat")
        }
        .statusBarHidden()
    }
}
