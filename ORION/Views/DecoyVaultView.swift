import SwiftUI

/// Фальшивое хранилище файлов.
/// Показывается при неверном пароле.
/// Выглядит как настоящее приложение — фотографии, документы, заметки.
/// Скрытый вход в ORION: набрать 0847 в поиске.
struct DecoyVaultView: View {

    let onCorrectCode: () -> Void

    @State private var selectedTab  = 0
    @State private var searchText   = ""
    @State private var showSearch   = false

    // Скрытый триггер — ввести правильный код в поиске
    private let secretSearch = "0847"

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()

                TabView(selection: $selectedTab) {
                    filesTab
                        .tabItem { Label("Файлы", systemImage: "folder.fill") }
                        .tag(0)

                    photosTab
                        .tabItem { Label("Фото", systemImage: "photo.fill") }
                        .tag(1)

                    docsTab
                        .tabItem { Label("Документы", systemImage: "doc.fill") }
                        .tag(2)

                    settingsDecoyTab
                        .tabItem { Label("Настройки", systemImage: "gearshape.fill") }
                        .tag(3)
                }
                .accentColor(Color(hex: "4FC3F7"))
            }
        }
        .onChange(of: searchText) { text in
            if text == secretSearch {
                // Тихо активируем ORION
                searchText = ""
                showSearch = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onCorrectCode()
                }
            }
        }
    }

    // MARK: - Вкладка: Файлы

    var filesTab: some View {
        List {
            Section("Недавние") {
                ForEach(DecoyData.recentFiles) { f in
                    DecoyFileRow(file: f)
                }
            }
            Section("Папки") {
                ForEach(DecoyData.folders) { folder in
                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill")
                            .font(.title2)
                            .foregroundColor(Color(hex: "4FC3F7"))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(folder.name).font(.body)
                            Text("\(folder.count) файлов")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Secure Vault")
        .searchable(text: $searchText, isPresented: $showSearch, prompt: "Поиск файлов")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showSearch = true } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - Вкладка: Фото

    var photosTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Защищённые фото")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Сетка заглушек
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 2) {
                    ForEach(0..<18, id: \.self) { i in
                        Rectangle()
                            .fill(Color.gray.opacity(Double.random(in: 0.1...0.25)))
                            .aspectRatio(1, contentMode: .fill)
                            .overlay(
                                Image(systemName: ["photo", "photo.fill", "camera.fill", "video.fill"].randomElement()!)
                                    .foregroundColor(.gray.opacity(0.3))
                            )
                    }
                }

                Text("18 объектов · \(String(format: "%.1f", Double.random(in: 200...800))) МБ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
        .navigationTitle("Фото")
    }

    // MARK: - Вкладка: Документы

    var docsTab: some View {
        List {
            Section("Последние") {
                ForEach(DecoyData.documents) { doc in
                    HStack(spacing: 12) {
                        Image(systemName: doc.icon)
                            .font(.title2)
                            .foregroundColor(doc.color)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(doc.name).font(.body)
                            Text(doc.date + " · " + doc.size)
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Документы")
    }

    // MARK: - Вкладка: Настройки (decoy)

    var settingsDecoyTab: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "4FC3F7"))
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Мой аккаунт")
                            .font(.headline)
                        Text("Локальное хранилище")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Хранилище") {
                decoySettingsRow("iCloud Sync", icon: "cloud.fill",   color: "4FC3F7", value: "Вкл")
                decoySettingsRow("Биометрия",   icon: "faceid",        color: "30D158", value: "Face ID")
                decoySettingsRow("Занято",       icon: "internaldrive", color: "FF9F0A", value: "1.2 ГБ")
            }
            Section("Безопасность") {
                decoySettingsRow("Автоблокировка", icon: "lock.fill",      color: "FF453A", value: "1 мин")
                decoySettingsRow("Фейковый пароль",icon: "key.fill",       color: "BF5AF2", value: "••••")
                decoySettingsRow("Журнал входов",  icon: "list.bullet",    color: "636366", value: "")
            }
            Section {
                Button(role: .destructive) { } label: {
                    HStack {
                        Spacer()
                        Text("Сбросить данные")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Настройки")
    }

    func decoySettingsRow(_ title: String, icon: String, color: String, value: String) -> some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(hex: color))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
    }
}

// MARK: - Decoy Data Models

struct DecoyFile: Identifiable {
    let id    = UUID()
    let name:  String
    let icon:  String
    let color: String
    let size:  String
    let date:  String
}

struct DecoyFolder: Identifiable {
    let id    = UUID()
    let name:  String
    let count: Int
}

struct DecoyDocument: Identifiable {
    let id    = UUID()
    let name:  String
    let icon:  String
    let color: Color
    let date:  String
    let size:  String
}

struct DecoyData {
    static let recentFiles: [DecoyFile] = [
        .init(name: "Сканы документов.zip",  icon: "doc.zipper",        color: "FF9F0A", size: "24.3 МБ", date: "Сегодня"),
        .init(name: "Резюме_2024.pdf",        icon: "doc.fill",          color: "FF453A", size: "1.8 МБ",  date: "Вчера"),
        .init(name: "Пароли.txt",             icon: "doc.text.fill",     color: "636366", size: "4 КБ",    date: "3 дня назад"),
        .init(name: "Фото паспорта.jpg",      icon: "photo.fill",        color: "30D158", size: "3.2 МБ",  date: "5 дней назад"),
        .init(name: "Банковские реквизиты",   icon: "creditcard.fill",   color: "4FC3F7", size: "12 КБ",   date: "Неделю назад"),
    ]

    static let folders: [DecoyFolder] = [
        .init(name: "Документы",       count: 23),
        .init(name: "Фотографии",      count: 147),
        .init(name: "Важное",          count: 8),
        .init(name: "Резервные копии", count: 3),
        .init(name: "Разное",          count: 41),
    ]

    static let documents: [DecoyDocument] = [
        .init(name: "Договор аренды.pdf",  icon: "doc.fill",       color: .red,    date: "12.03.2025", size: "2.1 МБ"),
        .init(name: "Смета_ремонт.xlsx",   icon: "tablecells.fill", color: .green,  date: "28.02.2025", size: "340 КБ"),
        .init(name: "Заметки.txt",         icon: "note.text",       color: .orange, date: "15.01.2025", size: "8 КБ"),
        .init(name: "Страховка ОСАГО.pdf", icon: "doc.fill",        color: .red,    date: "01.01.2025", size: "1.5 МБ"),
    ]
}

// MARK: - Decoy File Row

struct DecoyFileRow: View {
    let file: DecoyFile
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: file.icon)
                .font(.title2)
                .foregroundColor(Color(hex: file.color))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name).font(.body).lineLimit(1)
                Text(file.date + " · " + file.size)
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "ellipsis")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}
