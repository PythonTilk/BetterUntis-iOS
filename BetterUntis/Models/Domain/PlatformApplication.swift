import Foundation

struct PlatformApplicationInfo {
    let applicationId: String
    let applicationName: String
    let version: String
    let platform: String
    let developerId: String
    let privacyPolicyURL: String
    let termsOfServiceURL: String
    let supportEmail: String
    let companyName: String
    let companyAddress: String
    let dataProcessingPurposes: [DataProcessingPurpose]
    let requiredPermissions: [Permission]
}

struct DataProcessingPurpose {
    let id: String
    let name: String
    let description: String
    let isRequired: Bool
    let dataTypes: [String]
    let retentionPeriod: String
    let legalBasis: String
}

struct Permission {
    let id: String
    let name: String
    let description: String
    let isRequired: Bool
    let iosPermissionKey: String?
}

extension PlatformApplicationInfo {
    static let betterUntis = PlatformApplicationInfo(
        applicationId: "BetterUntis-iOS",
        applicationName: "BetterUntis for iOS",
        version: "1.0.0",
        platform: "iOS",
        developerId: "BetterUntis-Platform",
        privacyPolicyURL: "https://betteruntis.com/privacy",
        termsOfServiceURL: "https://betteruntis.com/terms",
        supportEmail: "support@betteruntis.com",
        companyName: "BetterUntis",
        companyAddress: "Educational Technology Solutions, Germany",
        dataProcessingPurposes: [
            DataProcessingPurpose(
                id: "timetable-display",
                name: "Timetable Display",
                description: "Process and display your school timetable data",
                isRequired: true,
                dataTypes: ["lessons", "times", "subjects", "teachers", "rooms"],
                retentionPeriod: "Until account deletion",
                legalBasis: "Legitimate interest for educational services"
            ),
            DataProcessingPurpose(
                id: "absence-tracking",
                name: "Absence Tracking",
                description: "Display student absence information and allow absence reporting",
                isRequired: false,
                dataTypes: ["absence_records", "absence_reasons"],
                retentionPeriod: "Current school year + 1 year",
                legalBasis: "Legitimate interest for educational administration"
            ),
            DataProcessingPurpose(
                id: "exam-management",
                name: "Exam Management",
                description: "Display upcoming exams and exam results",
                isRequired: false,
                dataTypes: ["exam_dates", "exam_subjects", "exam_results"],
                retentionPeriod: "Until graduation + 2 years",
                legalBasis: "Legitimate interest for educational progress tracking"
            ),
            DataProcessingPurpose(
                id: "homework-tracking",
                name: "Homework Tracking",
                description: "Display assigned homework and due dates",
                isRequired: false,
                dataTypes: ["homework_assignments", "due_dates", "completion_status"],
                retentionPeriod: "Current school year",
                legalBasis: "Legitimate interest for educational services"
            )
        ],
        requiredPermissions: [
            Permission(
                id: "camera",
                name: "Camera Access",
                description: "Used for QR code scanning to simplify login setup",
                isRequired: false,
                iosPermissionKey: "NSCameraUsageDescription"
            ),
            Permission(
                id: "biometrics",
                name: "Face ID / Touch ID",
                description: "Secure authentication for protecting your school data",
                isRequired: false,
                iosPermissionKey: "NSFaceIDUsageDescription"
            ),
            Permission(
                id: "calendar",
                name: "Calendar Access",
                description: "Export your timetable to your device calendar",
                isRequired: false,
                iosPermissionKey: "NSCalendarsUsageDescription"
            ),
            Permission(
                id: "reminders",
                name: "Reminders Access",
                description: "Create homework and exam reminders",
                isRequired: false,
                iosPermissionKey: "NSRemindersUsageDescription"
            ),
            Permission(
                id: "contacts",
                name: "Contacts Access",
                description: "Share your timetable with friends and classmates",
                isRequired: false,
                iosPermissionKey: "NSContactsUsageDescription"
            )
        ]
    )
}

struct PlatformApplicationMetadata {
    let buildDate: Date
    let gitCommitHash: String?
    let buildNumber: String
    let minimumOSVersion: String
    let supportedDevices: [String]
    let requiredFeatures: [String]
    let optionalFeatures: [String]

    static let current = PlatformApplicationMetadata(
        buildDate: Date(),
        gitCommitHash: nil, // Will be populated during build
        buildNumber: "1",
        minimumOSVersion: "15.0",
        supportedDevices: ["iPhone", "iPad"],
        requiredFeatures: [
            "Internet connectivity",
            "Secure storage (Keychain)"
        ],
        optionalFeatures: [
            "Camera (for QR scanning)",
            "Biometric authentication",
            "Calendar integration",
            "Reminders integration",
            "Contacts sharing"
        ]
    )
}