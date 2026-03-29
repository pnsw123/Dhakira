import SwiftUI
import AVFoundation

// MARK: - AudioPlayerView
// Compact bottom sheet for playing back a saved voice recording.
// Presented when the user taps an audio chip ("🎙 Recording • 0:42") in the note editor.
// Visual language matches AudioRecorderView (same detent, same material background).

struct AudioPlayerView: View {
    let audioLink: AudioLink

    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = AudioPlayerController()

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 16)

            // Recording name
            Text(audioLink.name)
                .font(.headline)
                .padding(.bottom, 4)

            // Date + duration subtitle
            Text(formattedDate(audioLink.date) + " · " + formattedDuration(controller.duration))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)

            if controller.loadFailed {
                // File missing (transferred device, cleaned up, etc.)
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                Text("Recording not found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            } else {
                // Scrubber
                scrubberView
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)

                // Time labels
                HStack {
                    Text(formattedDuration(controller.currentTime))
                    Spacer()
                    Text(formattedDuration(controller.duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 28)
                .padding(.bottom, 24)

                // Play / Pause button
                Button { controller.togglePlayPause() } label: {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(.white)
                                // Visually center the play triangle (it's off-center by design in SF Symbols)
                                .offset(x: controller.isPlaying ? 0 : 2)
                        }
                }
                .padding(.bottom, 28)
            }
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.regularMaterial)
        .onAppear {
            controller.load(url: audioLink.fileURL, reportedDuration: audioLink.duration)
        }
        .onDisappear {
            controller.stop()
        }
    }

    // MARK: - Scrubber

    private var scrubberView: some View {
        GeometryReader { geo in
            let progress: Double = controller.duration > 0
                ? min(1, max(0, controller.currentTime / controller.duration))
                : 0

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(height: 4)

                // Fill
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(0, geo.size.width * progress), height: 4)
            }
            // Expanded hit area for easier scrubbing
            .contentShape(Rectangle().size(CGSize(width: geo.size.width, height: 36)))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        controller.seek(to: fraction)
                    }
            )
        }
        .frame(height: 36)
    }

    // MARK: - Helpers

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
