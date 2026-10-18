import SwiftUI

/// The conversation itself: dark stage, the tutor's words, your breath.
struct TalkingView: View {
    let conversation: Conversation
    let room: Room
    let language: PracticeLanguage
    var onClose: () -> Void = {}

    @State private var showingExit = false

    var body: some View {
        ZStack {
            Theme.stage.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, Theme.Space.m)
                    .padding(.top, Theme.Space.s)

                Spacer(minLength: Theme.Space.l)

                transcript
                    .padding(.horizontal, Theme.Space.l)

                Spacer(minLength: Theme.Space.l)

                ListeningOrb(level: conversation.listener.level, phase: conversation.phase)
                    .padding(.bottom, Theme.Space.m)

                statusLine
                    .padding(.bottom, Theme.Space.m)

                if case .failed(let message) = conversation.phase {
                    failurePanel(message)
                        .padding(.horizontal, Theme.Space.l)
                        .padding(.bottom, Theme.Space.l)
                } else {
                    Color.clear.frame(height: Theme.Space.xl + Theme.Space.m)
                }
            }
        }
        .preferredColorScheme(.dark)
        .confirmationDialog("End this conversation?", isPresented: $showingExit) {
            Button("End") { Task { await conversation.end() } }
            Button("Keep talking", role: .cancel) {}
        }
        .task {
            conversation.start()
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(room.title)
                    .font(.label(13, weight: .semibold))
                    .foregroundStyle(Theme.stageInk)
                Text("\(language.name) · \(room.level.cefr)")
                    .font(.label(11, weight: .medium))
                    .foregroundStyle(Theme.stageSoft)
            }
            Spacer()
            Clock(seconds: conversation.elapsed, tint: Theme.stageSoft)
            Button {
                showingExit = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.stageInk)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(Theme.stageSoft.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.leading, Theme.Space.s)
        }
    }

    private var transcript: some View {
        VStack(spacing: Theme.Space.m) {
            Text(spokenLine)
                .font(.display(28))
                .foregroundStyle(Theme.stageInk)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .frame(maxWidth: 520)
                .animation(.easeOut(duration: 0.2), value: spokenLine)

            if !conversation.listener.partial.isEmpty, conversation.phase == .listening {
                Text(conversation.listener.partial)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.stageSoft)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: 460)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.smooth(duration: 0.25), value: conversation.listener.partial)
    }

    /// The tutor's line in flight, otherwise the last one it said.
    private var spokenLine: String {
        if !conversation.liveLine.isEmpty { return conversation.liveLine }
        if let last = conversation.lines.last(where: { !$0.isYou }) { return last.text }
        return ""
    }

    private func failurePanel(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.stageInk)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onClose) {
                Text("Close")
                    .font(.label(14, weight: .semibold))
                    .foregroundStyle(Theme.stage)
                    .padding(.horizontal, Theme.Space.m)
                    .padding(.vertical, 9)
                    .background(Theme.stageAccent)
                    .clipShape(.rect(cornerRadius: Theme.Radius.small))
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .stroke(Theme.stageAccent.opacity(0.4), lineWidth: 1)
        )
    }

    private var statusLine: some View {
        Group {
            switch conversation.phase {
            case .preparing:
                Text("Opening the room")
            case .speaking:
                Text("\(room.title)")
            case .listening:
                Text("Your turn")
            case .thinking:
                Text("Thinking")
            case .ended:
                Text("Done")
            case .failed:
                Text("Stopped")
                    .foregroundStyle(Theme.stageAccent)
            }
        }
        .font(.label(11, weight: .medium))
        .tracking(1.2)
        .foregroundStyle(Theme.stageSoft)
        .textCase(.uppercase)
        .animation(.smooth, value: conversation.phase)
    }
}
