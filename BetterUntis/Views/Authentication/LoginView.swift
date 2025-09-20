import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LoginView: View {
    @EnvironmentObject var userRepository: UserRepository
    private let apiClient = UntisAPIClient()

    @State private var serverURL: String = ""
    @State private var schoolName: String = ""
    @State private var username: String = ""
    @State private var password: String = ""

    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showingSchoolSearch: Bool = false
    @State private var foundSchools: [SchoolInfo] = []
    @State private var showingQRScanner: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App logo and title
                    headerSection

                    // Login form
                    loginFormSection

                    // Action buttons
                    actionButtonsSection

                    // Additional options
                    additionalOptionsSection

                    // Error message
                    if let errorMessage = errorMessage {
                        errorView(errorMessage)
                    }

                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .navigationBarHidden(true)
            .background(Color(UIColor.systemGroupedBackground))
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Prevent iPad split view
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
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 4) {
                Text("BetterUntis")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your timetable, reimagined")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 40)
    }

    // MARK: - Login Form Section
    private var loginFormSection: some View {
        VStack(spacing: 16) {
            // Server URL field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("School Server")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Button("Search Schools") {
                        searchSchools()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .disabled(isLoading)
                }

                TextField("e.g., school.webuntis.com", text: $serverURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                    .disabled(isLoading)
            }

            // School name field
            VStack(alignment: .leading, spacing: 8) {
                Text("School Name")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("School identifier", text: $schoolName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disabled(isLoading)
            }

            // Username field
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("Your username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disabled(isLoading)
            }

            // Password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)

                SecureField("Your password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isLoading)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Login button
            Button(action: performLogin) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }

                    Text(isLoading ? "Logging in..." : "Login")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(loginButtonColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(!isLoginFormValid || isLoading)

            // Anonymous login button
            Button("Continue as Guest") {
                performAnonymousLogin()
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            .disabled(isLoading || serverURL.isEmpty || schoolName.isEmpty)
        }
    }

    // MARK: - Additional Options Section
    private var additionalOptionsSection: some View {
        VStack(spacing: 16) {
            // URL paste button
            Button(action: pasteAndParseURL) {
                HStack {
                    Image(systemName: "link")
                    Text("Paste WebUntis URL")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .disabled(isLoading)

            // QR Code scan button
            Button(action: {
                showingQRScanner = true
            }) {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                    Text("Scan QR Code")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .disabled(isLoading)

            // Test API button (debug only)
            #if DEBUG
            Button("🧪 Test APIs") {
                Task {
                    await APITester.shared.runAllTests()
                }
            }
            .font(.caption)
            .foregroundColor(.purple)
            .disabled(isLoading)
            #endif

            // Help text
            Text("Having trouble? Check your school's WebUntis settings or contact your school administrator.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.red)

            Spacer()

            Button("Dismiss") {
                errorMessage = nil
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Computed Properties
    private var isLoginFormValid: Bool {
        !serverURL.isEmpty && !schoolName.isEmpty && !username.isEmpty && !password.isEmpty
    }

    private var loginButtonColor: Color {
        isLoginFormValid ? .blue : .gray
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
                let schoolDicts = try await apiClient.searchSchools(query: serverURL)
                let schools = schoolDicts.compactMap { dict -> SchoolInfo? in
                    return SchoolInfo(
                        schoolId: dict["schoolId"] as? String,
                        loginName: dict["loginName"] as? String,
                        displayName: dict["displayName"] as? String,
                        serverUrl: dict["serverUrl"] as? String,
                        mobileServiceUrl: dict["mobileServiceUrl"] as? String,
                        useMobileServiceUrlAndroid: dict["useMobileServiceUrlAndroid"] as? Bool,
                        address: dict["address"] as? String
                    )
                }
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

    // MARK: - URL and QR Code Parsing

    private func pasteAndParseURL() {
        #if canImport(UIKit)
        if let clipboardString = UIPasteboard.general.string {
            parseURLOrQRCode(clipboardString)
        } else {
            errorMessage = "No URL found in clipboard"
        }
        #else
        errorMessage = "Clipboard access not available"
        #endif
    }

    private func parseURLOrQRCode(_ input: String) {
        // Try parsing as QR code first
        if WebUntisURLParser.isWebUntisQRCode(input) {
            if let loginData = WebUntisURLParser.parseQRCode(input) {
                populateLoginFields(from: loginData)
                return
            }
        }

        // Try parsing as WebUntis URL
        if WebUntisURLParser.isWebUntisURL(input) {
            if let loginData = WebUntisURLParser.parseWebUntisURL(input) {
                populateLoginFields(from: loginData)
                return
            }
        }

        errorMessage = "Invalid WebUntis URL or QR code format"
    }

    private func populateLoginFields(from loginData: WebUntisLoginData) {
        serverURL = loginData.server
        schoolName = loginData.school

        if let user = loginData.username {
            username = user
        }

        // Clear any previous error
        errorMessage = nil

        // Show success message
        if loginData.isQRCode {
            errorMessage = "✅ QR code data loaded successfully"
        } else {
            errorMessage = "✅ URL parsed successfully"
        }

        // Clear success message after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.errorMessage?.hasPrefix("✅") == true {
                self.errorMessage = nil
            }
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