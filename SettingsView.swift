import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var state: AppState

    @State private var host: String = ""
    @State private var accessKey: String = ""
    @State private var secretKey: String = ""
    @State private var bucket: String = ""

    @State private var reconnectStatus: ReconnectStatus = .idle

    // MARK: - Focus State

    @FocusState private var focusedField: Field?

    enum Field {
        case host
        case accessKey
        case secretKey
        case bucket
    }

    enum ReconnectStatus: Equatable {
        case idle
        case loading
        case success
        case failure(String)
    }

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 28) {

                // MARK: - Title

                Text("Settings")
                    .font(.system(size: 26, weight: .bold, design: .rounded))

                // MARK: - Connection Profile

                GroupBox {

                    VStack(alignment: .leading, spacing: 16) {

                        Label("Connection Profile", systemImage: "network")
                            .font(.headline)

                        SettingsField(
                            label: "Host",
                            placeholder: "localhost:9000",
                            text: $host,
                            icon: "server.rack"
                        )
                        .focused($focusedField, equals: .host)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .accessKey
                        }

                        SettingsField(
                            label: "Access Key",
                            placeholder: "minioadmin",
                            text: $accessKey,
                            icon: "key.fill"
                        )
                        .focused($focusedField, equals: .accessKey)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .secretKey
                        }

                        SettingsField(
                            label: "Secret Key",
                            placeholder: "••••••••",
                            text: $secretKey,
                            icon: "lock.fill",
                            isSecure: true
                        )
                        .focused($focusedField, equals: .secretKey)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .bucket
                        }

                        SettingsField(
                            label: "Bucket Name",
                            placeholder: "mybucket",
                            text: $bucket,
                            icon: "externaldrive.fill"
                        )
                        .focused($focusedField, equals: .bucket)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                        }

                        // MARK: - Status

                        switch reconnectStatus {

                        case .idle:
                            EmptyView()

                        case .loading:
                            HStack(spacing: 8) {

                                ProgressView()
                                    .controlSize(.small)

                                Text("Connecting...")
                                    .foregroundColor(.secondary)
                            }

                        case .success:
                            Label(
                                "Reconnected successfully!",
                                systemImage: "checkmark.circle.fill"
                            )
                            .foregroundColor(.green)

                        case .failure(let msg):
                            Label(
                                msg,
                                systemImage: "xmark.circle.fill"
                            )
                            .foregroundColor(.red)
                        }

                        // MARK: - Save Button

                        HStack {

                            Spacer()

                            Button {

                                focusedField = nil

                                Task {
                                    await doReconnect()
                                }

                            } label: {

                                Label(
                                    "Save & Reconnect",
                                    systemImage: "arrow.clockwise"
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(reconnectStatus == .loading)
                        }
                    }
                    .padding(4)
                }

                // MARK: - App Info

                GroupBox {

                    VStack(alignment: .leading, spacing: 0) {

                        InfoRow(
                            icon: "info.circle",
                            label: "Version",
                            value: "MinIO Dashboard v1.2"
                        )

                        Divider()
                            .padding(.leading, 36)

                        InfoRow(
                            icon: "externaldrive.connected.to.line.below.fill",
                            label: "Bucket",
                            value: state.bucketName
                        )

                        Divider()
                            .padding(.leading, 36)

                        InfoRow(
                            icon: "server.rack",
                            label: "Host",
                            value: state.host
                        )
                    }
                }

                // MARK: - Danger Zone

                GroupBox {

                    VStack(alignment: .leading, spacing: 12) {

                        Label(
                            "Account",
                            systemImage: "person.crop.circle"
                        )
                        .font(.headline)

                        Button(role: .destructive) {

                            focusedField = nil
                            state.logout()

                        } label: {

                            Label(
                                "Logout",
                                systemImage: "rectangle.portrait.and.arrow.right"
                            )
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .padding(4)
                }

                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
        .toolbar {

            ToolbarItemGroup(placement: .keyboard) {

                Spacer()

                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .onAppear {
            loadCurrentValues()
        }
    }

    // MARK: - Load Current Values

    private func loadCurrentValues() {

        host = state.host
        accessKey = state.accessKey
        secretKey = state.secretKey
        bucket = state.bucketName
    }

    // MARK: - Reconnect

    private func doReconnect() async {

        reconnectStatus = .loading

        await MainActor.run {

            state.host = host
            state.accessKey = accessKey
            state.secretKey = secretKey
            state.bucketName = bucket
        }

        let success = await state.login(
            host: host,
            accessKey: accessKey,
            secretKey: secretKey,
            bucket: bucket
        )

        reconnectStatus = success
        ? .success
        : .failure("Reconnect failed. Check your credentials.")

        if success {

            try? await Task.sleep(
                nanoseconds: 2_000_000_000
            )

            reconnectStatus = .idle
        }
    }
}

// MARK: - Settings Field

struct SettingsField: View {

    let label: String
    let placeholder: String

    @Binding var text: String

    let icon: String

    var isSecure: Bool = false

    var body: some View {

        HStack(spacing: 12) {

            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {

                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                if isSecure {

                    SecureField(
                        placeholder,
                        text: $text
                    )
                    .textFieldStyle(.roundedBorder)

                } else {

                    TextField(
                        placeholder,
                        text: $text
                    )
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                }
            }
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {

    let icon: String
    let label: String
    let value: String

    var body: some View {

        HStack(spacing: 12) {

            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .foregroundColor(.primary)
                .fontWeight(.medium)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }
}
