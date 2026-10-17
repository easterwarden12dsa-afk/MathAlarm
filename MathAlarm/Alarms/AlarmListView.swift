import SwiftUI
import AlarmKit

struct AlarmListView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var ring: RingCoordinator

    @State private var editing: EditorTarget?
    @State private var testMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if ExpiryMonitor.shouldWarn, let expiry = ExpiryMonitor.expirationDate {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Reinstall soon", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                                .foregroundStyle(.yellow)
                            Text("This free install stops working \(expiry.formatted(.relative(presentation: .named))) (\(expiry.formatted(date: .abbreviated, time: .shortened))). Reinstall with iloader before then, or alarms may not ring.")
                                .font(.subheadline)
                        }
                    }
                }

                if store.authorization != .authorized {
                    Section { permissionWarning }
                }

                if let error = store.lastError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .onTapGesture { store.lastError = nil }
                    }
                }

                Section {
                    Button {
                        Haptics.tap()
                        Task {
                            let ok = await ring.scheduleTestRing()
                            testMessage = ok
                                ? "Test alarm rings in 10 seconds. Lock your phone to see the real thing."
                                : "Couldn't schedule the test alarm. Check that alarms are allowed."
                        }
                    } label: {
                        Label("Ring in 10 seconds", systemImage: "timer")
                            .font(.headline)
                    }
                    .buttonStyle(PressableStyle(scale: 0.96))
                    if let testMessage {
                        Text(testMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("Alarms") {
                    if store.alarms.isEmpty {
                        Text("No alarms yet. Tap + to add one.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.alarms) { item in
                        AlarmRow(item: item) { enabled in
                            Task { await store.setEnabled(id: item.id, enabled) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editing = EditorTarget(item: item, isNew: false) }
                    }
                    .onDelete { store.delete(at: $0) }
                }
            }
            .navigationTitle("Math Alarm")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        editing = EditorTarget(item: AlarmItem(), isNew: true)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add alarm")
                }
            }
            .sheet(item: $editing) { target in
                AlarmEditView(draft: target.item, isNew: target.isNew)
                    .environmentObject(store)
                    .environmentObject(ring)
            }
        }
    }

    private var permissionWarning: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Alarms aren't allowed", systemImage: "bell.slash.fill")
                .font(.headline)
                .foregroundStyle(.red)
            Text("Without permission nothing will ring.")
                .font(.subheadline)
            HStack {
                Button("Allow") { Task { await store.requestAuthorization() } }
                    .buttonStyle(.borderedProminent)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct EditorTarget: Identifiable {
    var item: AlarmItem
    var isNew: Bool
    var id: UUID { item.id }
}

struct AlarmRow: View {
    let item: AlarmItem
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.headlineTime)
                    .font(.system(size: 44, weight: .light, design: .rounded))
                    .monospacedDigit()
                Text(item.label.isEmpty ? "Alarm" : item.label)
                    .font(.headline)
                Text("\(item.repeatSummary) · \(item.challenge.title) · \(item.difficulty.title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if item.isEnabled, let next = item.nextFireDate() {
                    Text("Next: \(next.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(item.isEnabled ? 1 : 0.45)
            Spacer()
            Toggle("", isOn: Binding(get: { item.isEnabled }, set: onToggle))
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}
