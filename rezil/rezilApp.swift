//
//  rezilApp.swift
//  rezil
//
//  Created by Erman Manyasli on 4.09.2026.
//

import SwiftUI

@main
struct rezilApp: App {
    @StateObject private var auth = AuthStore()
    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false
    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView { hasCompletedOnboarding = true }
                }
                else if auth.isAuthenticated { ContentView(auth: auth).environmentObject(auth) }
                else if auth.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Hesabın hazırlanıyor…").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).ignoresSafeArea())
                }
                else { ContentView(auth: auth).environmentObject(auth) }
            }
            .onOpenURL { url in _ = auth.handleGoogleURL(url) }
        }
    }
}
