import SwiftUI
import AlarmKit
import MathEngine

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var ring: RingCoordinator

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $settings.problemsPerRing, in: 1...3) {
                        LabeledContent("Problems per ring", value: "\(settings.problemsPerRing)")
                    }
                    Picker("Change shows f as", selection: $settings.changeDisplay) {
                        ForEach(AppSettings.ChangeDisplay.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Show correct part during alarms", isOn: $settings.zoneRevealInAlarms)
                    Toggle("Sketch the whole graph", isOn: $settings.wholeGraph)
                } header: {
                    Text("Challenges")
                } footer: {
                    Text("More problems per ring means you have to solve several in a row before the alarm stops. Surrender still works at any time.\n\nWhole graph: for functions that don't repeat, you draw the whole graph (asymptotes included) and can pinch, use Move or ± to zoom and pan. What you drew inside the view is checked, and it has to include every peak, dip, zero, inflection point and asymptote.")
                }

                Section {
                    Toggle("More problems after mistakes", isOn: $settings.escalation)
                    Picker("Awake check", selection: $settings.awakeCheckMinutes) {
                        Text("Off").tag(0)
                        ForEach([3, 5, 10, 15], id: \.self) { Text("\($0) min after").tag($0) }
                    }
                    Picker("Walk before it stops", selection: $settings.stepsToWalk) {
                        Text("Off").tag(0)
                        ForEach([20, 40, 80], id: \.self) { Text("\($0) steps").tag($0) }
                    }
                    Toggle("Hold Surrender for 2 s", isOn: $settings.holdToSurrender)
                    Picker("Friday & Saturday", selection: $settings.weekendDifficulty) {
                        Text("Alarm's own").tag(Difficulty?.none)
                        ForEach(Difficulty.allCases) { Text($0.title).tag(Difficulty?.some($0)) }
                    }
                    NavigationLink {
                        SetupCheckView()
                            .environmentObject(store)
                            .environmentObject(ring)
                    } label: {
                        Label("Test my setup", systemImage: "checklist")
                    }
                } header: {
                    Text("Wake-up rules (β)")
                } footer: {
                    Text("Mistakes: every 3 wrong answers add one more problem (at most 2). Awake check: a few minutes after you solve, a gentle ring with an \u{201C}I'm awake\u{201D} button. Walk: after the last problem, walk that many steps (needs Motion access). Friday & Saturday: a different difficulty on weekend mornings.")
                }

                Section {
                    DatePicker("Bagrut exam", selection: Binding(get: { settings.examDate ?? Date().addingTimeInterval(60 * 86_400) },
                                                                 set: { settings.examDate = $0 }),
                               in: Date()..., displayedComponents: .date)
                    if settings.examDate != nil {
                        Button("Clear exam date", role: .destructive) { settings.examDate = nil }
                    }
                } header: {
                    Text("Exam countdown")
                } footer: {
                    Text("Shown on the Progress tab with a daily plan.")
                }

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
                } header: {
                    Text("Drawing mode (Graph Sketch and Change)")
                }

                Section {
                    Picker("Challenge", selection: $settings.quickChallenge) {
                        ForEach(ChallengeKind.allCases) { Text($0.title).tag($0) }
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
                } header: {
                    Text("Timers and the 10-second test")
                }

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
                    DisclosureGroup("How to reinstall") {
                        Text("""
                        1. Download the latest MathAlarm.ipa from the GitHub Releases page.
                        2. Plug the iPhone into your PC and open iloader.
                        3. Import the .ipa and install it over the existing app — don't delete the app first, or your alarms are lost.
                        """)
                        .font(.footnote)
                    }
                    DisclosureGroup("Skip the PC: SideStore") {
                        Text("""
                        SideStore can refresh the app on the phone itself every week. Set it up once with iloader ("Install SideStore"), import MathAlarm.ipa inside SideStore, then tap Refresh All in SideStore at least once a week. Full guide: the README on GitHub.
                        """)
                        .font(.footnote)
                    }
                } header: {
                    Text("Free Apple ID install")
                } footer: {
                    Text("Apps installed with a free Apple ID stop opening after 7 days. If that happens, alarms may not ring.")
                }

                Section("Your stats") {
                    LabeledContent("Problems solved", value: "\(settings.solved)")
                    LabeledContent("Surrenders", value: "\(settings.surrendered)")
                    LabeledContent("Day streak", value: "\(settings.streak) 🔥")
                }

                Section("Permissions") {
                    LabeledContent("Alarms", value: store.authorization == .authorized ? "Allowed" : "Not allowed")
                    Button("Open iPhone Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }

                Section("How answers are checked") {
                    Text("""
                    Integrals and derivatives: your expression is compared with the correct one at 40 random points, so any equivalent form passes, simplified or not, with or without + C. Points are only taken from the interval shown with the problem (if any); there ln x and ln|x| agree, so both are accepted.

                    Graph Sketch and Change: your drawing is compared with the true graph in 8 strips, at the ends, at zeros and at every peak and dip. The drawing mode decides how much has to match: Precision and Standard check values, Proportions allows any vertical scale, Shape only looks at the overall shape. Where the graph runs off the box (an asymptote), your line has to leave the box the same way. Every correction shown can be fixed in its zone: if fixing a small part wouldn't be enough, the zone is made bigger.
                    """)
                    .font(.footnote)
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
