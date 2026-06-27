import SwiftData
import SwiftUI

struct ProfileView: View {
    @Bindable var coordinator: AuthCoordinator
    @Environment(\.modelContext) private var modelContext
    @Environment(ProfilePreferences.self) private var preferences
    @State private var viewModel: ProfileViewModel?
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    statsRow
                    memoriesLink
                    if let vm = viewModel {
                        sectionList(vm)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(coordinator: coordinator)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit") { showEditor = true }
                }
            }
            .task {
                if viewModel == nil { viewModel = ProfileViewModel(container: modelContext.container) }
                await viewModel?.load()
            }
            .refreshable { await viewModel?.load() }
            .sheet(isPresented: $showEditor) {
                EditProfileSheet(coordinator: coordinator)
            }
        }
    }

    private var memoriesLink: some View {
        NavigationLink {
            MemoriesView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "book.closed.fill").foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Memories").font(.subheadline.weight(.semibold))
                    Text("Your reflections — on this day & recent")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        VStack(spacing: 12) {
            AvatarView(data: preferences.avatarData, name: resolvedDisplayName, size: 88)
            Text(resolvedDisplayName)
                .font(.title2.bold())
            if let email = coordinator.email {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 12)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(value: "\(viewModel?.streakDays ?? 0)", label: "Day streak", systemImage: "flame.fill", tint: .orange)
            statCard(value: "\(viewModel?.milestonesCompleted ?? 0)", label: "Milestones", systemImage: "checkmark.seal.fill", tint: .green)
        }
    }

    private func statCard(value: String, label: String, systemImage: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage).foregroundStyle(tint)
            Text(value).font(.title3.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func sectionList(_ vm: ProfileViewModel) -> some View {
        VStack(spacing: 16) {
            sectionHeader("Today", count: vm.todayHabitsCount)
            sectionHeader("Active projects", count: vm.activeProjects.count)
            ForEach(vm.activeProjects) { project in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.title).font(.subheadline)
                        ProgressView(value: project.progress)
                    }
                    Spacer()
                    Text("\(Int(project.progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var resolvedDisplayName: String {
        let name = preferences.displayName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return name }
        if let email = coordinator.email, let prefix = email.split(separator: "@").first {
            return String(prefix)
        }
        if let id = coordinator.state.userID {
            return "User \(id.uuidString.prefix(4))"
        }
        return "Anonymous"
    }
}

/// Renders a circular avatar from raw image data when present, falling back to
/// initials over a deterministic palette color.
struct AvatarView: View {
    let data: Data?
    let name: String
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            if let data, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle().fill(avatarColor).frame(width: size, height: size)
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        let chars = parts.prefix(2).compactMap { $0.first }.map { String($0) }.joined()
        return chars.isEmpty ? "?" : chars.uppercased()
    }

    private var avatarColor: Color {
        let palette: [Color] = [.indigo, .pink, .teal, .orange, .purple, .blue]
        let seed = name.utf8.reduce(0) { Int($0) &+ Int($1) }
        return palette[seed % palette.count]
    }
}
