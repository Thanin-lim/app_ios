import SwiftUI

struct LoginView: View {

    @EnvironmentObject var state: AppState

    @State private var host: String = "100.106.98.53:30005"

    @State private var accessKey: String = "minio"

    @State private var secretKey: String = "minio123"

    @State private var bucket: String = "mybucket"

    @State private var isLoggingIn: Bool = false

    @State private var errorMessage: String? = nil

    var body: some View {

        ZStack {

            // MARK: Background

            LinearGradient(

                colors: [

                    Color(hex: "#0F2027"),
                    Color(hex: "#203A43"),
                    Color(hex: "#2C5364")
                ],

                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer()

                // MARK: Card

                VStack(spacing: 28) {

                    // MARK: Header

                    VStack(spacing: 14) {

                        ZStack {

                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 76, height: 76)

                            Circle()
                                .stroke(
                                    Color.blue.opacity(0.3),
                                    lineWidth: 1
                                )
                                .frame(width: 76, height: 76)

                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 34))
                                .foregroundColor(.blue)
                        }

                        VStack(spacing: 6) {

                            Text("MinIO Connect")
                                .font(
                                    .system(
                                        size: 28,
                                        weight: .bold,
                                        design: .rounded
                                    )
                                )
                                .foregroundColor(.white)

                            Text("Connect to your MinIO storage server")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }

                    // MARK: Fields

                    VStack(spacing: 14) {

                        LoginField(
                            icon: "server.rack",
                            placeholder: "Host (e.g. localhost:9000)",
                            text: $host
                        )

                        LoginField(
                            icon: "key.fill",
                            placeholder: "Access Key",
                            text: $accessKey
                        )

                        LoginField(
                            icon: "lock.fill",
                            placeholder: "Secret Key",
                            text: $secretKey,
                            isSecure: true
                        )

                        LoginField(
                            icon: "externaldrive.fill",
                            placeholder: "Bucket Name",
                            text: $bucket
                        )
                    }

                    // MARK: Error

                    if let err = errorMessage {

                        HStack(spacing: 8) {

                            Image(systemName: "exclamationmark.triangle.fill")

                            Text(err)
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(10)
                    }

                    // MARK: Login Button

                    Button {

                        Task {

                            await doLogin()
                        }

                    } label: {

                        HStack(spacing: 10) {

                            if isLoggingIn {

                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)

                            } else {

                                Image(systemName: "arrow.right.circle.fill")
                            }

                            Text(
                                isLoggingIn
                                ? "Connecting..."
                                : "Login"
                            )
                            .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(

                            LinearGradient(

                                colors: [

                                    Color.blue,
                                    Color.blue.opacity(0.8)
                                ],

                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(
                            color: Color.blue.opacity(0.35),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoggingIn)
                    .opacity(isLoggingIn ? 0.7 : 1)
                }
                .padding(38)
                .frame(width: 430)
                .background(

                    RoundedRectangle(cornerRadius: 26)

                        .fill(Color(hex: "#182434"))

                        .overlay(

                            RoundedRectangle(cornerRadius: 26)
                                .stroke(
                                    Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )

                        .shadow(
                            color: .black.opacity(0.45),
                            radius: 35,
                            x: 0,
                            y: 14
                        )
                )

                Spacer()

                Text("MinIO Dashboard v1.2")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.28))
                    .padding(.bottom, 22)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: Login

    private func doLogin() async {

        isLoggingIn = true

        errorMessage = nil

        let success = await state.login(

            host: host,
            accessKey: accessKey,
            secretKey: secretKey,
            bucket: bucket
        )

        if !success {

            errorMessage =
            "Connection failed. Check your credentials and host."
        }

        isLoggingIn = false
    }
}

// MARK: - Login Field

struct LoginField: View {

    let icon: String

    let placeholder: String

    @Binding var text: String

    var isSecure: Bool = false

    var body: some View {

        HStack(spacing: 12) {

            Image(systemName: icon)
                .foregroundColor(Color.blue.opacity(0.85))
                .frame(width: 20)

            Group {

                if isSecure {

                    SecureField(
                        placeholder,
                        text: $text
                    )

                } else {

                    TextField(
                        placeholder,
                        text: $text
                    )
                }
            }
            .textFieldStyle(.plain)
            .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(

            RoundedRectangle(cornerRadius: 14)

                .fill(Color.white.opacity(0.06))

                .overlay(

                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
    }
}
