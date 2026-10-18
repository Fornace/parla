import FoundationModels
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(Preferences.self) private var preferences
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                group("Speaking") {
                    LanguageRow(preferences: preferences)
                    Hairline()
                    LevelRow(preferences: preferences)
                    Hairline()
                    DepthRow(preferences: preferences)
                    Hairline()
                    VoiceRow(preferences: preferences)
                }
                group("The model") {
                    ModelRow()
                }
                group("Your data") {
                    DataRow()
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, Theme.Space.l)
            .padding(.top, MacInset.top)
            .padding(.bottom, Theme.Space.l)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Theme.paper(scheme).ignoresSafeArea())
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Eyebrow(text: title)
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                content()
            }
            .padding(Theme.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface(scheme))
            .clipShape(.rect(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.line(scheme), lineWidth: 1)
            )
        }
    }
}

private struct LanguageRow: View {
    @Bindable var preferences: Preferences
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack {
            Text("I speak")
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink(scheme))
            Spacer()
            Menu {
                ForEach(PracticeLanguage.all) { language in
                    Button(language.nativeName) { preferences.language = language }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(preferences.language.name)
                        .font(.label(14, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(Theme.ink(scheme))
            }
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}

/// One row of equal chips, used wherever a small choice is made.
private struct ChipRow<Item: Hashable>: View {
    let items: [Item]
    let title: (Item) -> String
    let selection: Item
    let select: (Item) -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { item in
                let selected = selection == item
                Button(title(item)) { select(item) }
                    .font(.label(12, weight: .semibold))
                    .foregroundStyle(selected ? Theme.paper(scheme) : Theme.inkSoft(scheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selected ? Theme.ink(scheme) : Theme.paper(scheme))
                    .clipShape(.rect(cornerRadius: Theme.Radius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.small)
                            .stroke(selected ? Color.clear : Theme.line(scheme), lineWidth: 1)
                    )
                    .buttonStyle(.plain)
            }
        }
    }
}

private struct LevelRow: View {
    @Bindable var preferences: Preferences
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("I am")
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink(scheme))
            ChipRow(
                items: Level.allCases,
                title: { $0.badge },
                selection: preferences.level,
                select: { preferences.level = $0 }
            )
        }
    }
}

private struct DepthRow: View {
    @Bindable var preferences: Preferences
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("Correct me")
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink(scheme))
            ChipRow(
                items: DebriefEngine.Depth.allCases,
                title: { $0.title },
                selection: preferences.depth,
                select: { preferences.depth = $0 }
            )
        }
    }
}

private struct VoiceRow: View {
    @Bindable var preferences: Preferences
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Voice speed")
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink(scheme))
            Slider(value: $preferences.voiceRate, in: 0.34...0.56)
                .tint(Theme.accent(scheme))
                .padding(.top, 4)
        }
    }
}

private struct ModelRow: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("On-device model")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink(scheme))
                Spacer()
                Text(status)
                    .font(.label(13, weight: .semibold))
                    .foregroundStyle(isReady ? Theme.moss(scheme) : Theme.accent(scheme))
            }
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft(scheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var isReady: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    private var status: String {
        switch SystemLanguageModel.default.availability {
        case .available: "Ready"
        case .unavailable(.deviceNotEligible): "Unsupported"
        case .unavailable(.appleIntelligenceNotEnabled): "Off"
        case .unavailable(.modelNotReady): "Downloading"
        case .unavailable: "Unavailable"
        }
    }

    private var detail: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            "Apple Intelligence runs the conversation here, on this device."
        case .unavailable(.appleIntelligenceNotEnabled):
            "Turn on Apple Intelligence in Settings to open the rooms."
        case .unavailable(.modelNotReady):
            "Still arriving. Wi-Fi speeds this up."
        case .unavailable(.deviceNotEligible):
            "This device does not support Apple Intelligence."
        case .unavailable:
            "Not available right now."
        }
    }
}

private struct DataRow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @State private var showingErase = false
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("Conversations, corrections and phrases live only in this app on this device. Nothing is uploaded, and there is no account.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSoft(scheme))
                .fixedSize(horizontal: false, vertical: true)
            if let problem {
                Text(problem)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent(scheme))
            }
            Button("Delete every session") { showingErase = true }
                .font(.label(14, weight: .medium))
                .foregroundStyle(Theme.accent(scheme))
                .buttonStyle(.plain)
                .padding(.top, 2)
        }
        .confirmationDialog("Delete every session?", isPresented: $showingErase) {
            Button("Delete everything", role: .destructive, action: erase)
            Button("Keep it", role: .cancel) {}
        }
    }

    private func erase() {
        do {
            try context.delete(model: Note.self)
            try context.delete(model: Line.self)
            try context.delete(model: Phrase.self)
            try context.delete(model: Practice.self)
            try context.save()
            problem = nil
        } catch {
            problem = "Could not delete: \(error.localizedDescription)"
        }
    }
}
