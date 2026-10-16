import SwiftUI

struct AlarmEditView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var ring: RingCoordinator
    @Environment(\.dismiss) private var dismiss

    @State private var draft: AlarmItem
    @State private var isSaving = false
    let isNew: Bool

    init(draft: AlarmItem, isNew: Bool) {
        _draft = State(initialValue: draft)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label", text: $draft.label)
                }

                Section("Repeat") {
                    Picker("Repeat", selection: $draft.repeatMode) {
                        ForEach(RepeatMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch draft.repeatMode {
                    case .once:
                        DatePicker("Date & time", selection: onceBinding, in: Date()...,
                                   displayedComponents: [.date, .hourAndMinute])
                    case .daily:
                        DatePicker("Time", selection: timeBinding($draft.time),
                                   displayedComponents: .hourAndMinute)
                    case .weekdays:
                        ForEach($draft.weekdayTimes) { $row in
                            HStack {
                                Toggle(row.name, isOn: $row.enabled)
                                if row.enabled {
                                    DatePicker("", selection: timeBinding($row.time),
                                               displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                }
                            }
                        }
                    }
                }

                Section("Challenge") {
                    Picker("Type", selection: $draft.challenge) {
                        ForEach(ChallengeKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    Picker("Difficulty", selection: $draft.difficulty) {
                        ForEach(Difficulty.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Sound") {
                    NavigationLink {
                        SoundPickerView(selection: $draft.sound)
                            .environmentObject(ring)
                    } label: {
                        HStack {
                            Label("Sound", systemImage: "speaker.wave.3.fill")
                            Spacer()
                            Text(draft.sound.title).foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        Haptics.tap()
                        ring.sound.preview(draft.sound)
                    } label: {
                        Label("Play preview", systemImage: "play.circle.fill")
                            .font(.headline)
                    }
                    .buttonStyle(PressableStyle(scale: 0.96))
                }

                if let message = draft.validationMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.yellow)
                    }
                }

                if !isNew {
                    Section {
                        Button("Delete alarm", role: .destructive) {
                            store.delete(id: draft.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSaving = true
                        var item = draft
                        item.isEnabled = true
                        Task {
                            await store.upsert(item)
                            dismiss()
                        }
                    }
                    .bold()
                    .disabled(draft.validationMessage != nil || isSaving)
                }
            }
        }
    }

    /// Date picker value for a one-time alarm (calendar day + time).
    private var onceBinding: Binding<Date> {
        Binding(
            get: { draft.onceFireDate ?? Date().addingTimeInterval(3600) },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                draft.onceDay = DayStamp(date: newValue)
                draft.time = TimeOfDay(hour: c.hour ?? 7, minute: c.minute ?? 0)
            })
    }

    private func timeBinding(_ time: Binding<TimeOfDay>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: time.wrappedValue.hour,
                                      minute: time.wrappedValue.minute,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                time.wrappedValue = TimeOfDay(hour: c.hour ?? 7, minute: c.minute ?? 0)
            })
    }
}
