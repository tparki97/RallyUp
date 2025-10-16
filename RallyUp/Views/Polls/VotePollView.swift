import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct VotePollView: View {
    private let partyId: String
    private let pollId: String
    @StateObject private var vm: VoteViewModel

    @State private var newOptionText: String = ""

    init(partyId: String, pollId: String) {
        self.partyId = partyId
        self.pollId = pollId
        _vm = StateObject(wrappedValue: VoteViewModel(partyId: partyId, pollId: pollId))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                switch vm.pollKind {
                case .ranked: rankedContent
                case .single, .multiple: choiceContent
                }

                submitButton

                resultsSection

                ownerControls
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .navigationTitle("Vote")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var header: some View {
        Text(vm.question)
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var rankedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Drag to rank (top = best)")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Reorderable list with ONLY the right drag handle
            List {
                ForEach(vm.rankedOrder) { opt in
                    HStack {
                        Text(opt.text)
                        Spacer()
                        Image(systemName: "line.3.horizontal") // one handle at right
                            .opacity(0.35)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .onMove(perform: vm.moveRanked(from:to:))
            }
            .environment(\.editMode, .constant(.active))
            .frame(minHeight: CGFloat(max(1, vm.options.count)) * 56, maxHeight: 360)
            .listStyle(.plain)
            .scrollDisabled(true)

            if vm.allowGuestOptions && !vm.isClosed {
                HStack {
                    TextField("Add an option", text: $newOptionText)
                    Button("Add") {
                        Task {
                            let t = newOptionText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !t.isEmpty {
                                try? await vm.addGuestOption(text: t)
                                newOptionText = ""
                            }
                        }
                    }.disabled(newOptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var choiceContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(vm.options) { opt in
                Button {
                    vm.toggleSelect(opt.id)
                } label: {
                    HStack {
                        Text(opt.text)
                            .foregroundStyle(.primary)
                        Spacer()
                        if vm.pollKind == .single {
                            Image(systemName: vm.selectedOptionIds.contains(opt.id) ? "largecircle.fill.circle" : "circle")
                                .imageScale(.large)
                                .foregroundStyle(vm.selectedOptionIds.contains(opt.id) ? Theme.teal : .secondary)
                        } else {
                            Image(systemName: vm.selectedOptionIds.contains(opt.id) ? "checkmark.square.fill" : "square")
                                .imageScale(.large)
                                .foregroundStyle(vm.selectedOptionIds.contains(opt.id) ? Theme.teal : .secondary)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }

            if vm.allowGuestOptions && !vm.isClosed {
                HStack {
                    TextField("Add an option", text: $newOptionText)
                    Button("Add") {
                        Task {
                            let t = newOptionText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !t.isEmpty {
                                try? await vm.addGuestOption(text: t)
                                newOptionText = ""
                            }
                        }
                    }.disabled(newOptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var submitButton: some View {
        Button {
            Task { try? await vm.submitVote() }
        } label: {
            Text("Submit Vote")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.teal)
        .disabled(!vm.canSubmit)
        .padding(.top, 4)
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Results")
                .font(.headline)

            if vm.shouldShowResults {
                ForEach(vm.options) { opt in
                    let raw = vm.percent(for: opt.id)
                    let frac = raw.isFinite ? max(0, min(1, raw)) : 0
                    let pct = Int((frac * 100).rounded())

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(opt.text).font(.subheadline.weight(.semibold))
                            Spacer()
                            if vm.pollKind == .ranked {
                                let score = vm.score(for: opt.id)
                                Text("\(Int(score)) • \(pct)%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                let c = vm.count(for: opt.id)
                                Text("\(c) • \(pct)%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        BarMeter(fraction: frac)
                            .frame(height: 10)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                if vm.pollKind == .ranked {
                    Text("Ranked results use Borda scoring.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            } else {
                Text("Results are hidden until you vote or the poll closes.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding(.vertical, 8)
            }
        }
        .padding(.top, 8)
    }

    private var ownerControls: some View {
        Group {
            if vm.isCreator {
                VStack(alignment: .leading, spacing: 8) {
                    Divider().padding(.vertical, 8)
                    Text("Owner Controls").font(.subheadline.weight(.semibold))
                    Button(vm.isLocked ? "Unlock Poll" : "Lock Poll") {
                        Task { await vm.toggleLock() }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
