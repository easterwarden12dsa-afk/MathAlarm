import Foundation
import SwiftUI
import UIKit
import AlarmKit

/// Owns the "ring session": the alarm that is ringing and not yet solved or
/// surrendered.
///
/// How ringing stays reliable:
/// 1. AlarmKit rings the system alarm (works locked, on Silent, in Focus,
///    with the app closed). Its buttons are the system Stop plus our Solve.
/// 2. Solve opens the app. The app stops the system alarm and plays the
///    sound itself until the challenge is solved or Surrender is pressed.
/// 3. Stop can't be disabled by any app. Our Stop intent schedules a
///    re-ring `reRingDelay` seconds later, plus a backup alarm.
/// 4. While the app is ringing it keeps a "watchdog" AlarmKit alarm a little
///    in the future and keeps pushing it back. If the app is killed, the
///    watchdog fires. During Mute the watchdog is placed at the mute's end,
///    so the sound comes back even if the app is suspended.
@MainActor
final class RingCoordinator: ObservableObject {
    static let shared = RingCoordinator()

    // Tunable timings (seconds).
    static let reRingDelay: TimeInterval = 5
    static let stopBackupDelay: TimeInterval = 60
    static let watchdogLead: TimeInterval = 45
    static let watchdogRefreshInterval: TimeInterval = 15
    static let muteDuration: TimeInterval = 90
    static let foregroundMuteGrace: TimeInterval = 20
    static let vibrateInterval: TimeInterval = 2

    private static let sessionFile = "activeRing.json"

    @Published private(set) var session: RingSession?
    @Published var lastTestScheduledFor: Date?

    let sound = AlarmSoundPlayer()

    private var isForeground = false
    /// True once this process has taken over ringing in-app.
    private var inAppEngaged = false
    private var ticker: Timer?
    private var lastWatchdogRefresh = Date.distantPast
    private var lastVibrate = Date.distantPast
    private var observingAlarms = false

    private init() {
        session = Persistence.load(RingSession.self, from: Self.sessionFile)
    }

    // MARK: Startup

    func start() {
        guard !observingAlarms else { return }
        observingAlarms = true
        Task { [weak self] in
            for await alarms in AlarmManager.shared.alarmUpdates {
                self?.handleAlarmUpdates(alarms)
            }
        }
    }

    // MARK: Events from AlarmKit

    /// System Stop pressed. The intent runs even if the app was closed.
    func handleSystemStop(alarmID: UUID) async {
        if inAppEngaged && isForeground && session != nil {
            // The app is already ringing on screen; nothing to re-ring.
            return
        }
        join(alarmID: alarmID)
        guard var s = session else { return }

        if let old = s.reRingID { AlarmScheduler.cancel(old) }
        if let old = s.watchdogID { AlarmScheduler.cancel(old) }
        s.reRingID = nil
        s.watchdogID = nil
        session = s
        saveSession()

        let reRingContext = s.context(purpose: .reRing)
        let backupContext = s.context(purpose: .watchdog)
        let sessionID = s.id
        let reRing = try? await AlarmScheduler.scheduleFixed(
            at: Date().addingTimeInterval(Self.reRingDelay), context: reRingContext)
        let backup = try? await AlarmScheduler.scheduleFixed(
            at: Date().addingTimeInterval(Self.stopBackupDelay), context: backupContext)

        guard session?.id == sessionID else {
            // Resolved while we were scheduling.
            reRing.map(AlarmScheduler.cancel)
            backup.map(AlarmScheduler.cancel)
            return
        }
        session?.reRingID = reRing
        session?.watchdogID = backup
        saveSession()
    }

    /// "Solve" pressed on the system alarm; the app is being opened.
    func handleSolveButton(alarmID: UUID) {
        join(alarmID: alarmID)
        engageInApp()
        AlarmScheduler.stop(alarmID)
    }

    private func handleAlarmUpdates(_ alarms: [Alarm]) {
        let alerting = alarms.filter { $0.state == .alerting }
        guard isForeground, !alerting.isEmpty else { return }
        // The app is open: take over every ringing alarm in-app.
        for alarm in alerting {
            join(alarmID: alarm.id)
        }
        engageInApp()
        for alarm in alerting {
            AlarmScheduler.stop(alarm.id)
        }
    }

    /// Adds the alarm to the current session, or starts a new session.
    private func join(alarmID: UUID) {
        let context = AlarmRegistry.shared.context(for: alarmID) ?? .fallback
        if var s = session {
            if let itemID = context.itemID, !s.itemIDs.contains(itemID) {
                s.itemIDs.append(itemID)
                session = s
                saveSession()
            }
        } else {
            session = RingSession(context: context)
            saveSession()
        }
    }

    // MARK: App lifecycle

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            isForeground = true
            if session != nil {
                engageInApp()
                for alarm in AlarmScheduler.currentAlarms() where alarm.state == .alerting {
                    join(alarmID: alarm.id)
                    AlarmScheduler.stop(alarm.id)
                }
            }
            Task { await AlarmStore.shared.resync() }
        case .background:
            isForeground = false
            guard inAppEngaged, let s = session else { return }
            // Make sure the safety net is right before iOS may suspend us.
            let fireAt = s.muteUntil.map { max($0, Date().addingTimeInterval(2)) }
                ?? Date().addingTimeInterval(Self.watchdogLead)
            let taskID = UIApplication.shared.beginBackgroundTask(withName: "watchdog")
            Task { @MainActor in
                await self.replaceWatchdog(fireAt: fireAt)
                UIApplication.shared.endBackgroundTask(taskID)
            }
        default:
            break
        }
    }

    // MARK: In-app ringing

    private func engageInApp() {
        guard var s = session else { return }
        inAppEngaged = true
        if let r = s.reRingID {
            AlarmScheduler.cancel(r)
            s.reRingID = nil
        }
        if let m = s.muteUntil, m <= Date() {
            s.muteUntil = nil
        }
        session = s
        saveSession()

        if s.isMuted() {
            sound.stop()
        } else {
            sound.play(s.sound)
        }
        UIApplication.shared.isIdleTimerDisabled = true
        startTicker()
        Task { await refreshWatchdog() }
    }

    private func startTicker() {
        guard ticker == nil else { return }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard inAppEngaged, let s = session else {
            stopTicker()
            return
        }
        let now = Date()
        if let m = s.muteUntil, now >= m {
            session?.muteUntil = nil
            saveSession()
            sound.play(s.sound)
            Task { await refreshWatchdog() }
        } else if now.timeIntervalSince(lastWatchdogRefresh) >= Self.watchdogRefreshInterval {
            Task { await refreshWatchdog() }
        }
        if !s.isMuted(at: now), !sound.isPlaying {
            sound.play(s.sound)
        }
        if isForeground, !s.isMuted(at: now), now.timeIntervalSince(lastVibrate) >= Self.vibrateInterval {
            lastVibrate = now
            sound.vibrate()
        }
    }

    private func refreshWatchdog() async {
        guard let s = session else { return }
        let fireAt: Date
        if let m = s.muteUntil, m > Date() {
            fireAt = isForeground ? m.addingTimeInterval(Self.foregroundMuteGrace) : m
        } else {
            fireAt = Date().addingTimeInterval(Self.watchdogLead)
        }
        await replaceWatchdog(fireAt: fireAt)
    }

    private func replaceWatchdog(fireAt: Date) async {
        guard let s = session else { return }
        lastWatchdogRefresh = Date()
        let sessionID = s.id
        guard let newID = try? await AlarmScheduler.scheduleFixed(at: fireAt, context: s.context(purpose: .watchdog)) else {
            return
        }
        guard session?.id == sessionID else {
            AlarmScheduler.cancel(newID)
            return
        }
        if let old = session?.watchdogID { AlarmScheduler.cancel(old) }
        session?.watchdogID = newID
        saveSession()
    }

    // MARK: Buttons on the ringing screen

    /// Silences for exactly 90 s; the sound then resumes by itself.
    func mute() {
        guard var s = session, !s.isMuted() else { return }
        s.muteUntil = Date().addingTimeInterval(Self.muteDuration)
        session = s
        saveSession()
        sound.stop()
        Task { await refreshWatchdog() }
    }

    enum Outcome { case solved, surrendered }

    /// Solved or surrendered: stop everything, cancel re-rings, and let
    /// repeating alarms carry on to their next occurrence.
    func resolve(_ outcome: Outcome) {
        let itemIDs = session?.itemIDs ?? []
        session = nil
        Persistence.delete(Self.sessionFile)
        inAppEngaged = false
        stopTicker()
        sound.stop()
        UIApplication.shared.isIdleTimerDisabled = false

        // Cancel every re-ring / watchdog / test alarm, and silence anything of ours still ringing.
        for id in AlarmRegistry.shared.ids(withPurpose: [.reRing, .watchdog, .test]) {
            AlarmScheduler.cancel(id)
        }
        for alarm in AlarmScheduler.currentAlarms() where alarm.state == .alerting {
            AlarmScheduler.stop(alarm.id)
        }
        Task { await AlarmStore.shared.didResolve(itemIDs: itemIDs) }
    }

    // MARK: Test button

    func scheduleTestRing(in seconds: TimeInterval = 10) async -> Bool {
        let context = RingContext(itemID: nil, label: "Test alarm", challenge: .random,
                                  difficulty: .medium, sound: .classic, purpose: .test)
        let fireAt = Date().addingTimeInterval(seconds)
        do {
            try await AlarmScheduler.scheduleFixed(at: fireAt, context: context)
            lastTestScheduledFor = fireAt
            return true
        } catch {
            return false
        }
    }

    // MARK: Persistence

    private func saveSession() {
        if let session {
            Persistence.save(session, to: Self.sessionFile)
        } else {
            Persistence.delete(Self.sessionFile)
        }
    }
}
