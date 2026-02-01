import SwiftUI

public struct FocusFilterBannerView: View {
    private let scopeName: String
    private let scopeEmoji: String
    private let isEnabled: Bool
    private let onToggle: () -> Void

    public init(
        scopeName: String,
        scopeEmoji: String,
        isEnabled: Bool,
        onToggle: @escaping () -> Void
    ) {
        self.scopeName = scopeName
        self.scopeEmoji = scopeEmoji
        self.isEnabled = isEnabled
        self.onToggle = onToggle
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(scopeEmoji)
                .font(.title2)

            Text(isEnabled ? "Showing only \(scopeName) notifications" : "Filtering paused — showing all notifications")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onToggle()
            } label: {
                Text(isEnabled ? "Disable" : "Enable")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }
}

#Preview("Enabled") {
    FocusFilterBannerView(
        scopeName: "Work",
        scopeEmoji: "💼",
        isEnabled: true
    ) {}
}

#Preview("Disabled") {
    FocusFilterBannerView(
        scopeName: "Work",
        scopeEmoji: "💼",
        isEnabled: false
    ) {}
}
