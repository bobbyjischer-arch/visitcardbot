import Foundation
import Combine

/// Управляет состоянием блокировки приложения.
/// Правильный код открывает настоящий O.R.I.O.N.
/// Неверный — остаётся в режиме "хранилища файлов".
final class AppLock: ObservableObject {

    static let shared = AppLock()

    // MARK: - State
    @Published var isUnlocked  = false
    @Published var showWrongPW = false   // мигание при неверном коде

    private let correctCode = "0847"
    private var lockTimer: Timer?

    // Автоблокировка через N секунд после ухода в фон
    private let autoLockDelay: TimeInterval = 10

    private init() {
        // Подписываемся на уход в фон
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBackground),
            name:     UIApplication.didEnterBackgroundNotification,
            object:   nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidForeground),
            name:     UIApplication.willEnterForegroundNotification,
            object:   nil
        )
    }

    // MARK: - Public

    func attempt(_ code: String) {
        if code == correctCode {
            isUnlocked  = true
            showWrongPW = false
        } else {
            // Неверный код — остаёмся в decoy, мигаем
            showWrongPW = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.showWrongPW = false
            }
        }
    }

    func lock() {
        isUnlocked = false
    }

    // MARK: - Background handling

    @objc private func appDidBackground() {
        lockTimer = Timer.scheduledTimer(
            withTimeInterval: autoLockDelay,
            repeats: false
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.isUnlocked = false }
        }
    }

    @objc private func appDidForeground() {
        lockTimer?.invalidate()
        lockTimer = nil
    }
}
