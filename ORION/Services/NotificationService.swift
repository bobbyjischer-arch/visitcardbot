import Foundation
import UserNotifications

final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    // MARK: - Разрешение

    func requestPermission() async {
        try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Уведомления

    /// Сервер недоступен
    func notifyServerDown() {
        send(
            id:    "server_down",
            title: "⚠️ O.R.I.O.N. — нет связи",
            body:  "Сервер недоступен. Координаты не отправляются.",
            sound: .default
        )
    }

    /// Сервер восстановлен
    func notifyServerRestored() {
        // Убираем предыдущее уведомление о потере связи
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: ["server_down"])
        send(
            id:    "server_restored",
            title: "✅ O.R.I.O.N. — связь восстановлена",
            body:  "Сервер снова доступен.",
            sound: .default
        )
    }

    /// SOS отправлен
    func notifySOSSent(contactCount: Int) {
        send(
            id:    "sos_sent",
            title: "🆘 SOS отправлен",
            body:  "Уведомлено контактов: \(contactCount). Помощь в пути.",
            sound: UNNotificationSound(named: UNNotificationSoundName("sos.caf"))
        )
    }

    /// Тревога от сервера
    func notifyAlert(reason: String) {
        send(
            id:    "orion_alert",
            title: "🚨 O.R.I.O.N. — ТРЕВОГА",
            body:  reason,
            sound: .defaultCritical
        )
    }

    // MARK: - Внутренний метод

    private func send(id: String, title: String, body: String, sound: UNNotificationSound?) {
        let content        = UNMutableNotificationContent()
        content.title      = title
        content.body       = body
        content.sound      = sound

        let request = UNNotificationRequest(
            identifier: id,
            content:    content,
            trigger:    nil   // доставить немедленно
        )
        UNUserNotificationCenter.current().add(request)
    }
}
