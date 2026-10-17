import SwiftUI

struct AlarmEditView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var ring: RingCoordinator
    @Environment(\.dismiss) private var dismiss

    @State private var draft: AlarmItem
    @State private var isSaving = false
    @State private var onceInput: OnceInput = .date
    @State private var fromNowMonths = 0
    @State private var fromNowDays = 0
    @State private var fromNowHours = 8
    @State private var fromNowMinutes = 0
    let isNew: Bool

    enum OnceInput { case date, fromNow }

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
                        Picker("Set by", selection: $onceInput) {
                            Text("Date & time").tag(OnceInput.date)
                            Text("Time from now").tag(OnceInput.fromNow)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: onceInput) { _, input in if input == .fromNow { applyFromNow() } }
                        if onceInput == .date {
                            DatePicker("Date & time", selection: onceBinding, in: Date()...,
                                       displayedComponents: [.date, .hourAndMinute])
                        } else {
                            HStack(spacing: 0) {
                                fromNowWheel($fromNowMonths, 0...24, "mo")
                                fromNowWheel($fromNowDays, 0...60, "d")
                                fromNowWheel($fromNowHours, 0...23, "h")
                                fromNowWheel($fromNowMinutes, 0...59, "min")
                            }
                            .frame(height: 130)
                            if let fire = draft.onceFireDate {
                                Text("Rings \(fire.formatted(date: .complete, time: .shortened))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
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

                Section {
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
                } header: {
                    Text("Challenge")
                } footer: {
                    Text(draft.challenge.summary)
                }

                if draft.challenge == .random {
                    Section {
                        ForEach($draft.randomMix.entries) { $entry in
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle(entry.kind.title, isOn: $entry.enabled)
                                if entry.enabled {
                                    Picker("Difficulty", selection: $entry.difficulty) {
                                        Text("Alarm's").tag(Difficulty?.none)
                                        ForEach(Difficulty.allCases) { Text($0.title).tag(Difficulty?.some($0)) }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                        }
                    } header: {
                        Text("Random mix")
                    } footer: {
                        Text("Each ring picks one of the switched-on types, at its own difficulty (\"Alarm's\" uses the difficulty above).")
                    }
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

    /// One wheel of the "time from now" picker.
    private func fromNowWheel(_ value: Binding<Int>, _ range: ClosedRange<Int>, _ unit: String) -> some View {
        HStack(spacing: 1) {
            Picker(unit, selection: value) {
                ForEach(Array(range), id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
            .onChange(of: value.wrappedValue) { _, _ in applyFromNow() }
            Text(unit).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    /// "1 month 13 days 2 h from now" → the alarm's date and time.
    private func applyFromNow() {
        var comps = DateComponents()
        comps.month = fromNowMonths
        comps.day = fromNowDays
        comps.hour = fromNowHours
        comps.minute = fromNowMinutes
        guard let fire = Calendar.current.date(byAdding: comps, to: Date()) else { return }
        // Round up to the next whole minute so it's never in the past.
        let rounded = Date(timeIntervalSinceReferenceDate: (fire.timeIntervalSinceReferenceDate / 60).rounded(.up) * 60)
        let c = Calendar.current.dateComponents([.hour, .minute], from: rounded)
        draft.onceDay = DayStamp(date: rounded)
        draft.time = TimeOfDay(hour: c.hour ?? 0, minute: c.minute ?? 0)
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
