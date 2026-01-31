import Foundation
import SwiftData
import SwiftUI

@Model
public final class NotificationScope {
    // CloudKit doesn't support unique constraints - we handle uniqueness in app logic
    public var id: String = UUID().uuidString

    public var name: String = ""
    public var emoji: String = "bell"
    public var colorHex: String = "#007AFF"
    public var focusModeIdentifier: String?

    // CloudKit requires optional relationships
    public var accounts: [GitHubAccount]?

    @Relationship(deleteRule: .cascade, inverse: \NotificationRule.scope)
    public var rules: [NotificationRule]?

    public var quietHoursEnabled: Bool = false
    public var quietHoursStart: Int = 22
    public var quietHoursEnd: Int = 8
    public var quietHoursDays: [Int] = [1, 2, 3, 4, 5, 6, 7]

    public var isDefault: Bool = false
    public var sortOrder: Int = 0
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    public init(
        id: String = UUID().uuidString,
        name: String,
        emoji: String = "bell",
        colorHex: String = "#007AFF",
        focusModeIdentifier: String? = nil,
        accounts: [GitHubAccount]? = [],
        rules: [NotificationRule]? = [],
        quietHoursEnabled: Bool = false,
        quietHoursStart: Int = 22,
        quietHoursEnd: Int = 8,
        quietHoursDays: [Int] = [1, 2, 3, 4, 5, 6, 7],
        isDefault: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.focusModeIdentifier = focusModeIdentifier
        self.accounts = accounts
        self.rules = rules
        self.quietHoursEnabled = quietHoursEnabled
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.quietHoursDays = quietHoursDays
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension NotificationScope {
    public var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    public var isInQuietHours: Bool {
        guard quietHoursEnabled else { return false }

        let calendar = Calendar.current
        let now = Date.now
        let currentHour = calendar.component(.hour, from: now)
        let currentWeekday = calendar.component(.weekday, from: now)

        guard quietHoursDays.contains(currentWeekday) else { return false }

        if quietHoursStart < quietHoursEnd {
            return currentHour >= quietHoursStart && currentHour < quietHoursEnd
        } else {
            return currentHour >= quietHoursStart || currentHour < quietHoursEnd
        }
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
