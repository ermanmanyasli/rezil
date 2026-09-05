import Foundation

enum AppConfigurationError: Error, Equatable {
    case missingSupabaseConfiguration
    case invalidSupabaseURL
}

struct AppConfiguration: Sendable {
    let supabaseURL: URL
    let supabaseAnonKey: String
    let googleClientID: String
    let googleServerClientID: String

    nonisolated init(url: String, anonKey: String, googleClientID: String, googleServerClientID: String? = nil) throws {
        let serverClientID = googleServerClientID ?? googleClientID
        guard !url.isEmpty, !anonKey.isEmpty, !googleClientID.isEmpty, !serverClientID.isEmpty else { throw AppConfigurationError.missingSupabaseConfiguration }
        guard let supabaseURL = URL(string: url), supabaseURL.scheme == "https" else {
            throw AppConfigurationError.invalidSupabaseURL
        }
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = anonKey
        self.googleClientID = googleClientID
        self.googleServerClientID = serverClientID
    }

    nonisolated static func fromInfoDictionary(_ info: [String: Any] = Bundle.main.infoDictionary ?? [:]) throws -> AppConfiguration {
        try AppConfiguration(
            url: info["SUPABASE_URL"] as? String ?? "",
            anonKey: info["SUPABASE_ANON_KEY"] as? String ?? "",
            googleClientID: info["GOOGLE_CLIENT_ID"] as? String ?? "",
            googleServerClientID: info["GOOGLE_SERVER_CLIENT_ID"] as? String
        )
    }
}
