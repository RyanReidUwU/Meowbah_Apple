//
//  AudioPlayback.swift
//  Meowbah
//
//  Created by Ryan Reid on 02/09/2025.
//

import AVFoundation

final class AudioPlayback {
    static let shared = AudioPlayback()

    // Use AVQueuePlayer + AVPlayerLooper for seamless looping
    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    private init() { }

    var isInitialized: Bool { queuePlayer != nil }
    var isPlaying: Bool {
        guard let player = queuePlayer else { return false }
        return player.timeControlStatus == .playing
    }

    // Start from the beginning and loop indefinitely (used on login).
    // If already initialized, this replaces the current loop and restarts from the beginning.
    func startFromBeginningLoop(named baseName: String, ext: String, respectSilent: Bool = true) {
        guard let url = Bundle.main.url(forResource: baseName, withExtension: ext) ??
                        Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil)?
                            .first(where: { $0.lastPathComponent == "\(baseName).\(ext)" }) else {
            return
        }
#if os(iOS) || os(tvOS)
        startLoopingPlayback(url: url, respectSilent: respectSilent)
#else
        startLoopingPlayback(url: url, respectSilent: respectSilent)
#endif
    }

    // Initialize and start if not yet initialized; otherwise no-op.
    // Useful when the toggle turns ON after app launch with no player yet.
    func ensureStartedLoop(named baseName: String, ext: String, respectSilent: Bool = true) {
        guard !isInitialized else { return }
        startFromBeginningLoop(named: baseName, ext: ext, respectSilent: respectSilent)
    }

    // Pause without tearing down. Resuming will continue from the same position.
    func pause() {
        queuePlayer?.pause()
        // Keep session active to allow quick resume; deactivate only on full stop if desired.
    }

    // Resume if initialized; does nothing if not initialized.
    func resume() {
        guard let player = queuePlayer else { return }
#if os(iOS) || os(tvOS)
        configureAudioSession(respectSilent: true)
#endif
        player.play()
    }

    // Stop and tear down (loses position).
    func stop() {
        looper = nil
        queuePlayer?.pause()
        queuePlayer = nil
#if os(iOS) || os(tvOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: [])
#endif
    }

    // MARK: - Internals

    private func startLoopingPlayback(url: URL, respectSilent: Bool) {
#if os(iOS) || os(tvOS)
        configureAudioSession(respectSilent: respectSilent)
#endif

        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        // Replace any previous player/looper so we start from the beginning
        let player = AVQueuePlayer()
        player.volume = 1.0

        self.queuePlayer = player
        self.looper = AVPlayerLooper(player: player, templateItem: item)

        player.play()
    }

#if os(iOS) || os(tvOS)
    private func configureAudioSession(respectSilent: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if respectSilent {
                try session.setCategory(.ambient, mode: .default, options: [])
            } else {
                try session.setCategory(.playback, mode: .default, options: [])
            }
            try session.setActive(true, options: [])
        } catch {
            // Ignore failures; playback may still proceed with defaults.
        }
    }
#else
    // macOS and other platforms do not use AVAudioSession; provide a no-op.
    private func configureAudioSession(respectSilent: Bool) { }
#endif
}
