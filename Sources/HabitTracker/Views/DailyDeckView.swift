import SwiftData
import SwiftUI

struct DailyDeckView: View {
    @Bindable var viewModel: DailyDeckViewModel
    @Binding var focusedHabitID: UUID?
    @Environment(\.modelContext) private var modelContext
    @State var session: ActiveHabitSession = ActiveHabitSession(
        controller: ActivityKitLiveActivityController()
    )
    @State private var habitEditor: HabitEditorViewModel?
    @State private var showInjector: Bool = false
    @State private var ingestion: IngestionViewModel?
    @State private var collapseUpNext = false
    @State private var collapseCompleted = false
    @State private var repeatCandidate: DailySession?
    /// The Up-next habit the user tapped play on while another is still running.
    @State private var switchCandidate: DailySession?
    /// The Up-next habit the user tapped done on — confirm they really did it
    /// before logging its estimate into the budget.
    @State private var completeCandidate: DailySession?
    private let backgroundStore = CardBackgroundStore()
    @State private var cardBackground: CardBackground = CardBackgroundStore().current
    @State private var showBackgroundPicker = false

    init(viewModel: DailyDeckViewModel, focusedHabitID: Binding<UUID?> = .constant(nil)) {
        self.viewModel = viewModel
        self._focusedHabitID = focusedHabitID
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.sessions.isEmpty {
                    emptyState
                } else {
                    deckList
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !viewModel.sessions.isEmpty { floatingAddMenu }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { brandHeader }
            }
            .task {
                SessionGenerator.generate(in: modelContext)
                await viewModel.load()
            }
            .sheet(item: $habitEditor, onDismiss: {
                SessionGenerator.generate(in: modelContext)
                Task { await viewModel.load() }
            }) { vm in HabitEditorSheet(viewModel: vm) }
            .sheet(isPresented: $showInjector) {
                InterruptionInjectorSheet { title, energy, minutes in
                    await viewModel.injectInterruption(title: title, energy: energy, expectedMinutes: minutes)
                }
            }
            .sheet(item: $ingestion, onDismiss: {
                SessionGenerator.generate(in: modelContext)
                Task { await viewModel.load() }
            }) { vm in IngestionSheet(viewModel: vm) }
            .sheet(isPresented: $showBackgroundPicker) {
                BackgroundPickerSheet(current: cardBackground) { picked in
                    cardBackground = picked
                    backgroundStore.save(picked)
                }
            }
        }
    }

    private var deckList: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    budgetCard
                }
                .listRowBackground(budgetCardBackground)
                .listRowSeparator(.hidden)

                // Going on — the single in-progress habit. Never collapsible.
                if !viewModel.goingOnSessions.isEmpty {
                    Section {
                        ForEach(viewModel.goingOnSessions) { s in sessionRow(s) }
                    } header: { Text("Going on") }
                }

                // Up next — reorderable, collapsible.
                if !viewModel.upNextSessions.isEmpty {
                    Section {
                        if !collapseUpNext {
                            ForEach(viewModel.upNextSessions) { s in sessionRow(s) }
                                .onMove { source, destination in
                                    Task { await viewModel.move(from: source, to: destination) }
                                }
                        }
                    } header: {
                        collapseHeader("Up next", count: viewModel.upNextSessions.count, isCollapsed: $collapseUpNext)
                    }
                }

                if !viewModel.completedSessions.isEmpty {
                    Section {
                        if !collapseCompleted {
                            ForEach(viewModel.completedSessions) { s in sessionRow(s) }
                        }
                    } header: {
                        collapseHeader("Completed", count: viewModel.completedSessions.count, isCollapsed: $collapseCompleted)
                    }
                }
            }
            .onChange(of: focusedHabitID) { _, newValue in
                guard let id = newValue,
                      let target = viewModel.sessions.first(where: { $0.habit?.id == id }) else { return }
                withAnimation { proxy.scrollTo(target.id, anchor: .center) }
            }
            .alert(
                "Do \(repeatCandidate?.habit?.title ?? "this") again?",
                isPresented: repeatDialogBinding,
                presenting: repeatCandidate
            ) { candidate in
                Button("Do it again") { Task { await repeatSession(candidate) } }
                Button("Cancel", role: .cancel) { repeatCandidate = nil }
            } message: { _ in
                Text("You've already done enough of this today. This adds another fresh run.")
            }
            .alert(
                "Finish \(runningTitle) first?",
                isPresented: switchDialogBinding,
                presenting: switchCandidate
            ) { next in
                Button("Complete & start") { Task { await confirmSwitch(to: next) } }
                Button("Cancel", role: .cancel) { switchCandidate = nil }
            } message: { next in
                Text("\(runningTitle) is still running. Completing it now logs the \(runningElapsed) min you've spent, then starts \(next.habit?.title ?? "the next habit").")
            }
            .alert(
                "Did you do \(completeCandidate?.habit?.title ?? "this")?",
                isPresented: completeDialogBinding,
                presenting: completeCandidate
            ) { candidate in
                Button("Yes, I did it") { Task { await confirmComplete(candidate) } }
                Button("Cancel", role: .cancel) { completeCandidate = nil }
            } message: { candidate in
                Text("This logs \(candidate.compressedMinutes) min toward today's budget.")
            }
        }
    }

    private var completeDialogBinding: Binding<Bool> {
        Binding(get: { completeCandidate != nil }, set: { if !$0 { completeCandidate = nil } })
    }

    private var repeatDialogBinding: Binding<Bool> {
        Binding(get: { repeatCandidate != nil }, set: { if !$0 { repeatCandidate = nil } })
    }

    private var switchDialogBinding: Binding<Bool> {
        Binding(get: { switchCandidate != nil }, set: { if !$0 { switchCandidate = nil } })
    }

    /// Title + elapsed of the habit currently running, for the switch alert copy.
    private var runningTitle: String { viewModel.goingOnSessions.first?.habit?.title ?? "the current habit" }
    private var runningElapsed: Int { max(1, session.elapsedMinutes()) }

    private func collapseHeader(_ title: String, count: Int, isCollapsed: Binding<Bool>) -> some View {
        Button {
            withAnimation(.snappy) { isCollapsed.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                Text("(\(count))").monospacedDigit().foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tint)
                    .rotationEffect(.degrees(isCollapsed.wrappedValue ? 0 : 90))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sessionRow(_ s: DailySession) -> some View {
        let active = session.activeSessionID == s.id
        return SessionCardView(
            session: s,
            isExtraRun: viewModel.extraRunSessionIDs.contains(s.id),
            isRunning: active,
            isPaused: active && session.isPaused,
            runningStartedAt: active ? session.startedAt : nil,
            runningPausedAt: active ? session.pausedAt : nil,
            runningBudgetMinutes: active ? session.budgetMinutes : 0,
            onToggleSession: {
                Task { await toggleSession(s) }
            },
            onStop: {
                Task { await stopSession(s) }
            },
            onComplete: {
                Task { await completeSession(s) }
            },
            onResume: {
                Task { await resumeSession(s) }
            }
        )
        .id(s.id)
        .contentShape(Rectangle())
        .swipeActions {
            Button(role: .destructive) {
                Task { await stopIfRunning(s); await viewModel.delete(s) }
            } label: { Label("Delete", systemImage: "trash") }
            if s.status == .pending, s.habit != nil {
                Button { editHabit(s) } label: { Label("Edit", systemImage: "pencil") }
                    .tint(.blue)
            }
            if s.status == .completed, s.habit != nil {
                Button { repeatCandidate = s } label: { Label("Repeat", systemImage: "arrow.clockwise") }
                    .tint(.indigo)
            }
        }
    }

    private func editHabit(_ s: DailySession) {
        guard let habit = s.habit else { return }
        habitEditor = HabitEditorViewModel(mode: .edit(habit: habit), repository: repository())
    }

    /// Resume a completed-but-under-target session, continuing from the minutes
    /// it already logged. Starts it now if nothing's running, else queues it.
    private func resumeSession(_ s: DailySession) async {
        guard let habit = s.habit else { return }
        if session.isRunning {
            await viewModel.reopen(s, active: false)
        } else {
            await session.start(habit: habit, sessionID: s.id, budgetMinutes: s.compressedMinutes, resumingFromMinutes: s.actualMinutes ?? 0)
            await viewModel.reopen(s, active: true)
        }
    }

    /// Clone a fresh run of an already-finished habit. Starts immediately when
    /// nothing is running ("Going on"), otherwise drops it into "Up next".
    private func repeatSession(_ s: DailySession) async {
        repeatCandidate = nil
        guard let clone = await viewModel.repeatHabit(s), let habit = clone.habit else { return }
        if !session.isRunning {
            await session.start(habit: habit, sessionID: clone.id, budgetMinutes: clone.compressedMinutes)
            await viewModel.markActive(clone)
        }
    }

    /// Play/pause toggle. If a *different* habit is already running, ask the user
    /// to finish it first (so its time gets logged) rather than silently dropping
    /// it. The done checkbox is the only auto-complete path.
    private func toggleSession(_ s: DailySession) async {
        guard let habit = s.habit else { return }
        if session.activeSessionID == s.id {
            Haptics.tap()
            if session.isPaused { await session.resume() } else { await session.pause() }
        } else if session.isRunning {
            switchCandidate = s
        } else {
            Haptics.tap()
            await session.start(habit: habit, sessionID: s.id, budgetMinutes: s.compressedMinutes)
            await viewModel.markActive(s)
        }
    }

    /// Confirmed from the switch alert: complete the running habit (logging the
    /// time actually spent — it was really done), then start the chosen one.
    private func confirmSwitch(to next: DailySession) async {
        switchCandidate = nil
        guard let habit = next.habit else { return }
        if let running = viewModel.goingOnSessions.first(where: { $0.id == session.activeSessionID }) {
            let minutes = session.elapsedMinutes()
            await session.stop()
            await viewModel.switchActive(from: running, loggedMinutes: minutes, to: next)
        } else {
            await viewModel.markActive(next)
        }
        Haptics.tap()
        await session.start(habit: habit, sessionID: next.id, budgetMinutes: next.compressedMinutes)
    }

    /// Stop = end early but keep the record. Logs the elapsed minutes and marks
    /// the session completed-but-stopped-early (scored proportionally), then
    /// tears down the Live Activity + ring.
    private func stopSession(_ s: DailySession) async {
        let minutes: Int
        if session.activeSessionID == s.id {
            minutes = max(0, session.elapsedMinutes())
            await session.stop()
        } else {
            minutes = 0
        }
        Haptics.tap()
        await viewModel.complete(s, actualMinutes: minutes, stoppedEarly: true)
    }

    /// Completes a session. The running one logs its actual elapsed and tears
    /// down the Live Activity + ring. An Up-next habit (no timer) instead asks
    /// the user to confirm they really did it before its estimate hits the budget.
    private func completeSession(_ s: DailySession) async {
        if session.activeSessionID == s.id {
            let minutes = max(1, session.elapsedMinutes())
            await session.stop()
            Haptics.success()
            await viewModel.complete(s, actualMinutes: minutes)
        } else {
            completeCandidate = s
        }
    }

    /// Confirmed from the "Did you do this?" alert: log the Up-next habit's
    /// planned minutes into the budget as a full completion.
    private func confirmComplete(_ s: DailySession) async {
        completeCandidate = nil
        Haptics.success()
        await viewModel.completeAsPlanned(s)
    }

    private func stopIfRunning(_ s: DailySession) async {
        if session.activeSessionID == s.id { await session.stop() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your deck is empty", systemImage: "rectangle.stack")
        } description: {
            Text("Add a habit to start budgeting your day.")
        } actions: {
            Button("Add your first habit") { startAddHabit() }
                .buttonStyle(.borderedProminent)
        }
    }

    private func startIngestion() {
        let service: any TaskIngestService = (try? SupabaseConfig.fromBundle()).map { SupabaseTaskIngestService(config: $0) } ?? MockTaskIngestService()
        ingestion = IngestionViewModel(service: service, container: modelContext.container)
    }

    private func startAddHabit() {
        habitEditor = HabitEditorViewModel(mode: .create, repository: repository())
    }

    /// Brand lockup shown in the nav bar in place of a plain "Today" title:
    /// an accent app mark + the "WillPower" wordmark.
    private var brandHeader: some View {
        HStack(spacing: 7) {
            Image(systemName: "flame.fill")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 7))
            Text("Will Power")
                .font(.headline.weight(.bold))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Will Power")
    }

    /// Floating "+" action menu (bottom-right, above the tab bar) — the single
    /// entry point for injecting an interruption, brain-dumping, or adding a habit.
    private var floatingAddMenu: some View {
        Menu {
            Button("Inject interruption", systemImage: "bolt.fill") { showInjector = true }
            Button("Brain dump", systemImage: "sparkles") { startIngestion() }
            Button("Add habit", systemImage: "plus.circle") { startAddHabit() }
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor, in: Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 16)
        .accessibilityLabel("Add")
    }

    /// The hero "Today's budget" card: time spent today (only grows) — logged
    /// minutes from completed sessions plus live elapsed of whatever is running —
    /// with the planned remainder alongside. Background is swappable (see 2c).
    private var budgetCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let live = session.isRunning ? session.elapsedMinutes() : 0
            let onImage = cardBackground.isImage
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Today's budget")
                        .font(.title2.bold())
                        .foregroundStyle(onImage ? .white : .primary)
                    Spacer()
                    Button { showBackgroundPicker = true } label: {
                        Image(systemName: "paintbrush.fill")
                            .font(.subheadline)
                            .foregroundStyle(onImage ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Change card background")
                }
                spentBar(
                    spent: viewModel.budget.spentMinutes + live,
                    available: viewModel.budget.availableMinutes,
                    planned: viewModel.budget.plannedMinutes,
                    onImage: onImage
                )
            }
            // Extra vertical breathing room (~20% taller than the default row)
            // for the hero card; horizontal sizing is left to the default row
            // insets so it lines up exactly with the Up-next section below.
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Backing fill for the budget card — honors the user's choice (QA 2c):
    /// neutral surface, a solid color, a Supabase stock image, or a local upload.
    /// Image cases get a legibility scrim so the white text stays readable.
    @ViewBuilder private var budgetCardBackground: some View {
        switch cardBackground {
        case .surface:
            Color(.secondarySystemBackground)
        case .solid(let hex):
            Color(hex: hex) ?? Color(.secondarySystemBackground)
        case .remote(let path):
            imageBackground(AnyView(
                AsyncImage(url: CardBackground.publicStorageURL(path: path)) { img in
                    img.resizable().scaledToFill()
                } placeholder: { Color(.secondarySystemBackground) }
            ))
        case .local(let filename):
            imageBackground(AnyView(localImage(filename)))
        }
    }

    @ViewBuilder private func localImage(_ filename: String) -> some View {
        if let data = LocalImageStore().load(filename), let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            Color(.secondarySystemBackground)
        }
    }

    private func imageBackground(_ image: AnyView) -> some View {
        ZStack {
            image
            Color.black.opacity(0.45) // scrim for white-text legibility
        }
    }

    private func spentBar(spent: Int, available: Int, planned: Int, onImage: Bool = false) -> some View {
        let over = spent > available
        let primary: Color = onImage ? .white : .primary
        let secondary: Color = onImage ? .white.opacity(0.85) : .secondary
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(spent)").font(.title3.bold()).monospacedDigit().foregroundColor(primary)
                + Text(" of \(available) min spent").font(.subheadline).foregroundColor(secondary)
                Spacer()
                Text(over ? "Over by \(spent - available) min" : "\(planned) min to go")
                    .font(.caption)
                    .foregroundStyle(over ? Color.red : secondary)
            }
            progressBar(
                fraction: BudgetSnapshot.fraction(spent: spent, available: available),
                over: over,
                onImage: onImage
            )
        }
    }

    /// Capsule progress bar. Custom (vs. `ProgressView`) so the unfilled track
    /// stays visible against an image background, where the system track washes
    /// out into the scrim.
    private func progressBar(fraction: Double, over: Bool, onImage: Bool) -> some View {
        let track: Color = onImage ? .white.opacity(0.35) : Color(.systemGray5)
        let fill: Color = over ? .red : (onImage ? .white : .accentColor)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(fill)
                    .frame(width: max(0, geo.size.width * fraction))
            }
        }
        .frame(height: 6)
    }

    private func repository() -> SwiftDataRepository {
        SwiftDataRepository(container: modelContext.container)
    }
}
