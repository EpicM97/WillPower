import PhotosUI
import SwiftUI

struct EditProfileSheet: View {
    @Bindable var coordinator: AuthCoordinator
    @Environment(ProfilePreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var dobEnabled: Bool = false
    @State private var dateOfBirth: Date = .now
    @State private var appearance: AppearancePreference = .system
    @State private var photoItem: PhotosPickerItem?

    @State private var emailDraft: String = ""
    @State private var emailStatus: String?
    @State private var emailWorking = false
    @State private var showDeleteConfirm = false
    @State private var deleting = false

    var body: some View {
        NavigationStack {
            Form {
                avatarSection
                identitySection
                accountSection
                appearanceSection
                dangerSection
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }.fontWeight(.semibold)
                }
            }
            .onAppear {
                displayName = preferences.displayName
                dobEnabled = preferences.dateOfBirth != nil
                dateOfBirth = preferences.dateOfBirth ?? defaultDOB
                appearance = preferences.appearance
                emailDraft = coordinator.email ?? ""
            }
            .alert("Delete account?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) { Task { await performDelete() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You will be signed out and local data cleared on next launch. Server-side data removal isn't wired yet — email support to fully erase.")
            }
        }
    }

    // MARK: Sections

    private var avatarSection: some View {
        Section {
            HStack {
                AvatarView(data: preferences.avatarData, name: displayName.isEmpty ? "?" : displayName, size: 72)
                VStack(alignment: .leading, spacing: 6) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Choose photo", systemImage: "photo")
                    }
                    if preferences.avatarData != nil {
                        Button(role: .destructive) {
                            preferences.avatarData = nil
                        } label: {
                            Label("Remove photo", systemImage: "trash")
                                .font(.caption)
                        }
                    }
                }
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run { preferences.avatarData = downsized(data) }
                    }
                }
            }
        } header: { Text("Avatar") }
    }

    private var identitySection: some View {
        Section {
            TextField("Username", text: $displayName)
                .textInputAutocapitalization(.words)
            Toggle("Show date of birth", isOn: $dobEnabled)
            if dobEnabled {
                DatePicker("Date of birth", selection: $dateOfBirth, in: ...Date.now, displayedComponents: .date)
            }
        } header: { Text("Identity") }
    }

    private var accountSection: some View {
        Section {
            HStack {
                Text("Current email")
                Spacer()
                Text(coordinator.email ?? "—").foregroundStyle(.secondary)
            }
            TextField("New email", text: $emailDraft)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
            Button {
                Task { await requestEmailChange() }
            } label: {
                HStack {
                    Text("Send verification to new email")
                    Spacer()
                    if emailWorking { ProgressView() }
                }
            }
            .disabled(emailWorking || !canChangeEmail)
            if let status = emailStatus {
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Account")
        } footer: {
            Text("Password and language settings are coming soon.")
        }
    }

    private var appearanceSection: some View {
        Section {
            Picker("Theme", selection: $appearance) {
                ForEach(AppearancePreference.allCases) { a in
                    Text(a.label).tag(a)
                }
            }
            .pickerStyle(.segmented)
        } header: { Text("Appearance") }
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Label("Delete account", systemImage: "person.crop.circle.badge.xmark")
                    Spacer()
                    if deleting { ProgressView() }
                }
            }
            .disabled(deleting)
        }
    }

    // MARK: Actions

    private func saveAndDismiss() {
        preferences.displayName = displayName.trimmingCharacters(in: .whitespaces)
        preferences.dateOfBirth = dobEnabled ? dateOfBirth : nil
        preferences.appearance = appearance
        dismiss()
    }

    private var canChangeEmail: Bool {
        let trimmed = emailDraft.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed != (coordinator.email ?? "")
    }

    private func requestEmailChange() async {
        emailWorking = true
        defer { emailWorking = false }
        let trimmed = emailDraft.trimmingCharacters(in: .whitespaces)
        let ok = await coordinator.requestEmailChange(to: trimmed)
        emailStatus = ok
            ? "Check \(trimmed) for a confirmation link."
            : "Couldn't request change. \(coordinator.lastError ?? "")"
    }

    private func performDelete() async {
        deleting = true
        defer { deleting = false }
        await coordinator.deleteAccount()
        preferences.reset()
        dismiss()
    }

    private var defaultDOB: Date {
        Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
    }

    /// Resize down so the avatar doesn't bloat UserDefaults. Caps the longest
    /// edge at 512px and re-encodes as JPEG quality 0.8.
    private func downsized(_ data: Data) -> Data {
        guard let img = UIImage(data: data) else { return data }
        let maxEdge: CGFloat = 512
        let scale = min(1, maxEdge / max(img.size.width, img.size.height))
        let target = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.8) ?? data
    }
}
