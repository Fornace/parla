import FoundationModels
import SwiftUI

/// The one machine requirement: Apple Intelligence on, model ready.
struct ModelGate: View {
    @Environment(\.colorScheme) private var scheme
    let availability: SystemLanguageModel.Availability

    var body: some View {
        switch availability {
        case .available:
            EmptyView()
        case .unavailable(let reason):
            Card {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Text(title(for: reason))
                        .font(.label(15, weight: .semibold))
                        .foregroundStyle(Theme.ink(scheme))
                    Text(detail(for: reason))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkSoft(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func title(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            "This device cannot run the tutor"
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence is off"
        case .modelNotReady:
            "The model is still arriving"
        @unknown default:
            "The model is not available"
        }
    }

    private func detail(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            "Parla holds the conversation on the device itself, so it needs a device that supports Apple Intelligence. Your saved sessions are still here."
        case .appleIntelligenceNotEnabled:
            "Turn on Apple Intelligence in Settings to start a conversation. Everything else in Parla still works."
        case .modelNotReady:
            "The on-device model is downloading. It usually takes a few minutes on Wi-Fi, then the rooms open."
        @unknown default:
            "Try again in a moment."
        }
    }
}
