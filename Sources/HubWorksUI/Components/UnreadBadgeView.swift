import SwiftUI

public struct UnreadBadgeView: View {
    public let count: Int
    public let maxDisplayCount: Int

    public init(count: Int, maxDisplayCount: Int = 99) {
        self.count = count
        self.maxDisplayCount = maxDisplayCount
    }

    public var body: some View {
        if count > 0 {
            Text(displayText)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(.red)
                )
        }
    }

    private var displayText: String {
        if count > maxDisplayCount {
            "\(maxDisplayCount)+"
        } else {
            "\(count)"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack {
            Text("Inbox")
            Spacer()
            UnreadBadgeView(count: 5)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))

        HStack {
            Text("Mentions")
            Spacer()
            UnreadBadgeView(count: 123)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))

        HStack {
            Text("All Read")
            Spacer()
            UnreadBadgeView(count: 0)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
    }
    .padding()
}
