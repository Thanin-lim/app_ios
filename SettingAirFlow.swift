
//
//  SettingAirflow.swift
//  warvba.thanin.test
//
//  Created by warvba on 10/5/2569 BE.
//

import SwiftUI

struct SettingAirflowView: View {

    @EnvironmentObject var state: AppState

    // MARK: Airflow Config

    @State private var host: String = "http://localhost:8080"

    @State private var username: String = "admin"

    @State private var password: String = "admin"

    @State private var refreshInterval: Double = 30

    @State private var enableNotification: Bool = true

    @State private var autoRefresh: Bool = true

    @State private var selectedEnvironment: String = "Production"

    @State private var reconnectStatus: ReconnectStatus = .idle

    enum ReconnectStatus: Equatable {

        case idle
        case loading
        case success
        case failure(String)
    }

    let environments = [
        "Development",
        "Staging",
        "Production"
    ]

    var body: some View {

        ScrollView(showsIndicators: false) {

            VStack(alignment: .leading, spacing: 24) {

                // MARK: Header

                VStack(alignment: .leading, spacing: 8) {

                    Text("Airflow Settings")
                        .font(
                            .system(
                                size: 34,
                                weight: .bold,
                                design: .rounded
                            )
                        )

                    Text(
                        "Manage Airflow connection and monitoring preferences"
                    )
                    .foregroundColor(.secondary)
                }

                // MARK: Connection

                settingsCard {

                    VStack(alignment: .leading, spacing: 18) {

                        sectionTitle(
                            icon: "server.rack",
                            title: "Connection"
                        )

                        AirflowSettingsField(
                            title: "Host",
                            icon: "network",
                            placeholder: "http://localhost:8080",
                            text: $host
                        )

                        AirflowSettingsField(
                            title: "Username",
                            icon: "person.fill",
                            placeholder: "admin",
                            text: $username
                        )

                        AirflowSettingsField(
                            title: "Password",
                            icon: "lock.fill",
                            placeholder: "••••••••",
                            text: $password,
                            isSecure: true
                        )

                        VStack(alignment: .leading, spacing: 8) {

                            Text("Environment")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)

                            Picker(
                                "Environment",
                                selection: $selectedEnvironment
                            ) {

                                ForEach(
                                    environments,
                                    id: \.self
                                ) { env in

                                    Text(env)
                                        .tag(env)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // MARK: Status

                        switch reconnectStatus {

                        case .idle:

                            EmptyView()

                        case .loading:

                            HStack(spacing: 10) {

                                ProgressView()

                                Text("Connecting...")
                                    .foregroundColor(
                                        .secondary
                                    )
                            }

                        case .success:

                            Label(
                                "Connected Successfully",
                                systemImage:
                                    "checkmark.circle.fill"
                            )
                            .foregroundColor(.green)

                        case .failure(let message):

                            Label(
                                message,
                                systemImage:
                                    "xmark.circle.fill"
                            )
                            .foregroundColor(.red)
                        }

                        Button {

                            Task {
                                await reconnectAirflow()
                            }

                        } label: {

                            HStack {

                                Spacer()

                                Label(
                                    "Save & Reconnect",
                                    systemImage:
                                        "arrow.clockwise"
                                )

                                Spacer()
                            }
                            .frame(height: 52)
                            .background(

                                LinearGradient(
                                    colors: [
                                        Color.orange,
                                        Color.orange.opacity(
                                            0.8
                                        )
                                    ],
                                    startPoint:
                                        .leading,
                                    endPoint:
                                        .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // MARK: Monitoring

                settingsCard {

                    VStack(alignment: .leading, spacing: 20) {

                        sectionTitle(
                            icon: "waveform.path.ecg",
                            title: "Monitoring"
                        )

                        VStack(spacing: 18) {

                            settingsToggle(
                                title:
                                    "Enable Notifications",
                                subtitle:
                                    "Receive DAG alerts",
                                isOn:
                                    $enableNotification
                            )

                            settingsToggle(
                                title:
                                    "Auto Refresh",
                                subtitle:
                                    "Refresh DAG status automatically",
                                isOn:
                                    $autoRefresh
                            )
                        }

                        VStack(alignment: .leading, spacing: 12) {

                            HStack {

                                Text(
                                    "Refresh Interval"
                                )
                                .fontWeight(.medium)

                                Spacer()

                                Text(
                                    "\(Int(refreshInterval)) sec"
                                )
                                .foregroundColor(
                                    .orange
                                )
                            }

                            Slider(
                                value:
                                    $refreshInterval,
                                in: 10...120,
                                step: 5
                            )
                            .tint(.orange)
                        }
                    }
                }

                // MARK: System Info

                settingsCard {

                    VStack(alignment: .leading, spacing: 18) {

                        sectionTitle(
                            icon: "info.circle.fill",
                            title: "System"
                        )

                        infoRow(
                            title: "Version",
                            value:
                                "AirflowService v1.0"
                        )

                        infoRow(
                            title: "Environment",
                            value:
                                selectedEnvironment
                        )

                        infoRow(
                            title: "Scheduler",
                            value: "Healthy"
                        )

                        infoRow(
                            title: "Workers",
                            value: "16 Active"
                        )
                    }
                }

                // MARK: Logout

                settingsCard {

                    VStack(alignment: .leading, spacing: 18) {

                        sectionTitle(
                            icon:
                                "person.crop.circle.fill",
                            title: "Account"
                        )

                        Button(role: .destructive) {

                            state.logout()

                        } label: {

                            HStack {

                                Spacer()

                                Label(
                                    "Logout",
                                    systemImage:
                                        "rectangle.portrait.and.arrow.right"
                                )

                                Spacer()
                            }
                            .frame(height: 52)
                            .background(

                                RoundedRectangle(
                                    cornerRadius: 16
                                )
                                .fill(
                                    Color.red.opacity(
                                        0.18
                                    )
                                )
                            )
                            .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 100)
        }
        .background(Color.clear)
        .preferredColorScheme(.dark)
    }

    // MARK: Reconnect

    private func reconnectAirflow() async {

        reconnectStatus = .loading

        try? await Task.sleep(
            nanoseconds: 1_500_000_000
        )

        reconnectStatus = .success

        try? await Task.sleep(
            nanoseconds: 2_000_000_000
        )

        reconnectStatus = .idle
    }
}

// MARK: Settings Card

extension SettingAirflowView {

    @ViewBuilder
    func settingsCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {

        VStack {
            content()
        }
        .padding(22)
        .background(

            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white.opacity(0.05))

                .overlay(

                    RoundedRectangle(
                        cornerRadius: 28
                    )
                    .stroke(
                        Color.white.opacity(0.06),
                        lineWidth: 1
                    )
                )
        )
    }
}

// MARK: Section Title

extension SettingAirflowView {

    @ViewBuilder
    func sectionTitle(
        icon: String,
        title: String
    ) -> some View {

        HStack(spacing: 12) {

            Image(systemName: icon)
                .foregroundColor(.orange)

            Text(title)
                .font(.title3.bold())
        }
    }
}

// MARK: Toggle

extension SettingAirflowView {

    @ViewBuilder
    func settingsToggle(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {

        Toggle(isOn: isOn) {

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(title)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .orange))
    }
}

// MARK: Info Row

extension SettingAirflowView {

    @ViewBuilder
    func infoRow(
        title: String,
        value: String
    ) -> some View {

        HStack {

            Text(title)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: Settings Field

struct AirflowSettingsField: View {

    let title: String

    let icon: String

    let placeholder: String

    @Binding var text: String

    var isSecure: Bool = false

    var body: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)

            HStack(spacing: 12) {

                Image(systemName: icon)
                    .foregroundColor(.orange)
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
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(

                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        Color.white.opacity(0.05)
                    )
            )
        }
    }
}
