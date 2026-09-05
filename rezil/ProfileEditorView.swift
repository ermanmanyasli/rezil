import PhotosUI
import SwiftUI
import UIKit

struct ProfileEditorView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var city = "İstanbul"
    @State private var country = "Türkiye"
    @State private var photo: PhotosPickerItem?
    @State private var error: String?
    var body: some View {
        NavigationStack { Form {
            Section { PhotosPicker(selection: $photo, matching: .images) { Label("Profil fotoğrafını değiştir", systemImage: "camera.fill") } }
            Section("Profil") {
                TextField("Adın", text: $name)
                Picker("Ülke", selection: $country) {
                    ForEach(ProfileLocationOptions.countries, id: \.self) { Text($0).tag($0) }
                }
                Picker("Şehir", selection: $city) {
                    ForEach(ProfileLocationOptions.cities(for: country), id: \.self) { Text($0).tag($0) }
                }
                .disabled(ProfileLocationOptions.cities(for: country).isEmpty)
            }
            if let error { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Profili düzenle").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } } }
        .onAppear { name = auth.profile?.displayName ?? ""; country = auth.profile?.homeCountry ?? "Türkiye"; city = auth.profile?.homeCity ?? ProfileLocationOptions.cities(for: country).first ?? "" }
        .onChange(of: country) { _, newCountry in city = ProfileLocationOptions.cities(for: newCountry).first ?? "" }
        .onChange(of: photo) { _, item in guard let item else { return }; Task { do { guard let data = try await item.loadTransferable(type: Data.self) else { throw SupabaseError.invalidResponse }; try await auth.uploadAvatar(data) } catch { self.error = error.localizedDescription } } }
        }
    }
    private func save() { Task { do { try await auth.saveProfile(displayName: name.trimmingCharacters(in: .whitespacesAndNewlines), homeCity: city.nilIfEmpty, homeCountry: country.nilIfEmpty, avatarPath: auth.profile?.avatarPath); dismiss() } catch let saveError { self.error = saveError.localizedDescription } } }
}

private extension String { var nilIfEmpty: String? { let value = trimmingCharacters(in: .whitespacesAndNewlines); return value.isEmpty ? nil : value } }
