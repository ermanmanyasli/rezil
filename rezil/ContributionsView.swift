import SwiftUI

struct ContributionsView: View {
    @ObservedObject var store: ComplaintStore
    @EnvironmentObject private var auth: AuthStore
    let authRequiredAction: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if auth.isAuthenticated {
                    OwnedContentView(store: store)
                        .task { await store.loadOwnedContent() }
                } else {
                    ContentUnavailableView {
                        Label("Katkılarını gör", systemImage: "person.crop.circle.badge.checkmark")
                    } description: {
                        Text("Şikâyetlerini, doğrulamalarını ve yorumlarını tek yerde görmek için giriş yap.")
                    } actions: {
                        Button("Giriş yap", action: authRequiredAction)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Katkılar")
        }
    }
}
