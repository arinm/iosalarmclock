import Foundation
import AVFoundation
import Observation

/// Pro: lets the user import their own audio (from Files / Voice Memos / etc.)
/// and use it as the alarm sound. Imported files are converted to CAF (Linear
/// PCM, ≤30s) and stored in `Library/Sounds`, which is where iOS looks up custom
/// notification/alarm sounds by name.
///
/// NOTE: `Library/Sounds` is where iOS looks up custom notification sounds, so
/// the pre-alert is *expected* to play these — verify on-device. Whether
/// AlarmKit's *alarm* itself accepts a runtime-imported sound (vs. bundle-only)
/// also needs real-device validation — see AlarmKitManager.
@MainActor
@Observable
final class SoundManager {
    /// Apple's rule: notification audio must be UNDER 30 seconds — at exactly
    /// 30.0 (where any longer import lands after trimming) the system silently
    /// plays the DEFAULT sound instead. Clamp safely below the limit.
    static let maxSeconds: Double = 29.5

    private(set) var sounds: [String] = []   // CAF filenames in Library/Sounds
    private var player: AVAudioPlayer?

    init() { refresh() }

    static var soundsDirectory: URL {
        let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let dir = lib.appendingPathComponent("Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func refresh() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: Self.soundsDirectory.path)) ?? []
        sounds = files.filter { $0.hasSuffix(".caf") }.sorted()
    }

    func displayName(_ file: String) -> String { (file as NSString).deletingPathExtension }
    func url(for file: String) -> URL { Self.soundsDirectory.appendingPathComponent(file) }

    /// Import + convert. Returns the stored filename, or nil on failure.
    @discardableResult
    func importSound(from source: URL) async -> String? {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        // Sanitize to a safe, bounded sound filename.
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        var base = String(source.deletingPathExtension().lastPathComponent.map { allowed.contains($0) ? $0 : "_" }.prefix(40))
        if base.isEmpty { base = "Sound" }
        var name = "\(base).caf"
        var dest = Self.soundsDirectory.appendingPathComponent(name)
        var i = 1
        while FileManager.default.fileExists(atPath: dest.path) {
            name = "\(base)-\(i).caf"
            dest = Self.soundsDirectory.appendingPathComponent(name)
            i += 1
        }
        do {
            try await Self.convertToCAF(source: source, dest: dest)
            refresh()
            return name
        } catch {
            print("Sound import failed: \(error)")
            return nil
        }
    }

    func delete(_ file: String) {
        try? FileManager.default.removeItem(at: url(for: file))
        // Don't leave Settings' default pointing at a dead file (the Picker
        // would render blank and new alarms would seed an unresolvable name).
        if UserDefaults.standard.string(forKey: "defaultSoundName") == file {
            UserDefaults.standard.removeObject(forKey: "defaultSoundName")
        }
        refresh()
    }

    // MARK: Preview

    func preview(_ file: String) {
        stopPreview()
        // Use .playback so preview is audible even with the ring/silent switch off.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url(for: file))
        player?.play()
    }
    func stopPreview() {
        player?.stop(); player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Conversion

    /// Decode the source and write a notification-compatible CAF (16-bit LPCM,
    /// 44.1 kHz, ≤30s). MP3/M4A/WAV/AIFF in → CAF out; DRM-protected media fails.
    static func convertToCAF(source: URL, dest: URL) async throws {
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "SoundManager", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No audio track found."])
        }
        let duration = try await asset.load(.duration)
        let cap = CMTime(seconds: maxSeconds, preferredTimescale: 44_100)
        let end = CMTimeMinimum(duration, cap)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: .zero, duration: end)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(output)

        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        let writer = try AVAssetWriter(outputURL: dest, fileType: .caf)
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        writer.add(input)

        guard reader.startReading(), writer.startWriting() else {
            throw writer.error ?? reader.error ?? NSError(domain: "SoundManager", code: 2)
        }
        writer.startSession(atSourceTime: .zero)

        let queue = DispatchQueue(label: "com.punctual.soundconvert")
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            // The ready-callback can fire again after a failure path — a second
            // resume on a CheckedContinuation traps. Guarded; runs serially on
            // `queue`, so a plain flag is safe.
            var resumed = false
            func finish() {
                if !resumed { resumed = true; cont.resume() }
            }
            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData {
                    // Bail out (resume) if the writer failed, else we'd hang forever.
                    if writer.status == .failed || reader.status == .failed {
                        reader.cancelReading()
                        input.markAsFinished()
                        finish(); return
                    }
                    if let sample = output.copyNextSampleBuffer() {
                        if !input.append(sample) { // append failed
                            reader.cancelReading()
                            input.markAsFinished()
                            finish(); return
                        }
                    } else {
                        input.markAsFinished()
                        writer.finishWriting { finish() }
                        return
                    }
                }
            }
        }

        // Fail loudly if nothing valid was written (DRM, decode error, empty file).
        guard writer.status == .completed else {
            try? FileManager.default.removeItem(at: dest)
            throw writer.error ?? NSError(domain: "SoundManager", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't convert this audio file."])
        }

        // PROVE the under-30s rule (iOS silently plays the default sound at
        // ≥30.0s): AVFoundation doesn't guarantee the last decoded buffer is
        // truncated at the timeRange cut, so verify the written file. The 29.5s
        // cap leaves ~0.4s of slack for buffer granularity; anything at 29.9s+
        // is rejected rather than shipped broken.
        let writtenSeconds = try await AVURLAsset(url: dest).load(.duration).seconds
        guard writtenSeconds < 29.9 else {
            try? FileManager.default.removeItem(at: dest)
            throw NSError(domain: "SoundManager", code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Converted audio ended up too long for a notification sound."])
        }
    }
}
