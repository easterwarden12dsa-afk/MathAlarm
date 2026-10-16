import SwiftUI
import UniformTypeIdentifiers

/// Pick an alarm sound. Tapping a sound selects it and plays a preview.
struct SoundPickerView: View {
    @Binding var selection: AlarmSound
    @EnvironmentObject private var ring: RingCoordinator
    @ObservedObject private var library = CustomSoundLibrary.shared

    @State private var importing = false
    @State private var importError: String?
    @State private var isConverting = false

    var body: some View {
        List {
            Section {
                ForEach(AlarmSound.builtIns) { sound in
                    row(sound)
                }
                row(.systemDefault, detail: "The system alarm uses Apple's sound. Inside the app you'll hear Digital beeps.")
            } header: {
                Text("Built-in")
            } footer: {
                Text("Tap a sound to hear it. The alarm plays at your Alarm volume (Settings › Sounds & Haptics).")
            }

            Section("Your sounds") {
                ForEach(library.sounds) { sound in
                    row(sound)
                        .swipeActions {
                            Button(role: .destructive) {
                                if selection == sound { selection = .classic }
                                library.delete(sound)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                Button {
                    importing = true
                } label: {
                    if isConverting {
                        HStack { ProgressView(); Text("Importing…") }
                    } else {
                        Label("Import from Files…", systemImage: "square.and.arrow.down")
                    }
                }
                .disabled(isConverting)
                if let importError {
                    Text(importError).font(.footnote).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Sound")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                isConverting = true
                importError = nil
                Task {
                    do {
                        let sound = try await library.importSound(from: url)
                        selection = sound
                        ring.sound.preview(sound)
                    } catch {
                        importError = error.localizedDescription
                    }
                    isConverting = false
                }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .onDisappear { ring.sound.stopPreview() }
    }

    private func row(_ sound: AlarmSound, detail: String? = nil) -> some View {
        Button {
            selection = sound
            Haptics.tap()
            ring.sound.preview(sound)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.title).foregroundStyle(.primary)
                    if let detail {
                        Text(detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if selection == sound {
                    Image(systemName: "checkmark").foregroundStyle(.orange).fontWeight(.bold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.97))
    }
}
