import SwiftUI

enum MacInset {
    /// Room for the floating window buttons on the Mac.
    static var top: CGFloat {
        #if os(macOS)
        40
        #else
        Theme.Space.xl
        #endif
    }
}

extension View {
    /// A full screen on iPhone, a sheet on the Mac, where a cover would take
    /// the whole display away from the rest of the app.
    @ViewBuilder
    func sessionCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(macOS)
        sheet(item: item) { value in
            content(value)
                .frame(minWidth: 560, minHeight: 660)
        }
        #else
        fullScreenCover(item: item) { value in content(value) }
        #endif
    }
}

/// Primary action: flat accent fill, one line of text.
struct PrimaryButton: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.xs) {
                Text(title)
                    .font(.label(17, weight: .semibold))
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundStyle(isEnabled ? Theme.paper(scheme) : Theme.inkSoft(scheme))
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(isEnabled ? Theme.accent(scheme) : Theme.line(scheme))
            .clipShape(.rect(cornerRadius: Theme.Radius.small + 4))
        }
        .buttonStyle(.plain)
    }
}

/// Secondary action: hairline only.
struct GhostButton: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.label(15, weight: .medium))
                .foregroundStyle(Theme.ink(scheme))
                .padding(.horizontal, Theme.Space.m)
                .padding(.vertical, 10)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .stroke(Theme.line(scheme), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Small monospaced timer.
struct Clock: View {
    let seconds: TimeInterval
    var tint: Color

    var body: some View {
        Text(Self.format(seconds))
            .font(.system(size: 15, weight: .medium, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(tint)
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// The last seven days of practice, oldest on the left.
struct StreakDots: View {
    @Environment(\.colorScheme) private var scheme
    let days: [Bool]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, done in
                Circle()
                    .fill(done ? Theme.accent(scheme) : Theme.line(scheme))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

/// The living object that listens. Solid fills only, radius follows the
/// microphone level so the breath is visible but never theatrical.
struct ListeningOrb: View {
    let level: Double
    let phase: Conversation.Phase

    @State private var breathe = false
    @State private var spin = false

    private var isHot: Bool { phase == .listening }
    private var isThinking: Bool { phase == .thinking }

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.stageAccent.opacity(0.10))
                .frame(width: 168, height: 168)
                .scaleEffect(isHot ? 1 + level * 0.22 : (breathe ? 1.04 : 1.0))

            Circle()
                .strokeBorder(Theme.stageAccent.opacity(isHot ? 0.45 : 0.18), lineWidth: 1)
                .frame(width: 132, height: 132)

            Circle()
                .fill(isHot ? Theme.stageAccent : Theme.stageAccent.opacity(0.25))
                .frame(width: 84, height: 84)
                .scaleEffect(isHot ? 0.92 + level * 0.30 : 0.82)

            if isThinking {
                EqualizerBars(active: true, tint: Theme.stage)
                    .frame(width: 34, height: 16)
            } else {
                Image(systemName: isHot ? "waveform" : "ellipsis")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isHot ? Theme.stage : Theme.stageInk)
                    .opacity(isHot ? 1 : 0.55)
            }
        }
        .frame(width: 168, height: 168)
        .animation(.smooth(duration: 0.18), value: level)
        .animation(.smooth(duration: 0.4), value: phase)
        .onAppear { breathe = true }
        .onChange(of: phase) { _, _ in breathe = true }
        .task(id: isHot) {
            guard isHot else { return }
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 1.6)) { breathe.toggle() }
                try? await Task.sleep(for: .milliseconds(1600))
            }
        }
    }
}

struct EqualizerBars: View {
    let active: Bool
    var tint: Color
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(tint.opacity(active ? 0.9 : 0.4))
                    .frame(width: 3)
                    .frame(height: active ? height(for: index) : 4)
            }
        }
        .task(id: active) {
            guard active else { return }
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.34)) { phase += 1 }
                try? await Task.sleep(for: .milliseconds(340))
            }
        }
    }

    private func height(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [6, 14, 9, 4]
        let step = (Int(phase) + index) % pattern.count
        return pattern[step]
    }
}

/// A phrase you can hear again.
struct SpeakButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft(scheme))
                .frame(width: 30, height: 30)
                .overlay(
                    Circle().stroke(Theme.line(scheme), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
