import SwiftUI
import MapKit

struct ComplaintMapView: View {
    @ObservedObject var store: ComplaintStore
    @EnvironmentObject private var auth: AuthStore
    @Binding var mapCenter: CLLocationCoordinate2D?
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedComplaint: Complaint.ID?
    @State private var deletingComplaint: Complaint?
    @State private var showingDeleteConfirmation = false
    @StateObject private var liveLocation = LocationService()
    let authRequiredAction: () -> Void
    let addAction: (CLLocationCoordinate2D?) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position, selection: $selectedComplaint) {
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
            .onMapCameraChange(frequency: .continuous) { context in
                guard CoordinateValidation.isValid(context.region.center) else { return }
                mapCenter = context.region.center
            }
            .onTapGesture { selectedComplaint = nil }
            .overlay { statusOverlay }
            HeaderView()
            .sheet(item: selectedComplaintBinding) { complaint in
                ComplaintDetailSheet(store: store, complaint: complaint, auth: auth, authRequiredAction: authRequiredAction, deleteAction: {
                    deletingComplaint = complaint
                    showingDeleteConfirmation = true
                }) {
                    if auth.isAuthenticated { store.toggleSupport(for: complaint.id) } else { authRequiredAction() }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(Color(.systemBackground))
            }
        }
        .onAppear {
            liveLocation.requestLocation()
            Task {
                try? await Task.sleep(for: .seconds(1))
                guard !liveLocation.hasResolvedLocation else { return }
                await centerOnProfile()
            }
        }
        .onChange(of: liveLocation.hasResolvedLocation) { _, isResolved in
            guard isResolved else { return }
            centerOnLiveLocation()
        }
        .confirmationDialog("Şikâyet silinsin mi?", isPresented: $showingDeleteConfirmation) {
            Button("Sil", role: .destructive) {
                if let complaint = deletingComplaint { Task { try? await store.delete(complaint); selectedComplaint = nil } }
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
        }
    }

    private func centerOnProfile() async {
        guard let query = auth.profile?.displayLocation, !query.isEmpty else { return }
        let request = MKLocalSearch.Request(); request.naturalLanguageQuery = query
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else { return }
        guard !liveLocation.hasResolvedLocation else { return }
        guard CoordinateValidation.isValid(item.placemark.coordinate) else { return }
        position = .region(.init(center: item.placemark.coordinate, span: .init(latitudeDelta: 0.18, longitudeDelta: 0.18)))
    }

    private func centerOnLiveLocation() {
        guard CoordinateValidation.isValid(liveLocation.coordinate) else { return }
        position = .region(.init(center: liveLocation.coordinate, span: .init(latitudeDelta: 0.18, longitudeDelta: 0.18)))
        mapCenter = liveLocation.coordinate
    }

    private var selectedComplaintBinding: Binding<Complaint?> {
        Binding(
            get: { store.complaints.first(where: { $0.id == selectedComplaint }) },
            set: { selectedComplaint = $0?.id }
        )
    }
}

private struct ComplaintDetailSheet: View {
    @ObservedObject var store: ComplaintStore
    let complaint: Complaint
    let auth: AuthStore
    let authRequiredAction: () -> Void
    let deleteAction: () -> Void
    let supportAction: () -> Void
    @State private var showingComments = false

    var body: some View {
        Group {
            if showingComments {
                ReportCommentsView(store: store, complaint: complaint, onBack: { showingComments = false })
                    .environmentObject(auth)
            } else {
                ScrollView {
                    ComplaintSheetContent(
                        complaint: complaint,
                        imageURLs: store.reportImageURLs(for: complaint),
                        avatarURL: store.avatarURL(for: complaint.authorProfile?.avatarPath),
                        canDelete: complaint.authorID == auth.profile?.id,
                        deleteAction: deleteAction,
                        isSupportPending: store.isSupportPending(for: complaint.id),
                        isCommentsPending: store.isCommentPending(for: complaint.id),
                        showCommentsAction: {
                            if auth.isAuthenticated { showingComments = true } else { authRequiredAction() }
                        },
                        supportAction: supportAction
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .animation(.snappy, value: showingComments)
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

private struct ComplaintSheetContent: View {
    let complaint: Complaint
    let imageURLs: [URL]
    let avatarURL: URL?
    let canDelete: Bool
    let deleteAction: () -> Void
    let isSupportPending: Bool
    let isCommentsPending: Bool
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
        VStack(alignment: .leading, spacing: 16) {
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
            .frame(height: 220)
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

            Button(action: showCommentsAction) {
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
        VStack(alignment: .leading, spacing: 8) {
            Text(complaint.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Label(complaint.locationName, systemImage: "mappin.and.ellipse")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(complaint.category.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.rezilRed)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.rezilRed.opacity(0.1), in: Capsule())
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
