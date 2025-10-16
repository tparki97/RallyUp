import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CreatePollView: View {
    let partyId: String
    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var question: String = ""
    @State private var type: PollType = .single
    @State private var allowGuestOptions: Bool = false
    @State private var deadlineOn: Bool = false
    @State private var deadlineAt: Date = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()

    // Build options BEFORE saving
    // Show 3 rows by default (user can leave the 3rd blank).
    @State private var draftOptions: [String] = ["", "", ""]

    @State private var isSaving = false
    @State private var errorText: String?

    var body: some View {
        Form {
            Section(header: Text("Question")) {
                TextField("Ask something…", text: $question)
            }

            Section(header: Text("Poll Type")) {
                Picker("Type", selection: $type) {
                    Text("Single").tag(PollType.single)
                    Text("Multiple").tag(PollType.multiple)
                    Text("Ranked").tag(PollType.ranked)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Poll type")
                Toggle("Allow guests to add options", isOn: $allowGuestOptions)
            }

            Section(header: Text("Options")) {
                // Always render existing rows…
                ForEach(draftOptions.indices, id: \.self) { i in
                    TextField("Option", text: Binding(
                        get: { draftOptions[safe: i] ?? "" },
                        set: { draftOptions[safe: i] = $0 }
                    ))
                    .textInputAutocapitalization(.sentences)
                }
                .onDelete { idx in
                    draftOptions.remove(atOffsets: idx)
                    // Keep at least 3 visible inputs for clarity
                    while draftOptions.count < 3 { draftOptions.append("") }
                }

                // Add button reveals one more empty field each tap
                Button {
                    if draftOptions.count < 12 {
                        draftOptions.append("")
                    }
                } label: {
                    Label("Add another option", systemImage: "plus.circle")
                }
                .disabled(draftOptions.count >= 12)

                Text("Add 2 to 12 options. You can leave extra fields blank.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Deadline (optional)")) {
                Toggle("Has deadline", isOn: $deadlineOn)
                if deadlineOn {
                    DatePicker("Closes", selection: $deadlineAt, displayedComponents: [.date, .hourAndMinute])
                }
            }

            if let errorText {
                Text(errorText).foregroundStyle(.red).font(.footnote)
            }

            Button(isSaving ? "Saving…" : "Create Poll", action: save)
                .disabled(!canSave || isSaving)
        }
        .navigationTitle("Create Poll")
        .onAppear {
            // Safety: ensure we always show at least 3 visible rows
            while draftOptions.count < 3 { draftOptions.append("") }
        }
    }

    // Keep only trimmed, non-empty text, cap at 12
    private var cleanedOptions: [String] {
        draftOptions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(12)
            .map { String($0) }
    }

    private var canSave: Bool {
        let qOK = !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let count = cleanedOptions.count
        // Allow creation with as few as 2 options for ALL types.
        return qOK && count >= 2
    }

    private func save() {
        guard canSave, let uid = Auth.auth().currentUser?.uid else { return }
        isSaving = true
        errorText = nil

        let db = Firestore.firestore()
        let pollRef = db.collection("parties").document(partyId).collection("polls").document()

        let pollData: [String: Any] = [
            "type": type.rawValue,
            "question": question,
            "allowGuestOptions": allowGuestOptions,
            "isLocked": false,
            "deadlineAt": deadlineOn ? Timestamp(date: deadlineAt) : NSNull(),
            "createdBy": uid,
            "createdAt": Timestamp(date: Date())
        ]

        let batch = db.batch()
        batch.setData(pollData, forDocument: pollRef)

        let opts = cleanedOptions
        for (idx, text) in opts.enumerated() {
            let optRef = pollRef.collection("options").document()
            batch.setData([
                "text": text,
                "createdBy": uid,
                "createdAt": Timestamp(date: Date()),
                "rank": idx     // initial display order for ranked
            ], forDocument: optRef)
        }

        batch.commit { err in
            isSaving = false
            if let err {
                errorText = err.localizedDescription
            } else {
                dismiss()
            }
        }
    }
}

// Safe index subscript to avoid index warnings in bindings
private extension Array {
    subscript(safe index: Index) -> Element? {
        get { indices.contains(index) ? self[index] : nil }
        set {
            if let newValue, indices.contains(index) {
                self[index] = newValue
            }
        }
    }
}
