import SwiftUI

struct DiscoverView: View {
    @ObservedObject var store: ComplaintStore
    @EnvironmentObject private var auth: AuthStore
    let authRequiredAction: () -> Void
    let addAction: () -> Void
    @State private var showingCommentsFor: Complaint?
    @State private var sorting: DiscoverSorting = .popular

    private var sortedComplaints: [Complaint] {
        switch sorting {
        case .popular: store.complaints.sorted { $0.supportCount > $1.supportCount }
        case .newest: store.complaints.sorted { $0.createdAt > $1.createdAt }
        case .oldest: store.complaints.sorted { $0.createdAt < $1.createdAt }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.complaints.isEmpty {
                    ProgressView("Şikâyetler yükleniyor…")
                } else if let error = store.errorMessage, store.complaints.isEmpty {
                    ContentUnavailableView {
                        Label("Şikâyetler yüklenemedi", systemImage: "wifi.exclamationmark")
                    } description: { Text(error) } actions: {
                        Button("Tekrar dene") { Task { await store.load() } }.buttonStyle(.borderedProminent)
                    }
                } else if store.complaints.isEmpty {
                    ContentUnavailableView {
                        Label("Henüz şikâyet yok", systemImage: "text.page")
                    } description: { Text("İlk şikâyeti ekleyerek çevrendeki gündemi başlat.") } actions: {
                        Button("Şikâyet ekle", action: addAction).buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            sortingChips
                            ForEach(sortedComplaints) { complaint in
                                ComplaintCard(complaint: complaint, imageURLs: store.reportImageURLs(for: complaint), isSupportPending: store.isSupportPending(for: complaint.id), isCommentsPending: store.isCommentPending(for: complaint.id), showCommentsAction: { if auth.isAuthenticated { showingCommentsFor = complaint } else { authRequiredAction() } }) { if auth.isAuthenticated { store.toggleSupport(for: complaint.id) } else { authRequiredAction() } }
                            }
                        }.padding()
                    }
                    .refreshable { await store.load() }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Çevrende gündem")
            .sheet(item: $showingCommentsFor) { complaint in
                ReportCommentsView(store: store, complaint: complaint)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color(.systemBackground))
            }
        }
    }

    private var sortingChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sırala")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DiscoverSorting.allCases) { option in
                        Button {
                            withAnimation(.snappy) { sorting = option }
                        } label: {
                            Label(option.title, systemImage: option.icon)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(sorting == option ? .white : .primary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 9)
                                .background(sorting == option ? Color.rezilRed : Color(.secondarySystemBackground), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(sorting == option ? .isSelected : [])
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum DiscoverSorting: CaseIterable, Identifiable {
    case popular, newest, oldest

    var id: Self { self }
    var title: String {
        switch self {
        case .popular: "Öne çıkan"
        case .newest: "Yeni"
        case .oldest: "Eski"
        }
    }
    var icon: String {
        switch self {
        case .popular: "flame.fill"
        case .newest: "sparkles"
        case .oldest: "clock.arrow.circlepath"
        }
    }
}

struct ProfileView: View {
    @ObservedObject var store: ComplaintStore
    @EnvironmentObject private var auth: AuthStore
    @State private var showSignOutConfirmation = false
    @State private var showEditor = false
    let authRequiredAction: () -> Void
    var body: some View {
        if !auth.isAuthenticated {
            NavigationStack {
                ContentUnavailableView {
                    Label("Profil için giriş yap", systemImage: "person.crop.circle")
                } description: {
                    Text("Haritayı incelemeye devam edebilirsin. Katkılarını yönetmek için giriş yapman yeterli.")
                } actions: {
                    Button("Giriş yap") { authRequiredAction() }.buttonStyle(.borderedProminent)
                }
                .navigationTitle("Profil")
            }
        } else {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        if let avatarURL = store.avatarURL(for: auth.profile?.avatarPath) {
                            AsyncImage(url: avatarURL) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                }
                            }
                            .frame(width: 54, height: 54)
                            .clipShape(Circle())
                            .foregroundStyle(Color.rezilRed)
                        } else {
                            Image(systemName: "person.crop.circle.fill").font(.system(size: 54)).foregroundStyle(Color.rezilRed)
                        }
                        VStack(alignment: .leading) { Text(auth.profile?.displayName ?? "REZİL kullanıcısı").font(.headline); Text(auth.profile?.displayLocation ?? "Şehir veya ülke eklenmedi").foregroundStyle(.secondary) }
                        Spacer(); Button("Düzenle") { showEditor = true }
                    }.padding(.vertical, 8)
                }
                Section("Katkın") {
                    Label("\(store.myReports.count) şikâyet", systemImage: "exclamationmark.bubble")
                    Label("\(auth.profile?.reputationScore ?? 0) itibar puanı", systemImage: "star")
                }
                Section("Hesap") {
                    Button("Çıkış yap", role: .destructive) { showSignOutConfirmation = true }
                }
            }.navigationTitle("Profil").sheet(isPresented: $showEditor) { ProfileEditorView().environmentObject(auth) }.task { await store.loadOwnedContent() }
            .confirmationDialog("Hesabından çıkış yapılsın mı?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
                Button("Çıkış yap", role: .destructive) { auth.signOut() }
                Button("Vazgeç", role: .cancel) { }
            }
        }
        }
    }
}
