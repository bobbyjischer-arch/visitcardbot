import Foundation
import Combine

/// Единственный источник правды для всех настроек приложения.
/// Использует @AppStorage-совместимый UserDefaults через App Group
/// чтобы виджет мог читать те же данные.
final class AppSettings: ObservableObject {

    static let shared = AppSettings()
    static let appGroup = "group.com.stark.orion"

    private let defaults: UserDefaults

    // MARK: - Настройки сервера
    @Published var serverURL: String {
        didSet { defaults.set(serverURL, forKey: "serverURL") }
    }

    // MARK: - Геолокация
    @Published var intervalMinutes: Int {
        didSet { defaults.set(intervalMinutes, forKey: "intervalMinutes") }
    }

    // MARK: - SOS
    @Published var sosContacts: [SOSContact] {
        didSet {
            if let data = try? JSONEncoder().encode(sosContacts) {
                defaults.set(data, forKey: "sosContacts")
            }
        }
    }
    @Published var sosBotToken: String {
        didSet { defaults.set(sosBotToken, forKey: "sosBotToken") }
    }

    // MARK: - Последняя известная точка (для виджета)
    @Published var lastLatitude: Double {
        didSet { defaults.set(lastLatitude, forKey: "lastLatitude") }
    }
    @Published var lastLongitude: Double {
        didSet { defaults.set(lastLongitude, forKey: "lastLongitude") }
    }
    @Published var lastLocationDate: Date? {
        didSet { defaults.set(lastLocationDate, forKey: "lastLocationDate") }
    }
    @Published var systemStatus: String {
        didSet { defaults.set(systemStatus, forKey: "systemStatus") }
    }
    @Published var serverReachable: Bool {
        didSet { defaults.set(serverReachable, forKey: "serverReachable") }
    }
    @Published var totalPointsSent: Int {
        didSet { defaults.set(totalPointsSent, forKey: "totalPointsSent") }
    }

    private init() {
        // App Group даёт доступ виджету к тем же данным
        let d = UserDefaults(suiteName: AppSettings.appGroup) ?? .standard
        self.defaults = d

        self.serverURL        = d.string(forKey: "serverURL")       ?? "http://192.168.1.1:8000"
        self.intervalMinutes  = d.integer(forKey: "intervalMinutes").nonZeroOr(5)
        self.sosBotToken      = d.string(forKey: "sosBotToken")     ?? ""
        self.lastLatitude     = d.double(forKey: "lastLatitude")
        self.lastLongitude    = d.double(forKey: "lastLongitude")
        self.lastLocationDate = d.object(forKey: "lastLocationDate") as? Date
        self.systemStatus     = d.string(forKey: "systemStatus")    ?? "offline"
        self.serverReachable  = d.bool(forKey: "serverReachable")
        self.totalPointsSent  = d.integer(forKey: "totalPointsSent")

        if let data = d.data(forKey: "sosContacts"),
           let contacts = try? JSONDecoder().decode([SOSContact].self, from: data) {
            self.sosContacts = contacts
        } else {
            self.sosContacts = []
        }
    }
}

// MARK: - SOS Contact Model
struct SOSContact: Codable, Identifiable {
    var id: UUID
    var name: String
    var telegramChatID: String

    init(id: UUID = UUID(), name: String, telegramChatID: String) {
        self.id             = id
        self.name           = name
        self.telegramChatID = telegramChatID
    }
}

private extension Int {
    func nonZeroOr(_ fallback: Int) -> Int { self == 0 ? fallback : self }
}
