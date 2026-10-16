import Foundation
import SwiftUI
import UIKit
import AlarmKit

/// The list of alarms, saved as JSON on the phone, and kept in step with
/// the alarms AlarmKit has scheduled.
@MainActor
final class AlarmStore: ObservableObject {
    static let shared = AlarmStore()
    private static let fileName = "alarms.json"

    @Published private(set) var alarms: [AlarmItem]
    @Published private(set) var authorization: AlarmManager.AuthorizationState
    @Published var lastError: String?

    private var observers: [NSObjectProtocol] = []

    private init() {
        alarms = Persistence.load([AlarmItem].self, from: Self.fileName) ?? []
        authorization = AlarmScheduler.authorizationState

        // Time-zone, DST and manual clock changes: repeating alarms follow
        // local time automatically; one-time alarms are moved by resync().
        let center = NotificationCenter.default
        for name in [UIApplication.significantTimeChangeNotification,
                     Notification.Name.NSSystemTimeZoneDidChange] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in
                    await AlarmStore.shared.resync()
                }
            })
        }

        Task { [weak self] in
            for await state in AlarmManager.shared.authorizationUpdates {
                self?.authorization = state
            }
        }
    }

    // MARK: Permission

    func requestAuthorization() async {
        _ = await AlarmScheduler.requestAuthorization()
        authorization = AlarmScheduler.authorizationState
    }

    // MARK: Editing

    func upsert(_ item: AlarmItem) async {
        var item = item
        cancelSystemAlarms(of: &item)
        if item.isEnabled {
            await scheduleSystemAlarms(for: &item)
        }
        if let index = alarms.firstIndex(where: { $0.id == item.id }) {
            alarms[index] = item
        } else {
            alarms.append(item)
        }
        sortAndSave()
    }

    func delete(id: UUID) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        var item = alarms[index]
        cancelSystemAlarms(of: &item)
        alarms.remove(at: index)
        sortAndSave()
    }

    func delete(at offsets: IndexSet) {
        for id in offsets.map({ alarms[$0].id }) {
            delete(id: id)
        }
    }

    func setEnabled(id: UUID, _ enabled: Bool) async {
        guard var item = alarms.first(where: { $0.id == id }) else { return }
        item.isEnabled = enabled
        if enabled, item.repeatMode == .once, item.validationMessage != nil {
            // A one-time alarm in the past can't be re-enabled as-is: move it to the next occurrence of its time.
            let next = Calendar.current.nextDate(after: Date(),
                                                 matching: DateComponents(hour: item.time.hour, minute: item.time.minute, second: 0),
                                                 matchingPolicy: .nextTime) ?? Date()
            item.onceDay = DayStamp(date: next)
        }
        await upsert(item)
    }

    // MARK: After a ring ends

    func didResolve(itemIDs: [UUID]) async {
        for id in itemIDs {
            guard let index = alarms.firstIndex(where: { $0.id == id }) else { continue }
            if alarms[index].repeatMode == .once {
                var item = alarms[index]
                cancelSystemAlarms(of: &item)
                item.isEnabled = false
                alarms[index] = item
            }
        }
        sortAndSave()
        await resync()
    }

    // MARK: Keeping AlarmKit in sync

    /// Makes AlarmKit match the saved alarms. Runs on launch, on foreground,
    /// after each ring and on time-zone / clock changes.
    func resync() async {
        authorization = AlarmScheduler.authorizationState
        guard authorization == .authorized else { return }

        let systemAlarms = AlarmScheduler.currentAlarms()
        let liveIDs = Set(systemAlarms.map(\.id))
        let now = Date()

        for index in alarms.indices {
            var item = alarms[index]
            let original = item

            if item.isEnabled, item.repeatMode == .once {
                let stillLive = item.systemAlarmIDs.contains(where: liveIDs.contains)
                if let fire = item.onceFireDate, fire <= now, !stillLive {
                    // Already rang (or the time passed while the phone was off).
                    cancelSystemAlarms(of: &item)
                    item.isEnabled = false
                } else if item.onceFireDate != item.scheduledOnceDate || !stillLive {
                    // Time zone changed, or the system lost it: schedule again.
                    cancelSystemAlarms(of: &item)
                    await scheduleSystemAlarms(for: &item)
                }
            } else if item.isEnabled {
                let expected = AlarmScheduler.schedules(for: item).count
                let missing = item.systemAlarmIDs.count != expected
                    || item.systemAlarmIDs.contains(where: { !liveIDs.contains($0) })
                if missing {
                    cancelSystemAlarms(of: &item)
                    await scheduleSystemAlarms(for: &item)
                }
            } else if !item.systemAlarmIDs.isEmpty {
                cancelSystemAlarms(of: &item)
            }

            if item != original { alarms[index] = item }
        }

        // Remove leftovers nobody owns (e.g. from an alarm deleted while the
        // system was busy). Never touch test alarms or an active ring's safety nets.
        let owned = Set(alarms.flatMap(\.systemAlarmIDs))
        let ringActive = RingCoordinator.shared.session != nil
        for alarm in systemAlarms where alarm.state == .scheduled && !owned.contains(alarm.id) {
            let purpose = AlarmRegistry.shared.context(for: alarm.id)?.purpose
            switch purpose {
            case .test, .timer:
                continue
            case .reRing, .watchdog:
                if !ringActive { AlarmScheduler.cancel(alarm.id) }
            case .alarm, .none:
                AlarmScheduler.cancel(alarm.id)
            }
        }

        AlarmRegistry.shared.prune(keeping: Set(AlarmScheduler.currentAlarms().map(\.id)))
        sortAndSave()
    }

    // MARK: Helpers

    private func scheduleSystemAlarms(for item: inout AlarmItem) async {
        let context = RingContext(item: item)
        var ids: [UUID] = []
        for schedule in AlarmScheduler.schedules(for: item) {
            let id = UUID()
            do {
                try await AlarmScheduler.schedule(id: id, schedule: schedule, context: context)
                ids.append(id)
            } catch {
                lastError = "Couldn't schedule \"\(context.label)\": \(error.localizedDescription)"
            }
        }
        item.systemAlarmIDs = ids
        item.scheduledOnceDate = item.repeatMode == .once ? item.onceFireDate : nil
    }

    private func cancelSystemAlarms(of item: inout AlarmItem) {
        for id in item.systemAlarmIDs {
            AlarmScheduler.cancel(id)
        }
        item.systemAlarmIDs = []
        item.scheduledOnceDate = nil
    }

    private func sortAndSave() {
        alarms.sort { a, b in
            switch (a.nextFireDate(), b.nextFireDate()) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.label < b.label
            }
        }
        Persistence.save(alarms, to: Self.fileName)
    }
}
