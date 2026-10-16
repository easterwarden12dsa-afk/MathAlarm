import Foundation
import AVFoundation

/// Sounds the user imported from the Files app. They're converted to CAF
/// (uncompressed audio, cut to 29 s and normalised to full volume) and stored
/// in Library/Sounds, which is where iOS looks for custom alarm sounds.
final class CustomSoundLibrary: ObservableObject {
    static let shared = CustomSoundLibrary()

    struct Entry: Codable, Identifiable, Hashable {
        let id: String      // "custom-<uuid>"
        var title: String
    }

    @Published private(set) var entries: [Entry]

    private static let indexFile = "customSounds.json"
    static let maxSeconds: Double = 29

    static var soundsDirectory: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let dir = library.appendingPathComponent("Sounds", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private init() {
        entries = Persistence.load([Entry].self, from: Self.indexFile) ?? []
    }

    var sounds: [AlarmSound] { entries.map { AlarmSound(id: $0.id) } }

    func title(for sound: AlarmSound) -> String? {
        entries.first { $0.id == sound.id }?.title
    }

    enum ImportError: LocalizedError {
        case unreadable
        case empty

        var errorDescription: String? {
            switch self {
            case .unreadable: "That file couldn't be read as audio."
            case .empty: "That audio file is empty."
            }
        }
    }

    /// Converts and stores an audio file picked by the user.
    func importSound(from source: URL) async throws -> AlarmSound {
        let id = "custom-\(UUID().uuidString)"
        let destination = Self.soundsDirectory.appendingPathComponent("\(id).caf")
        let title = source.deletingPathExtension().lastPathComponent

        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }

        try await Task.detached(priority: .userInitiated) {
            try Self.convert(source, to: destination)
        }.value

        await MainActor.run {
            entries.append(Entry(id: id, title: title))
            Persistence.save(entries, to: Self.indexFile)
        }
        return AlarmSound(id: id)
    }

    func delete(_ sound: AlarmSound) {
        try? FileManager.default.removeItem(at: Self.soundsDirectory.appendingPathComponent(sound.fileName))
        entries.removeAll { $0.id == sound.id }
        Persistence.save(entries, to: Self.indexFile)
    }

    private static func convert(_ source: URL, to destination: URL) throws {
        let input: AVAudioFile
        do {
            input = try AVAudioFile(forReading: source)
        } catch {
            throw ImportError.unreadable
        }
        let format = input.processingFormat
        let frameCount = AVAudioFrameCount(min(Double(input.length), maxSeconds * format.sampleRate))
        guard frameCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw ImportError.empty
        }
        try input.read(into: buffer, frameCount: frameCount)

        // Normalise so quiet recordings still wake you up.
        if let channels = buffer.floatChannelData {
            var peak: Float = 0
            for c in 0..<Int(format.channelCount) {
                for i in 0..<Int(buffer.frameLength) { peak = max(peak, abs(channels[c][i])) }
            }
            if peak > 0.001 {
                let gain = 0.97 / peak
                for c in 0..<Int(format.channelCount) {
                    for i in 0..<Int(buffer.frameLength) { channels[c][i] *= gain }
                }
            }
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        try? FileManager.default.removeItem(at: destination)
        let output = try AVAudioFile(forWriting: destination, settings: settings,
                                     commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        try output.write(from: buffer)
    }
}
