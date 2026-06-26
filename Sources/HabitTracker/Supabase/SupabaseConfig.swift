import Foundation

enum SupabaseConfigError: Error, Equatable {
    case missingURL
    case missingAnonKey
    case invalidURL(String)
}

struct SupabaseConfig: Equatable {
    let url: URL
    let anonKey: String

    static func fromBundle(_ bundle: Bundle = .main) throws -> SupabaseConfig {
        guard let rawURL = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !rawURL.isEmpty else {
            throw SupabaseConfigError.missingURL
        }
        guard let key = bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty,
              key != "your-anon-key-here" else {
            throw SupabaseConfigError.missingAnonKey
        }
        guard let url = URL(string: rawURL), url.scheme?.hasPrefix("http") == true else {
            throw SupabaseConfigError.invalidURL(rawURL)
        }
        return SupabaseConfig(url: url, anonKey: key)
    }
}
