import SwiftUI

struct OwnedContentView: View {
    @ObservedObject var store: ComplaintStore
    @State private var edit: Complaint?
    @State private var complaintToDelete: Complaint?
    @State private var commentToDelete: ReportComment?
    @State private var showingComplaintDeleteConfirmation = false
    @State private var showingCommentDeleteConfirmation = false

    private var isEmpty: Bool { store.myReports.isEmpty && store.myComments.isEmpty }

    var body: some View {
        Group {
            if store.isLoadingOwned && isEmpty {
                ProgressView("Katkıların yükleniyor…")
            } else if let error = store.errorMessage, isEmpty {
                ContentUnavailableView {
                    Label("Katkılar yüklenemedi", systemImage: "wifi.exclamationmark")
                } description: { Text(error) } actions: {
                    Button("Tekrar dene") { Task { await store.loadOwnedContent() } }.buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    Section("Şikâyetlerim") {
                        if store.myReports.isEmpty {
                            Text("Henüz şikâyetin yok.").foregroundStyle(.secondary)
                        } else {
                            ForEach(store.myReports) { complaint in HStack { Text(complaint.title); Spacer(); Button("Düzenle") { edit = complaint } }.swipeActions { Button("Sil", role: .destructive) { complaintToDelete = complaint; showingComplaintDeleteConfirmation = true } } }
                        }
                    }
                    Section("Yorumlarım") {
                        if store.myComments.isEmpty {
                            Text("Henüz yorumun yok.").foregroundStyle(.secondary)
                        } else {
                            ForEach(store.myComments) { comment in HStack { Text(comment.body); Spacer(); Button("Sil", role: .destructive) { commentToDelete = comment; showingCommentDeleteConfirmation = true } } }
                        }
                    }
                }
                .refreshable { await store.loadOwnedContent() }
            }
        }
        .sheet(item: $edit) { complaint in EditComplaintView(store: store, complaint: complaint) }
        .confirmationDialog("Şikâyet silinsin mi?", isPresented: $showingComplaintDeleteConfirmation, titleVisibility: .visible) {
            Button("Sil", role: .destructive) {
                guard let complaint = complaintToDelete else { return }
                Task {
                    do { try await store.delete(complaint) }
                    catch { store.errorMessage = error.localizedDescription }
                }
            }
            Button("Vazgeç", role: .cancel) { }
        }
        .confirmationDialog("Yorum silinsin mi?", isPresented: $showingCommentDeleteConfirmation, titleVisibility: .visible) {
            Button("Sil", role: .destructive) {
                guard let comment = commentToDelete else { return }
                Task {
                    do { try await store.delete(comment) }
                    catch { store.errorMessage = error.localizedDescription }
                }
            }
            Button("Vazgeç", role: .cancel) { }
        }
    }
}

struct EditComplaintView: View {
    @ObservedObject var store: ComplaintStore
    @Environment(\.dismiss) private var dismiss
    @State private var complaint: Complaint
    @State private var isSaving = false
    @State private var saveError: String?
    init(store: ComplaintStore, complaint: Complaint) { self.store = store; _complaint = State(initialValue: complaint) }

    private var trimmedTitle: String { complaint.title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool {
        !isSaving && !trimmedTitle.isEmpty && trimmedTitle.count <= 240
            && !complaint.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Şikâyet", text: $complaint.title, axis: .vertical)
                Text("\(trimmedTitle.count)/240").font(.caption).foregroundStyle(trimmedTitle.count > 240 ? Color.rezilRed : .secondary)
                Picker("Kategori", selection: $complaint.category) { ForEach(ComplaintCategory.allCases) { Text($0.rawValue).tag($0) } }
                TextField("Konum", text: $complaint.locationName)
                if let saveError {
                    Label(saveError, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(Color.rezilRed)
                }
            }
            .navigationTitle("Şikâyeti düzenle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() }.disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSaving = true
                            saveError = nil
                            defer { isSaving = false }
                            do {
                                var toSave = complaint
                                toSave.title = trimmedTitle
                                try await store.update(toSave)
                                dismiss()
                            } catch {
                                saveError = error.localizedDescription
                            }
                        }
                    } label: {
                        if isSaving { ProgressView() } else { Text("Kaydet") }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
