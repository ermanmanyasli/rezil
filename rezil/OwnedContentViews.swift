import SwiftUI

struct OwnedContentView: View {
    @ObservedObject var store: ComplaintStore
    @State private var edit: Complaint?
    @State private var complaintToDelete: Complaint?
    @State private var commentToDelete: ReportComment?
    @State private var showingComplaintDeleteConfirmation = false
    @State private var showingCommentDeleteConfirmation = false
    var body: some View { List {
        Section("Şikâyetlerim") { ForEach(store.myReports) { complaint in HStack { Text(complaint.title); Spacer(); Button("Düzenle") { edit = complaint } }.swipeActions { Button("Sil", role: .destructive) { complaintToDelete = complaint; showingComplaintDeleteConfirmation = true } } } }
        Section("Yorumlarım") { ForEach(store.myComments) { comment in HStack { Text(comment.body); Spacer(); Button("Sil", role: .destructive) { commentToDelete = comment; showingCommentDeleteConfirmation = true } } } }
    }.sheet(item: $edit) { complaint in EditComplaintView(store: store, complaint: complaint) }
        .confirmationDialog("Şikâyet silinsin mi?", isPresented: $showingComplaintDeleteConfirmation, titleVisibility: .visible) {
            Button("Sil", role: .destructive) {
                guard let complaint = complaintToDelete else { return }
                Task { try? await store.delete(complaint) }
            }
            Button("Vazgeç", role: .cancel) { }
        }
        .confirmationDialog("Yorum silinsin mi?", isPresented: $showingCommentDeleteConfirmation, titleVisibility: .visible) {
            Button("Sil", role: .destructive) {
                guard let comment = commentToDelete else { return }
                Task { try? await store.delete(comment) }
            }
            Button("Vazgeç", role: .cancel) { }
        }
    }
}

struct EditComplaintView: View {
    @ObservedObject var store: ComplaintStore
    @Environment(\.dismiss) private var dismiss
    @State private var complaint: Complaint
    init(store: ComplaintStore, complaint: Complaint) { self.store = store; _complaint = State(initialValue: complaint) }
    var body: some View { NavigationStack { Form { TextField("Şikâyet", text: $complaint.title, axis: .vertical); Picker("Kategori", selection: $complaint.category) { ForEach(ComplaintCategory.allCases) { Text($0.rawValue).tag($0) } }; TextField("Konum", text: $complaint.locationName) }.navigationTitle("Şikâyeti düzenle").toolbar { Button("Kaydet") { Task { try? await store.update(complaint); dismiss() } } } } }
}
