import SwiftUI

struct AirflowLoginView: View {
    
    @EnvironmentObject var state: AppState
    
    // MARK: - Form State
    
    @State private var host: String = "http://100.106.98.53:30007"
    
    @State private var username: String = "admin"
    
    @State private var password: String = "admin"
    
    @State private var isLoggingIn: Bool = false
    
    @State private var errorMessage: String? = nil
    
    // MARK: - Keyboard Focus
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case host
        case username
        case password
    }
    
    // MARK: - Body
    
    var body: some View {
        
        GeometryReader { geo in
            
            let isMobile = geo.size.width < 700
            
            ZStack {
                
                // MARK: Background
                
                LinearGradient(
                    colors: [
                        Color(hex: "#0B1120"),
                        Color(hex: "#111827"),
                        Color(hex: "#1F2937")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // MARK: Glow Effects
                
                Circle()
                    .fill(Color.orange.opacity(0.18))
                    .frame(width: 260)
                    .blur(radius: 70)
                    .offset(x: -150, y: -250)
                
                Circle()
                    .fill(Color.blue.opacity(0.18))
                    .frame(width: 280)
                    .blur(radius: 80)
                    .offset(x: 180, y: 260)
                
                // MARK: Content
                
                ScrollView(showsIndicators: false) {
                    
                    VStack {
                        
                        Spacer(minLength: 40)
                        
                        Group {
                            
                            if isMobile {
                                
                                VStack(spacing: 0) {
                                    
                                    airflowLeftPanel
                                    
                                    Divider()
                                        .background(
                                            Color.white.opacity(0.08)
                                        )
                                    
                                    airflowRightPanel
                                }
                                
                            } else {
                                
                                HStack(spacing: 0) {
                                    
                                    airflowLeftPanel
                                    
                                    Divider()
                                        .background(
                                            Color.white.opacity(0.08)
                                        )
                                    
                                    airflowRightPanel
                                }
                            }
                        }
                        .frame(
                            maxWidth: isMobile
                            ? .infinity
                            : 980
                        )
                        .background(
                            
                            RoundedRectangle(cornerRadius: 32)
                            
                                .fill(Color(hex: "#111827"))
                            
                                .overlay(
                                    
                                    RoundedRectangle(cornerRadius: 32)
                                        .stroke(
                                            Color.white.opacity(0.06),
                                            lineWidth: 1
                                        )
                                )
                            
                                .shadow(
                                    color: .black.opacity(0.45),
                                    radius: 40,
                                    x: 0,
                                    y: 20
                                )
                        )
                        .padding(.horizontal, isMobile ? 18 : 24)
                        
                        Spacer(minLength: 120)
                    }
                }
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
        }
    }
    
    // MARK: - Left Panel
    
    private var airflowLeftPanel: some View {
        
        VStack(alignment: .leading, spacing: 24) {
            
            VStack(alignment: .leading, spacing: 18) {
                
                HStack(spacing: 14) {
                    
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 72, height: 72)
                        .overlay(
                            
                            Image(systemName: "wind")
                                .font(.system(size: 34))
                                .foregroundColor(.orange)
                        )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        
                        Text("Apache Airflow")
                            .font(
                                .system(
                                    size: 30,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .foregroundColor(.white)
                        
                        Text("Workflow Management Platform")
                            .foregroundColor(
                                .white.opacity(0.6)
                            )
                    }
                }
                
                Text(
                    "Monitor DAGs, manage workflows, schedule pipelines, and control your orchestration platform."
                )
                .foregroundColor(.white.opacity(0.72))
                .lineSpacing(4)
                
                VStack(alignment: .leading, spacing: 14) {
                    
                    FeatureRow(
                        icon: "checkmark.seal.fill",
                        text: "DAG Monitoring"
                    )
                    
                    FeatureRow(
                        icon: "checkmark.seal.fill",
                        text: "Task Logs & Retry"
                    )
                    
                    FeatureRow(
                        icon: "checkmark.seal.fill",
                        text: "Scheduler Overview"
                    )
                    
                    FeatureRow(
                        icon: "checkmark.seal.fill",
                        text: "Trigger & Pause DAGs"
                    )
                }
                .padding(.top, 10)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.18),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    // MARK: - Right Panel
    
    private var airflowRightPanel: some View {
        
        VStack(spacing: 24) {
            
            VStack(spacing: 10) {
                
                Text("Sign In")
                    .font(
                        .system(
                            size: 28,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundColor(.white)
                
                Text("Connect to your Airflow server")
                    .foregroundColor(.white.opacity(0.55))
            }
            
            VStack(spacing: 14) {
                
                AirflowField(
                    icon: "server.rack",
                    placeholder: "Airflow Host",
                    text: $host
                )
                .focused($focusedField, equals: .host)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .username
                }
                
                AirflowField(
                    icon: "person.fill",
                    placeholder: "Username",
                    text: $username
                )
                .focused($focusedField, equals: .username)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .password
                }
                
                AirflowField(
                    icon: "lock.fill",
                    placeholder: "Password",
                    text: $password,
                    isSecure: true
                )
                .focused($focusedField, equals: .password)
                .submitLabel(.done)
                .onSubmit {
                    
                    focusedField = nil
                    
                    Task {
                        await doLogin()
                    }
                }
            }
            
            // MARK: Error
            
            if let err = errorMessage {
                
                HStack(spacing: 8) {
                    
                    Image(
                        systemName:
                            "exclamationmark.triangle.fill"
                    )
                    
                    Text(err)
                        .font(.caption)
                }
                .foregroundColor(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .background(Color.red.opacity(0.12))
                .cornerRadius(12)
            }
            
            // MARK: Login Button
            
            Button {
                
                focusedField = nil
                
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
                        
                        Image(systemName: "arrow.right")
                    }
                    
                    Text(
                        isLoggingIn
                        ? "Connecting..."
                        : "Login to Airflow"
                    )
                    .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    
                    LinearGradient(
                        
                        colors: [
                            Color.orange,
                            Color.orange.opacity(0.8)
                        ],
                        
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(14)
                .shadow(
                    color: Color.orange.opacity(0.35),
                    radius: 12,
                    x: 0,
                    y: 6
                )
            }
            .buttonStyle(.plain)
            .disabled(isLoggingIn)
            .opacity(isLoggingIn ? 0.7 : 1)
        }
        .padding(32)
        .frame(maxWidth: 420)
    }
    
    // MARK: - Login
    
    private func doLogin() async {
        
        isLoggingIn = true
        
        errorMessage = nil
        
        AirflowAPIService.shared.configure(
            host: host,
            username: username,
            password: password
        )
        
        do {
            
            _ = try await AirflowAPIService.shared.fetchDAGs()
            
            await MainActor.run {
                
                state.isLoggedIn = true
            }
            
        } catch {
            
            errorMessage =
            "Connection failed. Check Airflow host and credentials."
        }
        
        isLoggingIn = false
    }
}

// MARK: - Airflow Field

struct AirflowField: View {

    let icon: String

    let placeholder: String

    @Binding var text: String

    var isSecure: Bool = false

    var body: some View {

        HStack(spacing: 12) {

            Image(systemName: icon)
                .foregroundColor(
                    Color.orange.opacity(0.9)
                )
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
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(

            RoundedRectangle(cornerRadius: 14)

                .fill(Color.white.opacity(0.05))

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

// MARK: - Feature Row

struct FeatureRow: View {

    let icon: String

    let text: String

    var body: some View {

        HStack(spacing: 12) {

            Image(systemName: icon)
                .foregroundColor(.orange)

            Text(text)
                .foregroundColor(
                    .white.opacity(0.82)
                )
        }
    }
}
