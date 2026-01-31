import ComposableArchitecture
import HubWorksCore
import SwiftUI

public struct AuthView: View {
    @Bindable var store: StoreOf<AuthFeature>

    public init(store: StoreOf<AuthFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            if let deviceFlow = store.deviceFlowStatus {
                deviceFlowView(deviceFlow)
            } else {
                signInView
            }
        }
    }

    // MARK: - Sign In View

    private var signInView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                Text("HubWorks")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Stay on top of your GitHub notifications")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 16) {
                if let error = store.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                // Primary: Web Flow (iOS/macOS)
                #if !os(watchOS)
                Button {
                    store.send(.signInTapped)
                } label: {
                    HStack {
                        if store.isAuthenticating, store.deviceFlowStatus == nil {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        Text(store.isAuthenticating ? "Signing in..." : "Sign in with GitHub")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(store.isAuthenticating)
                #endif

                // Secondary: Device Flow (all platforms, especially watchOS)
                Button {
                    store.send(.signInWithDeviceFlowTapped)
                } label: {
                    HStack {
                        Image(systemName: "qrcode")
                        Text("Sign in with code")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    #if os(watchOS)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                    #else
                        .background(Color.secondary.opacity(0.1))
                        .foregroundStyle(.primary)
                    #endif
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(store.isAuthenticating)

                Text("HubWorks needs access to your GitHub notifications to show them here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .padding()
    }

    // MARK: - Device Flow View

    private func deviceFlowView(_ deviceFlow: AuthFeature.State.DeviceFlowState) -> some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Enter this code on GitHub")
                    .font(.headline)

                Text("Visit the URL below on any device and enter this code:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Code display
            VStack(spacing: 8) {
                Text(deviceFlow.userCode)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .tracking(4)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    #if os(iOS)
                    UIPasteboard.general.string = deviceFlow.userCode
                    #elseif os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(deviceFlow.userCode, forType: .string)
                    #endif
                } label: {
                    Label("Copy code", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            // URL
            VStack(spacing: 8) {
                Text(deviceFlow.verificationUri)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.blue)

                #if !os(watchOS)
                if let url = URL(string: deviceFlow.verificationUri) {
                    Link(destination: url) {
                        Label("Open in browser", systemImage: "safari")
                            .font(.caption)
                    }
                }
                #endif
            }

            // Expiration timer
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let remaining = deviceFlow.expiresAt.timeIntervalSinceNow
                if remaining > 0 {
                    Text("Code expires in \(Int(remaining / 60)):\(String(format: "%02d", Int(remaining) % 60))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Code expired")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            // Waiting indicator
            HStack {
                ProgressView()
                Text("Waiting for authorization...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Cancel button
            Button {
                store.send(.cancelAuthTapped)
            } label: {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

#Preview("Sign In") {
    AuthView(
        store: Store(initialState: AuthFeature.State()) {
            AuthFeature()
        }
    )
}

#Preview("Device Flow") {
    AuthView(
        store: Store(
            initialState: AuthFeature.State(
                isAuthenticating: true,
                deviceFlowStatus: .init(
                    userCode: "ABCD-1234",
                    verificationUri: "https://github.com/login/device",
                    expiresAt: Date.now.addingTimeInterval(900)
                )
            )
        ) {
            AuthFeature()
        }
    )
}
