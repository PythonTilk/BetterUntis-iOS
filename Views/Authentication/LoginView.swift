import SwiftUI
import UIKit
import AVFoundation

struct LoginView: View {
    @EnvironmentObject var userRepository: UserRepository
    @StateObject private var apiClient = UntisAPIClient()

    @State private var serverURL: String = ""
    @State private var schoolName: String = ""
    @State private var username: String = ""
    @State private var password: String = ""

    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showingSchoolSearch: Bool = false
    @State private var showingQRScanner: Bool = false
    @State private var foundSchools: [SchoolInfo] = []

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [brandPrimary, brandSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        headerSection
                        loginFormCard
                        primaryActionsSection
                        secondaryActionsSection

                        if let errorMessage = errorMessage {
                            errorView(errorMessage)
                        }

                        footerSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingSchoolSearch) {
            SchoolSearchView(
                schools: foundSchools,
                onSchoolSelected: { schoolInfo in
                    if let serverUrl = schoolInfo.serverUrl {
                        serverURL = serverUrl
                    }
                    schoolName = schoolInfo.loginName ?? schoolInfo.displayName ?? ""
                    showingSchoolSearch = false
                }
            )
        }
        .sheet(isPresented: $showingQRScanner) {
            QRCodeScannerView { qrCodeString in
                showingQRScanner = false
                parseURLOrQRCode(qrCodeString)
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 140, height: 140)

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 6) {
                Text("BetterUntis")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)

                Text("Sign in to stay in sync with your school day")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var loginFormCard: some View {
        VStack(spacing: 18) {
            formField(
                icon: "network",
                title: "School Server",
                placeholder: "mese.webuntis.com",
                text: $serverURL,
                keyboardType: .URL
            )

            HStack(spacing: 12) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    searchSchools()
                }) {
                    Label("Find my school", systemImage: "magnifyingglass")
                        .foregroundColor(brandPrimary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(RoundedRectangle(cornerRadius: 12).fill(brandPrimary.opacity(0.12)))
                }
                .disabled(isLoading)

                Button(action: pasteFromClipboard) {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .foregroundColor(brandPrimary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(RoundedRectangle(cornerRadius: 12).fill(brandPrimary.opacity(0.06)))
                }
                .disabled(isLoading || !clipboardHasString)
            }

            formField(
                icon: "building.columns",
                title: "School Name",
                placeholder: "IT-Schule Stuttgart",
                text: $schoolName
            )

            formField(
                icon: "person.fill",
                title: "Username",
                placeholder: "Your WebUntis username",
                text: $username
            )

            formField(
                icon: "lock.fill",
                title: "Password",
                placeholder: "Your password",
                text: $password,
                isSecure: true
            )
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color(.systemBackground).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color.white.opacity(0.12))
        )
        .shadow(color: Color.black.opacity(0.15), radius: 24, x: 0, y: 12)
    }

    private var primaryActionsSection: some View {
        VStack(spacing: 16) {
            Button(action: performLogin) {
                HStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }

                    Text(isLoading ? "Signing in" : "Sign in")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [brandPrimary, brandSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .foregroundColor(.white)
                .cornerRadius(18)
                .shadow(color: brandPrimary.opacity(0.3), radius: 12, x: 0, y: 8)
            }
            .disabled(!isLoginFormValid || isLoading)

            Button(action: performAnonymousLogin) {
                Text("Continue as guest")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(brandPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.3)))
            }
            .disabled(isLoading || serverURL.isEmpty || schoolName.isEmpty)
        }
    }

    private var secondaryActionsSection: some View {
        VStack(spacing: 18) {
            Button(action: openQRScanner) {
                Label("Scan QR code", systemImage: "qrcode.viewfinder")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.12)))
            }
            .disabled(isLoading)
        }
    }

    private var footerSection: some View {
        Text("Need help signing in? Reach out to your school's WebUntis administrator.")
            .font(.caption)
            .foregroundColor(.white.opacity(0.75))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundColor(.white)
                .font(.title3)

            VStack(alignment: .leading, spacing: 6) {
                Text("We couldn't sign you in")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))

                Button(action: { errorMessage = nil }) {
                    Text("Dismiss")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(8)
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.red.opacity(0.55)))
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 8)
    }

    // MARK: - Computed Properties
    private var isLoginFormValid: Bool {
        !serverURL.isEmpty && !schoolName.isEmpty && !username.isEmpty && !password.isEmpty
    }

    private var brandPrimary: Color {
        Color(red: 0.95, green: 0.47, blue: 0.12)
    }

    private var brandSecondary: Color {
        Color(red: 0.99, green: 0.67, blue: 0.32)
    }

    private var clipboardHasString: Bool {
        if let text = UIPasteboard.general.string {
            return !text.isEmpty
        }
        return false
    }

    private func formField(
        icon: String,
        title: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(brandPrimary)

                if isSecure {
                    SecureField(placeholder, text: text)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(keyboardType)
                        .disabled(isLoading)
                } else {
                    TextField(placeholder, text: text)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(keyboardType)
                        .disabled(isLoading)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }

    // MARK: - Methods
    private func performLogin() {
        errorMessage = nil

        Task {
            do {
                let _ = try await userRepository.login(
                    server: serverURL,
                    school: schoolName,
                    username: username,
                    password: password
                )

                // Clear sensitive data
                await MainActor.run {
                    password = ""
                }

            } catch {
                await MainActor.run {
                    errorMessage = "Login failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func performAnonymousLogin() {
        errorMessage = nil

        Task {
            do {
                let _ = try await userRepository.loginAnonymously(
                    server: serverURL,
                    school: schoolName
                )
            } catch {
                await MainActor.run {
                    errorMessage = "Anonymous login failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func searchSchools() {
        guard !serverURL.isEmpty else {
            errorMessage = "Please enter a search term"
            return
        }

        errorMessage = nil

        Task {
            do {
                let schools = try await apiClient.searchSchools(search: serverURL)
                await MainActor.run {
                    foundSchools = schools
                    showingSchoolSearch = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "School search failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func openQRScanner() {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            errorMessage = nil
            showingQRScanner = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.errorMessage = nil
                        self.showingQRScanner = true
                    } else {
                        self.errorMessage = "Camera access is required to scan QR codes. Enable it in Settings."
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = "Camera access is required to scan QR codes. Enable it in Settings."
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        @unknown default:
            showingQRScanner = false
        }
    }

    private func pasteFromClipboard() {
        guard let clipboardString = UIPasteboard.general.string, !clipboardString.isEmpty else {
            errorMessage = "Clipboard is empty"
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        parseURLOrQRCode(clipboardString)
    }

    private func parseURLOrQRCode(_ input: String) {
        if WebUntisURLParser.isWebUntisQRCode(input),
           let loginData = WebUntisURLParser.parseQRCode(input) {
            applyLoginData(loginData)
            return
        }

        if WebUntisURLParser.isWebUntisURL(input),
           let loginData = WebUntisURLParser.parseWebUntisURL(input) {
            applyLoginData(loginData)
            return
        }

        errorMessage = "Invalid WebUntis URL or QR code"
    }

    private func applyLoginData(_ loginData: WebUntisLoginData) {
        serverURL = loginData.server
        schoolName = loginData.school

        if let username = loginData.username {
            self.username = username
        }

        if let key = loginData.key {
            self.password = key
        }

        if loginData.isQRCode {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            errorMessage = "✅ QR code detected. Review and sign in."
        } else {
            errorMessage = nil
        }
    }
}

// MARK: - School Search View
struct SchoolSearchView: View {
    let schools: [SchoolInfo]
    let onSchoolSelected: (SchoolInfo) -> Void

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List {
                if schools.isEmpty {
                    Text("No schools found")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(schools, id: \.schoolId) { school in
                        SchoolRowView(school: school) {
                            onSchoolSelected(school)
                        }
                    }
                }
            }
            .navigationTitle("Select School")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - School Row View
struct SchoolRowView: View {
    let school: SchoolInfo
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(school.displayName ?? school.loginName ?? "Unknown School")
                    .font(.headline)
                    .foregroundColor(.primary)

                if let address = school.address, !address.isEmpty {
                    Text(address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let serverUrl = school.serverUrl {
                    Text(serverUrl)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    LoginView()
        .environmentObject(UserRepository())
}
