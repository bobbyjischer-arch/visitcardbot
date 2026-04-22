import SwiftUI

/// Экран блокировки.
/// Выглядит как вход в защищённое хранилище файлов.
/// Правильный код (0847) → O.R.I.O.N.
/// Неверный код → DecoyVaultView (фальшивые файлы).
struct LockView: View {

    @ObservedObject var lock = AppLock.shared
    @State private var code       = ""
    @State private var shake      = false
    @State private var showDecoy  = false

    // Максимум 4 цифры
    private let codeLength = 4

    var body: some View {
        ZStack {
            // Фон — нейтральный серый, совсем не похожий на ORION
            LinearGradient(
                colors: [Color(hex: "1C1C1E"), Color(hex: "2C2C2E")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Иконка и заголовок
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "4FC3F7"), Color(hex: "0288D1")],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: Color(hex: "4FC3F7").opacity(0.3), radius: 12)

                    Text("Secure Vault")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Введите код доступа")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer().frame(height: 48)

                // Точки кода
                HStack(spacing: 18) {
                    ForEach(0..<codeLength, id: \.self) { i in
                        Circle()
                            .fill(i < code.count
                                  ? Color(hex: "4FC3F7")
                                  : Color.white.opacity(0.15))
                            .frame(width: 16, height: 16)
                            .scaleEffect(i < code.count ? 1.1 : 1.0)
                            .animation(.spring(response: 0.2), value: code.count)
                    }
                }
                .offset(x: shake ? -8 : 0)
                .animation(
                    shake ? .easeInOut(duration: 0.05).repeatCount(6, autoreverses: true) : .default,
                    value: shake
                )

                Spacer().frame(height: 48)

                // Цифровая клавиатура
                numpad

                Spacer().frame(height: 32)

                // Подпись
                Text("Secure Vault Pro · v3.1")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.2))

                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .fullScreenCover(isPresented: $showDecoy) {
            DecoyVaultView(onCorrectCode: {
                showDecoy = false
                lock.isUnlocked = true
            })
        }
        // Правильный код — переход к ORION происходит в ORIONApp через lock.isUnlocked
    }

    // MARK: - Numpad

    var numpad: some View {
        let rows: [[String]] = [
            ["1","2","3"],
            ["4","5","6"],
            ["7","8","9"],
            ["","0","⌫"],
        ]
        return VStack(spacing: 14) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { key in
                        NumpadKey(label: key) {
                            handleKey(key)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Logic

    func handleKey(_ key: String) {
        switch key {
        case "⌫":
            if !code.isEmpty { code.removeLast() }
        case "":
            break
        default:
            guard code.count < codeLength else { return }
            code.append(key)

            if code.count == codeLength {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    submit()
                }
            }
        }
    }

    func submit() {
        if code == "0847" {
            lock.attempt(code)
            // isUnlocked = true → ORIONApp покажет ContentView
        } else {
            // Неверный → трясём и показываем фальшивое хранилище
            shake = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                shake = false
                code  = ""
                // Показываем decoy — выглядит как "успешный вход"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showDecoy = true
                }
            }
        }
    }
}

// MARK: - Numpad Key

struct NumpadKey: View {
    let label: String
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            guard !label.isEmpty else { return }
            action()
        }) {
            ZStack {
                Circle()
                    .fill(label.isEmpty
                          ? Color.clear
                          : Color.white.opacity(pressed ? 0.25 : 0.1))
                    .frame(width: 72, height: 72)

                if label == "⌫" {
                    Image(systemName: "delete.left")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text(label)
                        .font(.system(size: 26, weight: .regular, design: .rounded))
                        .foregroundColor(label.isEmpty ? .clear : .white)
                }
            }
        }
        .buttonStyle(PressedButtonStyle())
        .disabled(label.isEmpty)
    }
}

struct PressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >>  8) & 0xFF) / 255
        let b = Double( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
