import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CreatePollView: View {
    let partyId: String
    @Environment(\.dismiss) private var dismiss

    // Config
    private let maxOptions = 12  // cap total options

    // Form fields
    @State private var question: String = ""
    @State private var type: PollType = .single
    @State private var allowGuestOptions: Bool = false
    @State private var deadlineOn: Bool = false
    @State private var deadlineAt: Date = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()

    // Build options BEFORE saving
    @State private var draftOptions: [String] = ["", ""] // at least two text fields visible
    @State private var newOptionText: String = ""
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

            Section(footer:
                Text("Add 2 to \(maxOptions) options.").font(.footnote).foregroundStyle(.secondary)
            ) {
                ForEach(draftOptions.indices, id: \.self) { i in
                    HStack {
                        if type == .ranked {
                            Text("\(i + 1).")
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .trailing)
                        }
                        TextField("Option \(i + 1)", text: Binding(
                            get: { draftOptions[i] },
                            set: { draftOptions[i] = $0 }
                        ))
                        .textInputAutocapitalization(.sentences)
                    }
                }
                .onDelete { idx in draftOptions.remove(atOffsets: idx) }

                HStack {
                    TextField("Add an option", text: $newOptionText)
                        .textInputAutocapitalization(.sentences)
                    Button("Add") {
                        let t = newOptionText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        guard cleanedOptions.count < maxOptions else { return }
                        draftOptions.append(t)
                        newOptionText = ""
                    }
                    .disabled(newOptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || cleanedOptions.count >= maxOptions)
                }
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
    }

    private var cleanedOptions: [String] {
        draftOptions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // ✅ Allow 2+ options for ALL types
    private var canSave: Bool {
        let qOK = !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let count = cleanedOptions.count
        return qOK && count >= 2 && count <= maxOptions
    }

    private func save() {
        guard canSave, let uid = Auth.auth().currentUser?.uid else { return }
        isSaving = true
        errorText = nil

        let db = Firestore.firestore()
        let pollRef = db.collection("parties").document(partyId).collection("polls").document()

        let pollData: [String: Any] = [
            "partyId": partyId, // keep consistent for fallback query
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
                "rank": idx // also used as initial display order for ranked
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
