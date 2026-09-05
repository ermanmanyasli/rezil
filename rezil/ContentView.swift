//
//  ContentView.swift
//  rezil
//
//  Created by Erman Manyasli on 4.09.2026.
//

import SwiftUI
import UIKit
import CoreLocation

struct ContentView: View {
    @ObservedObject var auth: AuthStore
    @StateObject private var store: ComplaintStore
    @State private var selectedTab: AppTab = .map
    @State private var isCreatingComplaint = false
    @State private var draftInitialCoordinate: CLLocationCoordinate2D?
    @State private var mapCenter: CLLocationCoordinate2D?
    @State private var notice: AppNotice?
    @State private var showingAuth = false

    init(auth: AuthStore) {
        self.auth = auth
        _store = StateObject(wrappedValue: ComplaintStore(auth: auth))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .map:
                    ComplaintMapView(store: store, mapCenter: $mapCenter, authRequiredAction: { showingAuth = true }) { coordinate in
                        draftInitialCoordinate = coordinate
                        requireAuth { isCreatingComplaint = true }
                    }
                case .discover:
                    DiscoverView(store: store, authRequiredAction: { showingAuth = true }, addAction: {
                        draftInitialCoordinate = nil
                        requireAuth { isCreatingComplaint = true }
                    })
                case .contributions:
                    ContributionsView(store: store, authRequiredAction: { showingAuth = true })
                case .profile: ProfileView(store: store, authRequiredAction: { showingAuth = true })
                }
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 78) }

            BottomBar(selectedTab: $selectedTab) {
                draftInitialCoordinate = selectedTab == .map ? mapCenter : nil
                requireAuth { isCreatingComplaint = true }
            }

            if let notice {
                NoticeBanner(notice: notice)
                    .padding(.horizontal, 16)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .sheet(isPresented: $isCreatingComplaint) {
            NewComplaintView(store: store, initialCoordinate: draftInitialCoordinate) { _ in
                selectedTab = .map
                showNotice(.success("Şikâyetin haritaya eklendi."))
            }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAuth) {
            SignInView()
                .environmentObject(auth)
                .presentationDetents([.medium])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(.systemBackground))
        }
        .tint(.rezilRed)
        .task { await store.load() }
        .onChange(of: auth.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated { showingAuth = false }
        }
        .onChange(of: store.errorMessage) { _, message in
            guard let message else { return }
            showNotice(.error(message))
        }
    }

    private func requireAuth(_ action: () -> Void) {
        guard auth.isAuthenticated else { showingAuth = true; return }
        action()
    }


    private func showNotice(_ newNotice: AppNotice) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(newNotice.kind == .success ? .success : .error)
        withAnimation(.snappy) { notice = newNotice }
        Task {
            try? await Task.sleep(for: .seconds(3))
            guard notice?.id == newNotice.id else { return }
            withAnimation(.snappy) { notice = nil }
        }
    }
}

struct AppNotice: Identifiable, Equatable {
    enum Kind: Equatable { case success, error }
    let id = UUID()
    let kind: Kind
    let message: String

    static func success(_ message: String) -> AppNotice { AppNotice(kind: .success, message: message) }
    static func error(_ message: String) -> AppNotice { AppNotice(kind: .error, message: message) }
}

private struct NoticeBanner: View {
    let notice: AppNotice

    var body: some View {
        Label(notice.message, systemImage: notice.kind == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(notice.kind == .success ? Color.green : Color.rezilRed, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 12, y: 5)
            .accessibilityIdentifier("app-notice")
    }
}

private enum AppTab: CaseIterable {
    case map, discover, contributions, profile
    var title: String {
        switch self {
        case .map: "Harita"
        case .discover: "Keşfet"
        case .contributions: "Katkılar"
        case .profile: "Profil"
        }
    }
    var icon: String {
        switch self {
        case .map: "map.fill"
        case .discover: "safari.fill"
        case .contributions: "person.crop.circle.badge.checkmark"
        case .profile: "person.fill"
        }
    }
}

private struct BottomBar: View {
    @Binding var selectedTab: AppTab
    let addAction: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            barSlot { tabButton(.map) }
            barSlot { tabButton(.discover) }
            barSlot { addButton }
            barSlot { tabButton(.contributions) }
            barSlot { tabButton(.profile) }
        }
        .frame(height: 78)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private var addButton: some View {
        Button(action: addAction) {
            Image(systemName: "plus")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.rezilRed, in: Circle())
                .shadow(color: Color.rezilRed.opacity(0.32), radius: 10, y: 5)
        }
        .accessibilityLabel("Yeni şikâyet ekle")
        .accessibilityIdentifier("add-report")
    }

    private func barSlot<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .frame(height: 78)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            withAnimation(.snappy) { selectedTab = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon).font(.system(size: 19, weight: .semibold))
                Text(tab.title).font(.caption2.weight(.semibold))
            }
            .foregroundStyle(selectedTab == tab ? Color.rezilRed : .secondary).frame(width: 58)
        }
        .accessibilityIdentifier("tab-\(tab.title.lowercased())")
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }
}

extension Color { static let rezilRed = Color("AccentColor") }

#Preview { ContentView(auth: AuthStore()) }
