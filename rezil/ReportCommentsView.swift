import SwiftUI

/// Unified complaint detail sheet in three fixed regions: the complaint
/// stays pinned on top (unchanged content), comments scroll independently
/// in the middle, composer stays pinned at the bottom. The comment icon
/// scrolls the comments region instead of swapping views.
struct ReportDetailSheet: View {
    @ObservedObject var store: ComplaintStore
    @EnvironmentObject private var auth: AuthStore
    let complaint: Complaint
    let canDelete: Bool
    let deleteAction: () -> Void
    let supportAction: () -> Void
    let authRequiredAction: () -> Void
    /// Open already scrolled to the comments (feed card comment taps).
    var startAtComments = false
    @State private var didInitialScroll = false
    @State private var detent: PresentationDetent
    @State private var commentsOpacity: Double

    init(store: ComplaintStore, complaint: Complaint, canDelete: Bool, deleteAction: @escaping () -> Void, supportAction: @escaping () -> Void, authRequiredAction: @escaping () -> Void, startAtComments: Bool = false) {
        self.store = store
        self.complaint = complaint
        self.canDelete = canDelete
        self.deleteAction = deleteAction
        self.supportAction = supportAction
        self.authRequiredAction = authRequiredAction
        self.startAtComments = startAtComments
        _detent = State(initialValue: startAtComments ? .large : .medium)
        _commentsOpacity = State(initialValue: startAtComments ? 1 : 0)
    }

    /// Store-owned copy refreshes live (support/comment counts change).
    private var liveComplaint: Complaint {
        store.complaints.first(where: { $0.id == complaint.id }) ?? complaint
    }

    /// Complaint region cap: a 420pt floor holds steady while the sheet
    /// animates open and favors the complaint on phones; taller screens
    /// grow proportionally; compact heights (landscape) split 60/40 so
    /// the comments region never collapses to zero.
    private func complaintCap(for sheetHeight: CGFloat) -> CGFloat {
        guard sheetHeight > 550 else { return sheetHeight * 0.6 }
        return max(420, sheetHeight * 0.65)
    }

    var body: some View {
        ScrollViewReader { proxy in
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // Region 1 — complaint, pinned. At medium detent it owns
                    // the whole sheet; at large it's capped adaptively: a fixed
                    // floor holds steady while the sheet animates open, growing
                    // proportionally on taller screens. The rest goes to
                    // the comments region below.
                    ScrollView {
                    ComplaintSheetContent(
                        complaint: liveComplaint,
                        imageURLs: store.reportImageURLs(for: liveComplaint),
                        avatarURL: store.avatarURL(for: liveComplaint.authorProfile?.avatarPath),
                        canDelete: canDelete,
                        deleteAction: deleteAction,
                        isSupportPending: store.isSupportPending(for: liveComplaint.id),
                        isCommentsPending: store.isCommentPending(for: liveComplaint.id),
                        scrollToCommentsAction: {
                            if auth.isAuthenticated {
                                if detent == .large {
                                    withAnimation(.snappy) { proxy.scrollTo("comments", anchor: .top) }
                                } else {
                                    withAnimation(.snappy) { detent = .large }
                                    // Scroll once the sheet has resized.
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        guard detent == .large else { return }
                                        withAnimation(.snappy) { proxy.scrollTo("comments", anchor: .top) }
                                    }
                                }
                            } else {
                                authRequiredAction()
                            }
                        },
                        supportAction: supportAction
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                }
                .frame(maxHeight: detent == .large ? complaintCap(for: geo.size.height) : .infinity)

                // Region 2 — comments, own independent scroll. Always mounted:
                // mounting mid-animation is what made the region travel in
                // from the layout origin. Visibility is pure height + opacity
                // interpolation instead, which reverses identically whether
                // the detent changes via icon tap, manual drag, or feed entry.
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 20)

                    ScrollView {
                        ReportCommentListView(store: store, complaint: liveComplaint, authRequiredAction: authRequiredAction)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .id("comments")
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(maxHeight: detent == .large ? .infinity : 0)
                .opacity(commentsOpacity)
                .clipped()
                .animation(.snappy, value: detent)
                .onChange(of: detent) { _, newDetent in
                    if newDetent == .large {
                        // Let the space open first, then fade the rows in.
                        withAnimation(.snappy.delay(0.2)) { commentsOpacity = 1 }
                    } else {
                        withAnimation(.snappy) { commentsOpacity = 0 }
                    }
                }
                }
            }
                .safeAreaInset(edge: .bottom) {
                    if auth.isAuthenticated {
                        ReportComposerView(store: store, reportID: liveComplaint.id)
                    } else {
                        Button("Yorum yazmak için giriş yap", action: authRequiredAction)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.rezilRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .overlay(alignment: .top) { Divider() }
                    }
                }
                .task { await store.loadComments(for: complaint.id) }
                .onAppear {
                    guard startAtComments, !didInitialScroll else { return }
                    didInitialScroll = true
                    // Wait for the open animation to settle so the scroll
                    // can't land while regions are still resizing.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        guard detent == .large else { return }
                        withAnimation(.snappy) { proxy.scrollTo("comments", anchor: .top) }
                    }
                }
            .presentationDetents([.medium, .large], selection: $detent)
        }
    }
}

struct ReportCommentListView: View {
    @ObservedObject var store: ComplaintStore
    @EnvironmentObject private var auth: AuthStore
    let complaint: Complaint
    let authRequiredAction: () -> Void
    @State private var commentToDelete: ReportComment?
    @State private var showingDeleteConfirmation = false
    @State private var deleteError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Yorumlar").font(.headline)
                Text("\(complaint.commentCount)").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
            if store.isCommentsLoading(for: complaint.id) && store.comments(for: complaint.id).isEmpty {
                ProgressView("Yorumlar yükleniyor…").frame(maxWidth: .infinity).padding(.vertical, 12)
            } else if store.comments(for: complaint.id).isEmpty {
                Text("Henüz yorum yok. İlk yorumu sen yaz.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
            } else {
                ForEach(store.comments(for: complaint.id)) { comment in commentRow(comment) }
            }
            if let deleteError {
                Text(deleteError).font(.caption).foregroundStyle(.red)
            }
        }
        .confirmationDialog("Yorum silinsin mi?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Sil", role: .destructive) {
                guard let comment = commentToDelete else { return }
                Task {
                    do { try await store.delete(comment) }
                    catch { deleteError = error.localizedDescription }
                }
            }
            Button("Vazgeç", role: .cancel) { }
        } message: { Text("Bu yorum kalıcı olarak kaldırılacak.") }
    }

    private func commentRow(_ comment: ReportComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            CommentAvatarView(store: store, path: comment.authorProfile?.avatarPath, size: 28)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(comment.authorProfile?.displayName ?? "REZİL kullanıcısı").font(.footnote.weight(.semibold))
                    Text(RelativeTimestamp.string(from: comment.createdAt)).font(.caption).foregroundStyle(.secondary)
                }
                Text(comment.body).font(.footnote).fixedSize(horizontal: false, vertical: true)
                Button("Yanıtla") {
                    NotificationCenter.default.post(name: .reportCommentReply,
                                                    object: "@\(comment.authorProfile?.displayName ?? "kullanıcı") ")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
            Button {
                if auth.isAuthenticated { store.toggleCommentLike(for: comment.id) }
                else { authRequiredAction() }
            } label: {
                Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                    .font(.footnote)
                    .foregroundStyle(comment.isLiked ? Color.rezilRed : .secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(store.isCommentLikePending(for: comment.id))
            .accessibilityLabel(comment.isLiked ? "Yorumu beğenmekten vazgeç" : "Yorumu beğen")
        }
        .contextMenu {
            if comment.authorID == auth.profile?.id {
                Button("Sil", role: .destructive) {
                    commentToDelete = comment
                    showingDeleteConfirmation = true
                }
                .disabled(store.isCommentDeletePending(for: comment.id))
            }
        }
    }
}

struct ReportComposerView: View {
    @ObservedObject var store: ComplaintStore
    @EnvironmentObject private var auth: AuthStore
    let reportID: UUID
    @State private var bodyText = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                CommentAvatarView(store: store, path: auth.profile?.avatarPath, size: 44)
                TextField("Yorumunu yaz…", text: $bodyText, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($composerFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Button(action: submit) {
                    Group {
                        if isSubmitting { ProgressView().controlSize(.small).tint(.white) }
                        else { Image(systemName: "arrow.up").font(.body.weight(.bold)) }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .foregroundStyle(Color.rezilRed)
                            .opacity(isSubmitting || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Yorumu gönder")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18).padding(.bottom, 6)
            }
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .top) { Divider() }
        .onReceive(NotificationCenter.default.publisher(for: .reportCommentReply)) { notification in
            if let prefix = notification.object as? String {
                bodyText = prefix
                composerFocused = true
            }
        }
    }

    private func submit() {
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                _ = try await store.addComment(reportID: reportID, body: trimmed)
                bodyText = ""
            } catch { errorMessage = error.localizedDescription }
            isSubmitting = false
        }
    }
}

struct CommentAvatarView: View {
    @ObservedObject var store: ComplaintStore
    let path: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let avatarURL = store.avatarURL(for: path) {
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
        .frame(width: size, height: size)
        .clipShape(Circle())
        .foregroundStyle(Color.rezilRed)
    }
}

extension Notification.Name {
    static let reportCommentReply = Notification.Name("rezil.reportCommentReply")
}
