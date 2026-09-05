import Foundation

enum ProfileLocationOptions {
    static let countries = ["Türkiye", "Almanya", "Amerika Birleşik Devletleri", "Birleşik Krallık", "Fransa", "Hollanda"]

    static let citiesByCountry: [String: [String]] = [
        "Türkiye": ["Adana", "Ankara", "Antalya", "Bursa", "İstanbul", "İzmir", "Kocaeli", "Konya", "Mersin", "Samsun", "Trabzon"],
        "Almanya": ["Berlin", "Hamburg", "Köln", "Münih", "Frankfurt"],
        "Amerika Birleşik Devletleri": ["New York", "Los Angeles", "Chicago", "San Francisco", "Washington"],
        "Birleşik Krallık": ["Londra", "Manchester", "Birmingham", "Edinburgh"],
        "Fransa": ["Paris", "Lyon", "Marsilya", "Nice"],
        "Hollanda": ["Amsterdam", "Rotterdam", "Lahey", "Utrecht"]
    ]

    static func cities(for country: String) -> [String] { citiesByCountry[country] ?? [] }
}
