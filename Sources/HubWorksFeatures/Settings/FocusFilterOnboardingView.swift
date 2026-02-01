import SwiftUI

public struct FocusFilterOnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "moon.stars.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue.gradient)

                    VStack(spacing: 8) {
                        Text("Focus Filters")
                            .font(.largeTitle.bold())

                        Text("Filter notifications by Focus mode")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 32)

                // Use Cases
                VStack(alignment: .leading, spacing: 24) {
                    FeatureCard(
                        icon: "briefcase.circle.fill",
                        iconColor: .orange,
                        title: "Work Focus",
                        description: "Show only work notifications during work hours. Filter by company organizations."
                    )

                    FeatureCard(
                        icon: "house.circle.fill",
                        iconColor: .green,
                        title: "Personal Focus",
                        description: "See personal project notifications outside work hours. Perfect for side projects."
                    )

                    FeatureCard(
                        icon: "moon.zzz.circle.fill",
                        iconColor: .indigo,
                        title: "Sleep Focus",
                        description: "Silence all notifications during sleep. Wake up to a focused inbox."
                    )
                }
                .padding(.horizontal)

                // How It Works
                VStack(alignment: .leading, spacing: 16) {
                    Text("How It Works")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        HowItWorksStep(
                            number: 1,
                            text: "Create a scope and select organizations or repositories"
                        )

                        HowItWorksStep(
                            number: 2,
                            text: "Open iOS Settings → Focus → [Your Focus Mode]"
                        )

                        HowItWorksStep(
                            number: 3,
                            text: "Tap 'Add Filter' and select HubWorks"
                        )

                        HowItWorksStep(
                            number: 4,
                            text: "Choose which scope to use for this Focus mode"
                        )
                    }
                }
                .padding(.horizontal)

                // CTA Button
                Button {
                    dismiss()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.gradient)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Focus Filters")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
    }
}

// MARK: - Supporting Views

private struct FeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(iconColor.gradient)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct HowItWorksStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.blue.gradient)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        FocusFilterOnboardingView()
    }
}
