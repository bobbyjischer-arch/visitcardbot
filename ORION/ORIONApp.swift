import SwiftUI

@main
struct ORIONApp: App {
    @StateObject private var location = LocationService()
    @StateObject private var sos      = SOSService()
    @StateObject private var settings = AppSettings.shared
    @ObservedObject  private var lock  = AppLock.shared

    init() {
        Task { await NotificationService.shared.requestPermission() }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if lock.isUnlocked {
                    // Правильный пароль — показываем настоящий O.R.I.O.N.
                    ContentView()
                        .environmentObject(location)
                        .environmentObject(sos)
                        .environmentObject(settings)
                        .preferredColorScheme(.dark)
                        .transition(.opacity)
                } else {
                    // Экран блокировки — выглядит как Secure Vault
                    LockView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: lock.isUnlocked)
        }
    }
}
