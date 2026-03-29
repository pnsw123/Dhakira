import AVFoundation
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "AudioPlayer")

#if canImport(UIKit)
import UIKit
import Combine

// MARK: - AudioPlayerController
// ObservableObject that owns AVAudioPlayer lifecycle.
// Separated from the view so it can be torn down cleanly when the
// playback sheet dismisses — no leaked timers or audio sessions.
//
// Uses CADisplayLink (60fps) for scrubber updates so the progress bar
// moves smoothly rather than with a coarser Timer tick.

@MainActor
final class AudioPlayerController: NSObject, ObservableObject {

    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var loadFailed: Bool = false

    private var player: AVAudioPlayer?
    private var displayLink: CADisplayLink?

    // MARK: - Public API

    func load(url: URL, reportedDuration: TimeInterval) {
        duration = reportedDuration
        loadFailed = false

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            duration = p.duration > 0 ? p.duration : reportedDuration
            player = p
            log.info("AudioPlayerController: loaded \(url.lastPathComponent), duration \(p.duration)s")
        } catch {
            log.error("AudioPlayerController: load failed — \(error.localizedDescription)")
            loadFailed = true
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopDisplayLink()
        } else {
            player.play()
            isPlaying = true
            startDisplayLink()
        }
    }

    func seek(to fraction: Double) {
        guard let player else { return }
        player.currentTime = fraction * player.duration
        currentTime = player.currentTime
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        stopDisplayLink()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        log.debug("AudioPlayerController: stopped")
    }

    // MARK: - CADisplayLink

    private func startDisplayLink() {
        stopDisplayLink()
        let dl = CADisplayLink(target: self, selector: #selector(tick))
        dl.add(to: .main, forMode: .common)
        displayLink = dl
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        currentTime = player?.currentTime ?? 0
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0
            self.stopDisplayLink()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            log.error("AudioPlayerController: decode error — \(error?.localizedDescription ?? "unknown")")
            self.isPlaying = false
            self.loadFailed = true
            self.stopDisplayLink()
        }
    }
}

#endif // canImport(UIKit)
