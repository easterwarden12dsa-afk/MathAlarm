import SwiftUI
import AlarmKit
import MathEngine

/// Settings, grouped like the iPhone's own: a summary at the top, then one
/// page per subject.
struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var ring: RingCoordinator

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $settings.language) {
                        ForEach(AppLanguage.allCases) { Text(verbatim: $0.title).tag($0) }
                    } label: {
                        SettingsRow("Language", "globe", .teal)
                    }
                }

                Section {
                    HStack(spacing: 0) {
                        summary("\(settings.streak)", "day streak", "flame.fill", .orange)
                        Divider().frame(height: 44)
                        summary("\(settings.solved)", "solved", "checkmark.circle.fill", .green)
                        Divider().frame(height: 44)
                        summary("\(settings.surrendered)", "surrenders", "flag.fill", .red)
                    }
                    .padding(.vertical, 4)
                }

                Section("Alarms") {
                    NavigationLink { ChallengeSettingsPage() } label: {
                        SettingsRow("Challenges", "function", .orange, detail: "\(settings.problemsPerRing) per ring")
                    }
                    NavigationLink { WakeUpRulesPage() } label: {
                        SettingsRow("Wake-up rules", "sunrise.fill", .yellow, detail: wakeSummary)
                    }
                    NavigationLink { DrawingModePage() } label: {
                        SettingsRow("Drawing mode", "pencil.and.ruler", .purple, detail: settings.sketchMode.title)
                    }
                    NavigationLink { QuickTestPage().environmentObject(ring) } label: {
                        SettingsRow("Timers and the test ring", "timer", .blue, detail: settings.quickChallenge.title)
                    }
                }

                Section("Study") {
                    DatePicker(selection: Binding(get: { settings.examDate ?? Date().addingTimeInterval(60 * 86_400) },
                                                  set: { settings.examDate = $0 }),
                               in: Date()..., displayedComponents: .date) {
                        SettingsRow("Bagrut exam", "graduationcap.fill", .indigo)
                    }
                    if settings.examDate != nil {
                        Button("Clear exam date", role: .destructive) { settings.examDate = nil }
                    }
                }

                Section {
                    NavigationLink {
                        SetupCheckView().environmentObject(store).environmentObject(ring)
                    } label: {
                        SettingsRow("Test my setup", "checklist", .green, detail: store.authorization == .authorized ? nil : "Action needed")
                    }
                    NavigationLink { InstallPage() } label: {
                        SettingsRow("Install & expiry", "clock.badge.exclamationmark", .red, detail: ExpiryMonitor.daysLeft.map { $0 < 1 ? "< 1 day" : "\(Int($0)) days" })
                    }
                    NavigationLink { CheckingPage() } label: {
                        SettingsRow("How answers are checked", "questionmark.circle.fill", .gray)
                    }
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: {
                        SettingsRow("iPhone Settings", "gear", .gray, detail: store.authorization == .authorized ? "Alarms allowed" : "Alarms not allowed")
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Help")
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var wakeSummary: String {
        var on: [String] = []
        if settings.escalation { on.append("mistakes") }
        if settings.awakeCheckMinutes > 0 { on.append("awake") }
        if settings.stepsToWalk > 0 { on.append("walk") }
        if settings.weekendDifficulty != nil { on.append("weekend") }
        return on.isEmpty ? "Off" : "\(on.count) on"
    }

    private func summary(_ value: String, _ label: String, _ symbol: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: symbol).foregroundStyle(color).font(.footnote)
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// An iPhone-Settings-style row: a coloured icon tile, a title and a quiet value.
struct SettingsRow: View {
    let title: String
    let symbol: String
    let color: Color
    var detail: String? = nil

    init(_ title: String, _ symbol: String, _ color: Color, detail: String? = nil) {
        self.title = title
        self.symbol = symbol
        self.color = color
        self.detail = detail
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 7))
            Text(title)
            Spacer(minLength: 4)
            if let detail {
                Text(detail).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}

// MARK: - Pages

private struct ChallengeSettingsPage: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Stepper(value: $settings.problemsPerRing, in: 1...3) {
                    LabeledContent("Problems per ring", value: "\(settings.problemsPerRing)")
                }
            } footer: {
                Text("More problems per ring means you have to solve several in a row before the alarm stops. Surrender still works at any time.")
            }
            Section {
                Picker("Change shows f as", selection: $settings.changeDisplay) {
                    ForEach(AppSettings.ChangeDisplay.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Show correct part during alarms", isOn: $settings.zoneRevealInAlarms)
                Toggle("Sketch the whole graph", isOn: $settings.wholeGraph)
            } header: {
                Text("Graph Sketch and Change")
            } footer: {
                Text("Whole graph: for functions that don't repeat, you draw the whole graph (asymptotes included) and can pinch, use Move or ± to zoom and pan. What you drew inside the view is checked, and it has to include every peak, dip, zero, inflection point and asymptote.")
            }
        }
        .navigationTitle("Challenges")
    }
}

private struct WakeUpRulesPage: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.escalation) { rule("More problems after mistakes", "Every 3 wrong answers add one more problem (at most 2).") }
                Toggle(isOn: $settings.holdToSurrender) { rule("Hold Surrender for 2 s", "So it isn't a half-asleep reflex.") }
            }
            Section {
                Picker(selection: $settings.awakeCheckMinutes) {
                    Text("Off").tag(0)
                    ForEach([3, 5, 10, 15], id: \.self) { Text("\($0) min after").tag($0) }
                } label: {
                    rule("Awake check", "A gentle ring with an \u{201C}I'm awake\u{201D} button, a few minutes after you solve.")
                }
                Picker(selection: $settings.stepsToWalk) {
                    Text("Off").tag(0)
                    ForEach([20, 40, 80], id: \.self) { Text("\($0) steps").tag($0) }
                } label: {
                    rule("Walk before it stops", "After the last problem (needs Motion access).")
                }
            } header: {
                Text("After solving")
            }
            Section {
                Picker(selection: $settings.weekendDifficulty) {
                    Text("Alarm's own").tag(Difficulty?.none)
                    ForEach(Difficulty.allCases) { Text($0.title).tag(Difficulty?.some($0)) }
                } label: {
                    rule("Friday & Saturday", "A different difficulty on weekend mornings.")
                }
            } header: {
                Text("Weekend")
            }
        }
        .navigationTitle("Wake-up rules")
    }

    private func rule(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
    }
}

private struct DrawingModePage: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                ForEach(SketchMode.allCases) { mode in
                    Button {
                        Haptics.tap()
                        settings.sketchMode = mode
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.title).font(.headline).foregroundStyle(.primary)
                                Text(mode.summary).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if settings.sketchMode == mode {
                                Image(systemName: "checkmark").foregroundStyle(.orange).fontWeight(.bold)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("Used by Graph Sketch and Change, in alarms and in Practice.")
            }
        }
        .navigationTitle("Drawing mode")
    }
}

private struct QuickTestPage: View {
    @ObservedObject private var settings = AppSettings.shared
    @EnvironmentObject private var ring: RingCoordinator

    var body: some View {
        Form {
            Section {
                Picker("Challenge", selection: $settings.quickChallenge) {
                    ForEach(ChallengeKind.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
                Picker("Difficulty", selection: $settings.quickDifficulty) {
                    ForEach(Difficulty.allCases) { Text($0.title).tag($0) }
                }
                NavigationLink {
                    SoundPickerView(selection: $settings.quickSound)
                        .environmentObject(ring)
                } label: {
                    LabeledContent("Sound", value: settings.quickSound.title)
                }
            } footer: {
                Text("Used by countdown timers and by the 10-second test ring.")
            }
        }
        .navigationTitle("Timers and test")
    }
}

private struct InstallPage: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                if let expiry = ExpiryMonitor.expirationDate {
                    LabeledContent("This install works until", value: expiry.formatted(date: .abbreviated, time: .shortened))
                    if let days = ExpiryMonitor.daysLeft {
                        LabeledContent("Time left", value: days < 1 ? "less than a day" : "\(Int(days)) days")
                            .foregroundStyle(days <= 2 ? .red : .primary)
                    }
                    Toggle("Remind me the day before", isOn: $settings.expiryReminder)
                } else {
                    Text("Expiry date not found (it's only present in sideloaded builds).")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Apps installed with a free Apple ID stop opening after 7 days. If that happens, alarms may not ring.")
            }
            Section("How to reinstall") {
                Text("""
                1. Download the latest MathAlarm.ipa from the GitHub Releases page.
                2. Plug the iPhone into your PC and open iloader.
                3. Import the .ipa and install it over the existing app — don't delete the app first, or your alarms are lost.
                """)
                .font(.footnote)
            }
            Section("Skip the PC: SideStore") {
                Text("""
                SideStore can refresh the app on the phone itself every week. Set it up once with iloader ("Install SideStore"), import MathAlarm.ipa inside SideStore, then tap Refresh All in SideStore at least once a week. Full guide: the README on GitHub.
                """)
                .font(.footnote)
            }
        }
        .navigationTitle("Install & expiry")
    }
}

private struct CheckingPage: View {
    var body: some View {
        Form {
            Section("Integrals and derivatives") {
                Text("Your expression is compared with the correct one at 40 random points, so any equivalent form passes, simplified or not, with or without + C. Points are only taken from the interval shown with the problem (if any); there ln x and ln|x| agree, so both are accepted.")
                    .font(.footnote)
            }
            Section("Graph Sketch and Change") {
                Text("Your drawing is compared with the true graph in 8 strips, at the ends, at zeros and at every peak and dip. The drawing mode decides how much has to match: Precision and Standard check values, Proportions allows any vertical scale, Shape only looks at the overall shape. Where the graph runs off the box (an asymptote), your line has to leave the box the same way. Every correction shown can be fixed in its zone: if fixing a small part wouldn't be enough, the zone is made bigger.")
                    .font(.footnote)
            }
            Section("Questions, probability, triangles, min & max") {
                Text("Typed numbers are checked exactly, so √7, 5√2/2, 3/10 or 2/e all work. When a question asks for 2 (or 3) decimal places, an answer within rounding is accepted. Multiple-choice and sign-table answers can't be retried: the right answer is shown instead.")
                    .font(.footnote)
            }
        }
        .navigationTitle("How answers are checked")
    }
}
