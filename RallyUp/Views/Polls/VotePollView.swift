import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct VotePollView: View {
    let partyId: String
    let pollId: String

    @StateObject private var vm: VoteViewModel
    @State private var newOptionText: String = ""
    @State private var isSubmitting = false
    @State private var errorText: String?

    init(partyId: String, pollId: String) {
        self.partyId = partyId
        self.pollId = pollId
        _vm = StateObject(wrappedValue: VoteViewModel(partyId: partyId, pollId: pollId))
    }

    var body: some View {
        List {
            Section {
                Text(vm.question)
                    .font(.headline)
                    .accessibilityLabel("Poll question")
            }

            optionsSection

            if vm.allowGuestOptions && !vm.isLocked {
                Section("Add an option") {
                    HStack {
                        TextField("Your option", text: $newOptionText)
                            .textInputAutocapitalization(.sentences)
                        Button("Add") { Task { await addGuestOption() } }
                            .disabled(newOptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }

            if let deadline = vm.deadlineAt {
                Section {
                    HStack {
                        Image(systemName: "hourglass")
                        Text("Closes \(deadline.formatted(date: .abbreviated, time: .shortened))")
                    }
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                }
            }

            Section {
                Button(isSubmitting ? "Submitting…" : "Submit Vote") {
                    Task { await submit() }
                }
                .disabled(!vm.canSubmit || isSubmitting || vm.isLocked)
                .buttonStyle(.borderedProminent)
                .tint(Theme.teal)
            }

            resultsSection
        }
        .listStyle(.insetGrouped)
        // ✅ Force edit mode ON only for ranked polls (required for .onMove to show drag handles)
        .environment(\.editMode, .constant(vm.pollKind == .ranked ? EditMode.active : EditMode.inactive))
        .navigationTitle("Vote")
        .onAppear {
            Task {
                await vm.refreshHasVoted()
                await vm.refreshTallies()
            }
        }
        .alert("Error", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorText ?? "") }
    }

    // MARK: - Sections

    @ViewBuilder
    private var optionsSection: some View {
        switch vm.pollKind {
        case .single:
            Section("Choose one") {
                ForEach(vm.options) { opt in
                    Button {
                        vm.toggleSelect(opt.id)
                    } label: {
                        HStack {
                            Image(systemName: vm.selectedOptionIds.contains(opt.id) ? "largecircle.fill.circle" : "circle")
                                .imageScale(.large)
                            Text(opt.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .accessibilityLabel(opt.text)
                    .contentShape(Rectangle())
                }
            }

        case .multiple:
            Section("Choose one or more") {
                ForEach(vm.options) { opt in
                    Toggle(isOn: Binding(
                        get: { vm.selectedOptionIds.contains(opt.id) },
                        set: { _ in vm.toggleSelect(opt.id) }
                    )) {
                        Text(opt.text)
                    }
                    .accessibilityLabel(opt.text)
                }
            }

        case .ranked:
            Section("Drag to rank (top = best)") {
                // Use a stable ForEach inside the List; .onMove + edit mode shows drag handles
                ForEach(vm.rankedOrder) { opt in
                    HStack {
                        // A visible “grip” helps users discover reordering
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(opt.text)
                            .accessibilityLabel(opt.text)
                    }
                }
                .onMove(perform: moveRanked)
                .moveDisabled(false)
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if vm.shouldShowResults {
            Section("Results") {
                if vm.resultsCounts.isEmpty {
                    Text("No votes yet").foregroundStyle(.secondary)
                } else {
                    ForEach(vm.options) { opt in
                        let count = vm.resultsCounts[opt.id] ?? 0
                        let pct = vm.resultsPercentages[opt.id] ?? 0
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(opt.text)
                                Spacer()
                                Text("\(count) • \(Int(round(pct * 100)))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("\(count) votes, \(Int(round(pct * 100))) percent")
                            }
                            BarMeter(fraction: pct)
                                .frame(height: 10)
                        }
                        .padding(.vertical, 4)
                    }
                    if vm.pollKind == .ranked {
                        Text("Ranked results use Borda scoring.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            Section {
                Text("Results are hidden until you vote or the poll closes.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func moveRanked(from source: IndexSet, to destination: Int) {
        vm.rankedOrder.move(fromOffsets: source, toOffset: destination)
    }

    private func submit() async {
        isSubmitting = true
        errorText = nil
        do {
            try await vm.submitVote()
            await vm.refreshHasVoted()
            await vm.refreshTallies()
        } catch {
            errorText = error.localizedDescription
        }
        isSubmitting = false
    }

    private func addGuestOption() async {
        let t = newOptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        do {
            try await vm.addGuestOption(text: t)
            newOptionText = ""
        } catch {
            errorText = error.localizedDescription
        }
    }
}
