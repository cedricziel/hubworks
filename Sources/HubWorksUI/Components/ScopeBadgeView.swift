import SwiftUI

public struct ScopeBadgeView: View {
    public let name: String
    public let emoji: String
    public let color: Color
    public let isSelected: Bool

    public init(
        name: String,
        emoji: String,
        color: Color,
        isSelected: Bool = false
    ) {
        self.name = name
        self.emoji = emoji
        self.color = color
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: 6) {
            Text(emoji)
                .font(.caption)

            Text(name)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? color.opacity(0.2) : Color.secondary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? color : Color.clear, lineWidth: 1)
        )
    }
}

#Preview {
    HStack {
        ScopeBadgeView(
            name: "Work",
            emoji: "💼",
            color: .blue,
            isSelected: true
        )

        ScopeBadgeView(
            name: "Personal",
            emoji: "🏠",
            color: .green,
            isSelected: false
        )

        ScopeBadgeView(
            name: "OSS",
            emoji: "🌍",
            color: .orange,
            isSelected: false
        )
    }
    .padding()
}
