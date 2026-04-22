import SwiftUI

struct StatusView: View {
    @EnvironmentObject var loc: LocationService
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        headerSection
                        trackingButton
                        serverCard
                        gpsCard
                        statsCard
                        if let err = loc.errorMessage { errorCard(err) }
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Header

    var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("O.R.I.O.N.")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                Text("Adaptive Emergency Guardian")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            Spacer()
            // Индикатор связи с сервером
            Circle()
                .fill(loc.serverOnline ? Color.green : Color.red)
                .frame(width: 10, height: 10)
                .shadow(color: loc.serverOnline ? .green : .red, radius: 4)
                .animation(.easeInOut(duration: 0.5), value: loc.serverOnline)
        }
        .padding(.top, 8)
    }

    // MARK: - Кнопка старт/стоп

    var trackingButton: some View {
        Button {
            loc.isTracking ? loc.stopTracking() : loc.startTracking()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: loc.isTracking ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                Text(loc.isTracking ? "Остановить" : "Запустить слежение")
                    .font(.headline)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(loc.isTracking ? Color.red : Color.cyan)
            .cornerRadius(14)
        }
    }

    // MARK: - Карточки

    var serverCard: some View {
        ORIONCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("Сервер", systemImage: "server.rack")
                    .font(.caption).foregroundColor(.cyan)
                    .textCase(.uppercase).tracking(1)

                HStack {
                    Circle()
                        .fill(loc.serverOnline ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(loc.serverOnline ? "Онлайн" : "Недоступен")
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Button("Проверить") {
                        Task {
                            let ok = await NetworkService().checkHealth(settings.serverURL)
                            loc.serverOnline = ok
                        }
                    }
                    .font(.caption).foregroundColor(.cyan)
                }

                Text(settings.serverURL)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
    }

    var gpsCard: some View {
        ORIONCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("GPS", systemImage: "location.fill")
                    .font(.caption).foregroundColor(.cyan)
                    .textCase(.uppercase).tracking(1)

                switch loc.authStatus {
                case .authorizedAlways:
                    row("🟢", "Разрешено: всегда")
                case .authorizedWhenInUse:
                    row("🟡", "Разрешено: при использовании")
                    Text("Лучше выдать «Всегда» для фона")
                        .font(.caption2).foregroundColor(.orange)
                case .denied, .restricted:
                    row("🔴", "Доступ запрещён")
                default:
                    row("⚪", "Нет разрешения")
                }

                if let coord = loc.currentLocation?.coordinate {
                    row("📍", String(format: "%.5f, %.5f", coord.latitude, coord.longitude))
                }

                if !loc.isTracking && loc.authStatus != .denied {
                    Button("Выдать разрешение") { loc.requestPermission() }
                        .font(.caption).foregroundColor(.cyan)
                }
            }
        }
    }

    var statsCard: some View {
        ORIONCard {
            HStack(spacing: 0) {
                statItem(value: "\(settings.totalPointsSent)", label: "Отправлено")
                Divider().background(Color.white.opacity(0.1))
                statItem(value: "\(loc.locationHistory.count)", label: "В памяти")
                Divider().background(Color.white.opacity(0.1))
                statItem(
                    value: settings.lastLocationDate.map {
                        let m = Int(-$0.timeIntervalSinceNow / 60)
                        return m < 1 ? "сейчас" : "\(m)м"
                    } ?? "—",
                    label: "Обновление"
                )
            }
        }
    }

    func errorCard(_ msg: String) -> some View {
        ORIONCard {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text(msg).font(.caption).foregroundColor(.orange)
            }
        }
    }

    // MARK: - Helpers

    func row(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Text(icon).font(.caption)
            Text(text).font(.system(.caption, design: .monospaced)).foregroundColor(.white.opacity(0.85))
        }
    }

    func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title3, design: .monospaced)).foregroundColor(.cyan)
            Text(label).font(.caption2).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
