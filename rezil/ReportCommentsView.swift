import SwiftUI

struct ReportCommentsView: View {
    @ObservedObject var store: ComplaintStore
    @EnvironmentObject private var auth: AuthStore
    let complaint: Complaint
    @State private var bodyText = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var commentToDelete: ReportComment?
    @State private var showingDeleteConfirmation = false
    @FocusState private var composerFocused: Bool
    var onBack: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if store.isCommentsLoading(for: complaint.id) && store.comments(for: complaint.id).isEmpty {
                            ProgressView("Yorumlar yükleniyor…").frame(maxWidth: .infinity).padding(.top, 24)
                        } else if store.comments(for: complaint.id).isEmpty {
                            Text("Henüz yorum yok. İlk yorumu sen yaz.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity).padding(.top, 28)
                        } else {
                            ForEach(store.comments(for: complaint.id)) { comment in commentRow(comment) }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                }

                composer
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("Yorumlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onBack {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Geri", action: onBack)
                    }
                }
            }
            .task { await store.loadComments(for: complaint.id) }
            .confirmationDialog("Yorum silinsin mi?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Sil", role: .destructive) {
                    guard let comment = commentToDelete else { return }
                    Task {
                        do { try await store.delete(comment) }
                        catch { errorMessage = error.localizedDescription }
                    }
                }
                Button("Vazgeç", role: .cancel) { }
            } message: { Text("Bu yorum kalıcı olarak kaldırılacak.") }
        }
    }

    private func commentRow(_ comment: ReportComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            avatar(for: comment.authorProfile?.avatarPath, size: 28)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(comment.authorProfile?.displayName ?? "REZİL kullanıcısı").font(.caption.weight(.semibold))
                    Text(RelativeTimestamp.string(from: comment.createdAt)).font(.caption2).foregroundStyle(.secondary)
                }
                Text(comment.body).font(.caption).fixedSize(horizontal: false, vertical: true)
                Button("Yanıtla") {
                    bodyText = "@\(comment.authorProfile?.displayName ?? "kullanıcı") "
                    composerFocused = true
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
            Button {
                store.toggleCommentLike(for: comment.id)
            } label: {
                Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                    .font(.caption)
                    .foregroundStyle(comment.isLiked ? Color.rezilRed : .secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(store.isCommentLikePending(for: comment.id))
            .accessibilityLabel(comment.isLiked ? "Yorumu beğenmekten vazgeç" : "Yorumu beğen")
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if comment.authorID == auth.profile?.id {
                Button("Sil", role: .destructive) {
                    commentToDelete = comment
                    showingDeleteConfirmation = true
                }
                .disabled(store.isCommentDeletePending(for: comment.id))
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                avatar(for: auth.profile?.avatarPath, size: 44)
                TextField("Yorumunu yaz…", text: $bodyText, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($composerFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Button(action: submit) {
                    if isSubmitting { ProgressView().controlSize(.small) }
                    else { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                }
                .foregroundStyle(Color.rezilRed)
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
    }

    @ViewBuilder
    private func avatar(for path: String?, size: CGFloat) -> some View {
        if let avatarURL = store.avatarURL(for: path) {
            AsyncImage(url: avatarURL) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else { Image(systemName: "person.crop.circle.fill").resizable().scaledToFit() }
            }
            .frame(width: size, height: size).clipShape(Circle()).foregroundStyle(Color.rezilRed)
        } else {
            Image(systemName: "person.crop.circle.fill").resizable().scaledToFit()
                .frame(width: size, height: size).foregroundStyle(Color.rezilRed)
        }
    }

    private func submit() {
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                _ = try await store.addComment(reportID: complaint.id, body: trimmed)
                bodyText = ""
            } catch { errorMessage = error.localizedDescription }
            isSubmitting = false
        }
    }
}
