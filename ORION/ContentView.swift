import SwiftUI

struct ContentView: View {
    @EnvironmentObject var location: LocationService
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            StatusView()
                .tabItem { Label("Статус", systemImage: "shield.fill") }
                .tag(0)

            MapHistoryView()
                .tabItem { Label("Карта", systemImage: "map.fill") }
                .tag(1)

            SOSView()
                .tabItem { Label("SOS", systemImage: "sos.circle.fill") }
                .tag(2)

            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .accentColor(.cyan)
        .onReceive(NotificationCenter.default.publisher(for: .openSOSTab)) { _ in
            tab = 2
        }
    }
}

extension Notification.Name {
    static let openSOSTab = Notification.Name("openSOSTab")
}
