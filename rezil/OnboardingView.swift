import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @StateObject private var location = LocationService()
    @State private var step = 0

    private let pages: [(title: String, message: String, icon: String)] = [
        ("Sorunları görünür kıl", "REZİL, yaşadığımız yerlerdeki gerçek sorunları haritada buluşturur.", "map.fill"),
        ("Birlikte doğrulayalım", "Gözlemleri kanıt, doğrulama ve çözüm takibiyle anlamlı veriye dönüştürürüz.", "checkmark.seal.fill"),
        ("Çevrendekileri keşfet", "Yakınındaki sorunları gösterebilmemiz için konumunu kullanmamıza izin ver.", "location.fill")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("REZİL").font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(Color.rezilRed)
                Spacer()
                if step < pages.count - 1 { Button("Atla") { onComplete() }.foregroundStyle(.secondary) }
            }.padding(.horizontal, 24).padding(.top, 18)

            Spacer()
            Image(systemName: pages[step].icon).font(.system(size: 58, weight: .semibold)).foregroundStyle(Color("AccentColor"))
                .frame(width: 124, height: 124).background(Color.rezilRed.opacity(0.1), in: Circle())
            Text(pages[step].title).font(.system(size: 30, weight: .bold, design: .rounded)).multilineTextAlignment(.center).padding(.top, 28)
            Text(pages[step].message).font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32).padding(.top, 12)
            Spacer()

            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule().fill(index == step ? Color.rezilRed : Color.secondary.opacity(0.2)).frame(width: index == step ? 24 : 8, height: 8)
                }
            }.padding(.bottom, 24)

            Button(action: next) {
                HStack { if step == pages.count - 1 { Image(systemName: "location.fill") }; Text(step == pages.count - 1 ? "Konum izni ver" : "Devam et") }
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
            }.buttonStyle(.borderedProminent).tint(Color("AccentColor")).padding(.horizontal, 24)

            if step == pages.count - 1 {
                Button("Şimdi değil") { onComplete() }.font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 14)
            }
        }.padding(.bottom, 24).background(Color(.systemBackground).ignoresSafeArea()).animation(.snappy, value: step)
    }

    private func next() {
        if step < pages.count - 1 {
            step += 1
        } else {
            // Complete the app transition independently from the system permission dialog.
            onComplete()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                location.requestLocation()
            }
        }
    }
}
