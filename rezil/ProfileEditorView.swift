import PhotosUI
import SwiftUI
import UIKit

struct ProfileEditorView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var photo: PhotosPickerItem?
    @State private var error: String?
    var body: some View {
        NavigationStack { Form {
            Section { PhotosPicker(selection: $photo, matching: .images) { Label("Profil fotoğrafını değiştir", systemImage: "camera.fill") } }
            Section("Profil") {
                TextField("Adın", text: $name)
            }
            if let error { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Profili düzenle").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } } }
        .onAppear { name = auth.profile?.displayName ?? "" }
        .onChange(of: photo) { _, item in guard let item else { return }; Task { do { guard let data = try await item.loadTransferable(type: Data.self) else { throw SupabaseError.invalidResponse }; try await auth.uploadAvatar(data) } catch { self.error = error.localizedDescription } } }
        }
    }
    private func save() { Task { do { try await auth.saveProfile(displayName: name.trimmingCharacters(in: .whitespacesAndNewlines), avatarPath: auth.profile?.avatarPath); dismiss() } catch let saveError { self.error = saveError.localizedDescription } } }
}
