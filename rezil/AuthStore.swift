import Combine
import CryptoKit
import Foundation
import GoogleSignIn
import SwiftUI
import UIKit

@MainActor
final class AuthStore: NSObject, ObservableObject {
    @Published private(set) var session: SupabaseSession?
    @Published private(set) var profile: Profile?
    @Published private(set) var isLoading = true
    @Published private(set) var isSigningIn = false
    @Published var errorMessage: String?

    private let configuration: AppConfiguration?
    private let keychain = KeychainStore()

    init(configuration: AppConfiguration? = try? .fromInfoDictionary()) {
        self.configuration = configuration
        super.init()
        if let accessToken = keychain.value(for: "access_token"), let userData = keychain.value(for: "user")?.data(using: .utf8), let user = try? JSONDecoder().decode(SupabaseUser.self, from: userData) {
            session = SupabaseSession(accessToken: accessToken, refreshToken: keychain.value(for: "refresh_token"), user: user)
        }
        Task { await restoreSession() }
    }

    var isAuthenticated: Bool { session != nil }

    func signInWithGoogle() async {
        guard let configuration else { errorMessage = "Supabase ve Google ayarları eksik. README içindeki kurulumu tamamla."; return }
        guard let presenter = Self.presentingViewController() else { errorMessage = "Giriş ekranı açılamadı."; return }
        errorMessage = nil
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            // Use the configured Supabase/Google client as the token audience so
            // the ID token can be validated by the backend.
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(
                clientID: configuration.googleClientID,
                serverClientID: configuration.googleServerClientID
            )
            let nonce = UUID().uuidString
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presenter,
                hint: nil,
                additionalScopes: nil,
                nonce: GoogleNonce.sha256(nonce)
            )
            guard let idToken = result.user.idToken?.tokenString else { throw SupabaseError.invalidResponse }
            let accessToken = result.user.accessToken.tokenString
            let session = try await SupabaseClient(configuration: configuration, session: nil).signInWithGoogle(idToken: idToken, accessToken: accessToken, nonce: nonce)
            self.session = session; try persist(session); await loadProfile()
        } catch GIDSignInError.canceled { return }
        catch { errorMessage = error.localizedDescription }
    }

    func handleGoogleURL(_ url: URL) -> Bool { GIDSignIn.sharedInstance.handle(url) }

    func signInWithPassword(email: String, password: String) async {
        await performAuth { client in try await client.signInWithPassword(email: email, password: password) }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        session = nil; profile = nil
        keychain.delete("access_token"); keychain.delete("refresh_token"); keychain.delete("user")
    }

    func client() -> SupabaseClient? {
        guard let configuration, let session else { return nil }
        return SupabaseClient(configuration: configuration, session: session)
    }

    func publicClient() -> SupabaseClient? {
        guard let configuration else { return nil }
        return SupabaseClient(configuration: configuration, session: nil)
    }

    func validClient() async throws -> SupabaseClient {
        try await refreshIfNeeded()
        guard let client = client() else { throw SupabaseError.notAuthenticated }
        return client
    }

    func saveProfile(displayName: String, homeCity: String?, homeCountry: String?, avatarPath: String?) async throws {
        let client = try await validClient()
        profile = try await client.updateProfile(displayName: displayName, homeCity: homeCity, homeCountry: homeCountry, avatarPath: avatarPath)
    }

    func uploadAvatar(_ data: Data) async throws {
        let client = try await validClient()
        let path = try await client.uploadAvatar(data)
        guard let currentProfile = profile else { return }
        profile = try await client.updateProfile(displayName: currentProfile.displayName, homeCity: currentProfile.homeCity, homeCountry: currentProfile.homeCountry, avatarPath: path)
    }

    private func restoreSession() async {
        do {
            try await refreshIfNeeded()
            await loadProfile()
        } catch {
            signOut()
            errorMessage = "Oturum süresi doldu. Lütfen tekrar giriş yap."
            isLoading = false
        }
    }

    private func refreshIfNeeded() async throws {
        guard let session else { return }
        guard JWTToken.needsRefresh(session.accessToken) else { return }
        guard let refreshToken = session.refreshToken, let configuration else {
            throw SupabaseError.notAuthenticated
        }
        let refreshed = try await SupabaseClient(configuration: configuration, session: nil).refreshSession(refreshToken: refreshToken)
        self.session = refreshed
        try persist(refreshed)
    }

    private func loadProfile() async {
        guard let client = client() else { isLoading = false; return }
        do {
            if let profile = try await client.fetchProfile(userID: session!.user.id) { self.profile = profile }
            else { self.profile = try await client.upsertProfile(Profile(id: session!.user.id, displayName: session?.user.userMetadata?.fullName ?? "REZİL kullanıcısı", avatarPath: nil, homeCity: nil, reputationScore: 0, createdAt: .now)) }
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    private func performAuth(_ operation: (SupabaseClient) async throws -> SupabaseSession) async {
        guard let configuration else { errorMessage = "Supabase ve Google ayarları eksik. README içindeki kurulumu tamamla."; return }
        do { let session = try await operation(SupabaseClient(configuration: configuration, session: nil)); self.session = session; try persist(session); await loadProfile() }
        catch { errorMessage = error.localizedDescription }
    }

    private func persist(_ session: SupabaseSession) throws {
        try keychain.save(session.accessToken, for: "access_token")
        if let refreshToken = session.refreshToken { try keychain.save(refreshToken, for: "refresh_token") }
        else { keychain.delete("refresh_token") }
        try keychain.save(String(data: JSONEncoder().encode(session.user), encoding: .utf8) ?? "", for: "user")
    }

    private static func presentingViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
        var controller = window?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }

}

enum GoogleNonce {
    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

struct SignInView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 7) {
                HStack(spacing: 0) {
                    Text("REZ").foregroundStyle(Color.rezilRed)
                    Text("!").foregroundStyle(Color.rezilRed)
                    Text("L").foregroundStyle(Color.rezilRed)
                }
                .font(.system(size: 42, weight: .black, design: .rounded))
                Text("Gördüğün sorunu görünür kıl.")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)

            HStack(spacing: 0) {
                authStep("GÖR", systemImage: "eye.fill")
                stepDivider
                authStep("PAYLAŞ", systemImage: "arrow.up.right")
                stepDivider
                authStep("ÇÖZ", systemImage: "checkmark.seal.fill")
            }
            .foregroundStyle(Color.rezilRed)
            .padding(.horizontal, 28)
            .padding(.top, 22)

            VStack(spacing: 14) {
                Text("Katkı vermek için giriş yap.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                ZStack {
                    GoogleSignInButton { Task { await auth.signInWithGoogle() } }
                        .disabled(auth.isSigningIn)
                        .opacity(auth.isSigningIn ? 0.45 : 1)
                    if auth.isSigningIn { ProgressView().controlSize(.small) }
                }
                .frame(height: 50)
                .padding(.horizontal, 28)
            }
            .padding(.top, 24)

            if let errorMessage = auth.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.rezilRed)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
            }

            Spacer(minLength: 18)

            Text("Giriş yaparak kullanım koşullarını ve gizlilik politikasını kabul edersin.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 34)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private func authStep(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage).font(.caption.weight(.bold))
            Text(title).font(.caption2.weight(.black))
        }
        .frame(maxWidth: .infinity)
    }

    private var stepDivider: some View {
        Image(systemName: "chevron.right")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.rezilRed.opacity(0.45))
    }
}

private struct GoogleSignInButton: UIViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> GIDSignInButton {
        let button = GIDSignInButton()
        button.style = .wide
        button.colorScheme = .light
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTap), for: .touchUpInside)
        button.accessibilityIdentifier = "google-sign-in"
        return button
    }

    func updateUIView(_ button: GIDSignInButton, context: Context) { }

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func didTap() { action() }
    }
}
