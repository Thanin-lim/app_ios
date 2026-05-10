import SwiftUI

struct ContentView: View {

    @StateObject private var state = AppState()

    // MARK: Current Login Page

    @State private var selectedPage: LoginPage = .minio

    var body: some View {

        Group {

            // MARK: After Login

            if state.isLoggedIn {

                switch selectedPage {

                case .minio:

                    MainView()

                case .airflow:

                    AirFlowService()
                }

            } else {

                // MARK: Login Pages

                ZStack(alignment: .bottom) {

                    TabView(selection: $selectedPage) {

                        // MARK: MinIO Login

                        LoginView()
                            .tag(LoginPage.minio)

                        // MARK: Airflow Login

                        AirflowLoginView()
                            .tag(LoginPage.airflow)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: selectedPage
                    )

                    // MARK: Bottom Switch

                    HStack(spacing: 12) {

                        // MARK: MinIO Button

                        Button {

                            withAnimation {

                                selectedPage = .minio
                            }

                        } label: {

                            HStack(spacing: 8) {

                                Image(
                                    systemName:
                                        "externaldrive.fill"
                                )

                                Text("MinIO")
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(
                                selectedPage == .minio
                                ? .black
                                : .white
                            )
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(

                                Capsule()
                                    .fill(
                                        selectedPage == .minio
                                        ? Color.white
                                        : Color.white.opacity(
                                            0.12
                                        )
                                    )
                            )
                        }
                        .buttonStyle(.plain)

                        // MARK: Airflow Button

                        Button {

                            withAnimation {

                                selectedPage = .airflow
                            }

                        } label: {

                            HStack(spacing: 8) {

                                Image(systemName: "wind")

                                Text("Airflow")
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(
                                selectedPage == .airflow
                                ? .black
                                : .white
                            )
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(

                                Capsule()
                                    .fill(
                                        selectedPage == .airflow
                                        ? Color.white
                                        : Color.white.opacity(
                                            0.12
                                        )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(

                        Capsule()
                            .fill(Color.black.opacity(0.35))

                            .overlay(

                                Capsule()
                                    .stroke(
                                        Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )

                            .shadow(
                                color: .black.opacity(0.35),
                                radius: 12,
                                x: 0,
                                y: 8
                            )
                    )
                    .padding(.bottom, 30)
                }
            }
        }
        .environmentObject(state)

        #if os(macOS)
        .frame(minWidth: 1200, minHeight: 750)
        #endif
    }
}

// MARK: - Login Page

enum LoginPage {

    case minio
    case airflow
}
