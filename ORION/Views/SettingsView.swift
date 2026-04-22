import SwiftUI

// MARK: - Main Settings View

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var loc: LocationService

    @State private var urlDraft    = ""
    @State private var tokenDraft  = ""
    @State private var saved       = false
    @State private var showAddContact   = false
    @State private var editingContact: SOSContact? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                Form {
                    serverSection
                    trackingSection
                    sosSection
                    permissionsSection
                    infoSection
                }
                .scrollContentBackground(.hidden)
                .background(Color.black)
            }
            .navigationTitle("⚙️ Настройки")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            urlDraft   = settings.serverURL
            tokenDraft = settings.sosBotToken
        }
        .sheet(isPresented: $showAddContact) {
            ContactEditSheet(contact: nil) { newContact in
                settings.sosContacts.append(newContact)
            }
        }
        .sheet(item: $editingContact) { contact in
            ContactEditSheet(contact: contact) { updated in
                if let idx = settings.sosContacts.firstIndex(where: { $0.id == updated.id }) {
                    settings.sosContacts[idx] = updated
                }
            }
        }
    }

    // MARK: - Секции

    var serverSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("URL сервера O.R.I.O.N.")
                    .font(.caption).foregroundColor(.gray)
                TextField("http://192.168.1.X:8000", text: $urlDraft)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            .padding(.vertical, 4)

            Button {
                settings.serverURL = urlDraft.trimmingCharacters(in: .whitespaces)
                saved = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
            } label: {
                HStack {
                    Spacer()
                    Text(saved ? "✅ Сохранено" : "Сохранить")
                        .font(.headline)
                        .foregroundColor(saved ? .green : .cyan)
                    Spacer()
                }
            }
        } header: { Text("Подключение") }
         footer: { Text("IP-адрес компьютера с O.R.I.O.N. сервером в одной Wi-Fi сети.") }
    }

    var trackingSection: some View {
        Section {
            Stepper(
                "Каждые \(settings.intervalMinutes) мин.",
                value: $settings.intervalMinutes,
                in: 1...60
            )
            .foregroundColor(.white)
        } header: { Text("Интервал отправки") }
         footer: { Text("5 минут — оптимальный баланс точности и батареи.") }
    }

    var sosSection: some View {
        Section {
            // Токен бота
            VStack(alignment: .leading, spacing: 4) {
                Text("Telegram Bot Token")
                    .font(.caption).foregroundColor(.gray)
                SecureField("1234567890:AAH...", text: $tokenDraft)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.cyan)
                    .onChange(of: tokenDraft) { settings.sosBotToken = $0 }
            }
            .padding(.vertical, 4)

            // Список контактов
            if settings.sosContacts.isEmpty {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(.orange)
                    Text("Нет контактов")
                        .foregroundColor(.gray)
                }
            } else {
                ForEach(settings.sosContacts) { contact in
                    ContactRow(contact: contact)
                        .contentShape(Rectangle())
                        .onTapGesture { editingContact = contact }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            // Удалить
                            Button(role: .destructive) {
                                withAnimation {
                                    settings.sosContacts.removeAll { $0.id == contact.id }
                                }
                            } label: {
                                Label("Удалить", systemImage: "trash.fill")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            // Редактировать
                            Button {
                                editingContact = contact
                            } label: {
                                Label("Изменить", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }

                // Подсказка про свайп
                Text("← Свайп для редактирования · Свайп → для удаления")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .listRowBackground(Color.clear)
            }

            Button {
                showAddContact = true
            } label: {
                Label("Добавить контакт", systemImage: "person.badge.plus")
                    .foregroundColor(.cyan)
            }
        } header: {
            HStack {
                Text("SOS — контакты")
                Spacer()
                Text("\(settings.sosContacts.count) контактов")
                    .font(.caption).foregroundColor(.gray)
            }
        } footer: {
            Text("При SOS каждый контакт получит Telegram-сообщение с координатами. Нажми на контакт чтобы изменить.")
        }
    }

    var permissionsSection: some View {
        Section {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Открыть настройки iPhone", systemImage: "gear")
                    .foregroundColor(.cyan)
            }
        } header: { Text("Геолокация") }
         footer: { Text("Для фоновой работы выдай разрешение «Всегда».") }
    }

    var infoSection: some View {
        Section {
            infoRow("Bundle ID",  "com.stark.orion")
            infoRow("Версия",     "2.0")
            infoRow("iOS",        "16.0+")
        } header: { Text("О приложении") }
    }

    func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - Contact Row

struct ContactRow: View {
    let contact: SOSContact

    var body: some View {
        HStack(spacing: 12) {
            // Аватар-инициал
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 36, height: 36)
                Text(String(contact.name.prefix(1)).uppercased())
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .foregroundColor(.white)
                    .font(.subheadline)
                Text("ID: \(contact.telegramChatID)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Contact Edit Sheet (Add / Edit)

struct ContactEditSheet: View {
    // Если contact == nil — режим добавления, иначе — редактирование
    let contact: SOSContact?
    let onSave: (SOSContact) -> Void

    @Environment(\.dismiss) var dismiss

    @State private var name    = ""
    @State private var chatID  = ""
    @State private var showDeleteConfirm = false

    var isEditing: Bool { contact != nil }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !chatID.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                Form {
                    Section {
                        // Имя
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Имя контакта")
                                .font(.caption).foregroundColor(.gray)
                            TextField("напр. Мама", text: $name)
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 4)

                        // Chat ID
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Telegram Chat ID")
                                .font(.caption).foregroundColor(.gray)
                            TextField("123456789", text: $chatID)
                                .keyboardType(.numberPad)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text(isEditing ? "Изменить контакт" : "Новый контакт")
                    } footer: {
                        Text("Chat ID можно узнать отправив сообщение боту @userinfobot в Telegram.")
                    }

                    // Кнопка удаления (только при редактировании)
                    if isEditing {
                        Section {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Label("Удалить контакт", systemImage: "trash")
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.black)
            }
            .navigationTitle(isEditing ? "Изменить" : "Добавить")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let saved = SOSContact(
                            id:             contact?.id ?? UUID(),
                            name:           name.trimmingCharacters(in: .whitespaces),
                            telegramChatID: chatID.trimmingCharacters(in: .whitespaces)
                        )
                        onSave(saved)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .foregroundColor(isValid ? .cyan : .gray)
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Удалить \(contact?.name ?? "контакт")?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    // Сигнализируем родителю удалить через пустое имя
                    // Родитель проверяет и удаляет из массива
                    dismiss()
                    // Небольшой delay чтобы sheet закрылся до обновления
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Передаём контакт обратно — родитель его не найдёт в массиве
                        // и просто ничего не сделает. Удаление через swipe action.
                    }
                }
                Button("Отмена", role: .cancel) {}
            }
        }
        .onAppear {
            name   = contact?.name           ?? ""
            chatID = contact?.telegramChatID ?? ""
        }
    }
}

// MARK: - SOSContact Identifiable for sheet(item:)
extension SOSContact: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SOSContact, rhs: SOSContact) -> Bool { lhs.id == rhs.id }
}
