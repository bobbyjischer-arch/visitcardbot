import Foundation

final class NetworkService {

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 8
        cfg.timeoutIntervalForResource = 15
        return URLSession(configuration: cfg)
    }()

    func sendLocation(_ point: LocationPoint, to serverURL: String) async -> Bool {
        guard let url = URL(string: "\(serverURL)/location/update") else { return false }
        return await post(url: url, body: point.serverPayload)
    }

    func checkHealth(_ serverURL: String) async -> Bool {
        guard let url = URL(string: "\(serverURL)/api/status") else { return false }
        do {
            let (_, r) = try await session.data(from: url)
            return (r as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    func sendSOS(lat: Double, lon: Double, serverURL: String) async -> Bool {
        guard let url = URL(string: "\(serverURL)/sos/trigger") else { return false }
        return await post(url: url, body: [
            "latitude":  lat,
            "longitude": lon,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "source":    "ios_manual"
        ])
    }

    /// Резервный канал: напрямую через Telegram Bot API
    func sendSOSViaTelegram(
        botToken: String,
        contacts: [SOSContact],
        lat: Double, lon: Double,
        lastSeen: Date?
    ) async -> Int {
        guard !botToken.isEmpty, !contacts.isEmpty else { return 0 }

        let mapsLink = "https://maps.google.com/?q=\(lat),\(lon)"
        let timeStr  = lastSeen.map {
            RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date())
        } ?? "только что"
        let text = "🆘 *SOS от O.R.I.O.N.*\n\n📍 [Местоположение](\(mapsLink))\n🕐 Последний раз: \(timeStr)\n\n_Автоматическое уведомление безопасности._"

        var count = 0
        await withTaskGroup(of: Bool.self) { group in
            for c in contacts {
                group.addTask {
                    await self.telegramSend(token: botToken, chatID: c.telegramChatID, text: text)
                }
            }
            for await ok in group { if ok { count += 1 } }
        }
        return count
    }

    // MARK: - Private

    private func post(url: URL, body: [String: Any]) async -> Bool {
        var req        = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, r) = try await session.data(for: req)
            return (200..<300).contains((r as? HTTPURLResponse)?.statusCode ?? 0)
        } catch { return false }
    }

    private func telegramSend(token: String, chatID: String, text: String) async -> Bool {
        guard let url = URL(string: "https://api.telegram.org/bot\(token)/sendMessage") else { return false }
        return await post(url: url, body: ["chat_id": chatID, "text": text, "parse_mode": "Markdown"])
    }
}
