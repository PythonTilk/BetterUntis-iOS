# BetterUntis iOS

A native iOS implementation of BetterUntis - an alternative mobile client for the Untis timetable system.

## Overview

This iOS version provides a clean, native Swift implementation of the BetterUntis app with SwiftUI for modern iOS experiences. It maintains feature parity with the Android version while leveraging iOS-specific capabilities.

## Features

- **Modern SwiftUI Interface** - Clean, native iOS design following Apple's Human Interface Guidelines
- **Custom WeekView Component** - Smooth, interactive timetable display optimized for iOS
- **Multi-Account Support** - Secure management of multiple Untis accounts using Keychain
- **Info Center** - Messages, homework, exams, and absence management
- **RoomFinder** - Find available rooms by date and time
- **Offline Caching** - Core Data integration for offline timetable access
- **Background Refresh** - Keep timetables updated automatically

## Architecture

### Tech Stack
- **SwiftUI** - Modern declarative UI framework
- **Core Data** - Local data persistence and caching
- **Alamofire** - HTTP networking for Untis API communication
- **Keychain Services** - Secure credential storage

### Architecture Pattern
- **MVVM** - Model-View-ViewModel pattern with SwiftUI
- **Repository Pattern** - Data access abstraction layer
- **Combine** - Reactive programming for data flow

### Project Structure
```
BetterUntis/
├── Models/
│   ├── API/           # Request/Response models
│   ├── Domain/        # Business logic models
│   └── CoreData/      # Core Data entities
├── Views/
│   ├── Authentication/   # Login and auth flows
│   ├── Timetable/       # Week view and timetable UI
│   ├── InfoCenter/      # Messages, homework, exams
│   ├── RoomFinder/      # Room availability search
│   └── Settings/        # App preferences and account management
├── Services/
│   └── UntisAPIClient   # Untis API communication
├── Repositories/
│   ├── UserRepository      # User account management
│   ├── TimetableRepository # Timetable data management
│   └── InfoCenterRepository # Info center data
├── Utilities/
│   └── KeychainManager  # Secure storage utilities
└── Resources/
```

## Key Components

### WeekView Component
The heart of the app - a custom SwiftUI component that displays the weekly timetable:
- Smooth scrolling in both directions
- Touch interaction for period details
- Time-based layout with proper scaling
- Color-coded periods matching Untis data
- Responsive design for different screen sizes

### UntisAPIClient
Handles all communication with Untis servers:
- JSON-RPC API calls
- Authentication management (app shared secrets, auth tokens)
- Error handling and network resilience
- Async/await pattern for modern Swift

### Data Management
- **Core Data** for local storage and caching
- **Repository pattern** for data access abstraction
- **Keychain** for secure credential storage
- Smart caching with timestamp-based invalidation

### Authentication Flow
1. School search and selection
2. Username/password authentication
3. App shared secret generation
4. Secure credential storage in Keychain
5. Multi-account support with easy switching

## Setup and Installation

### Requirements
- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+

### Dependencies
```swift
.package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0")
.package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0")
```

### Installation
1. Clone the repository
2. Open `BetterUntis.xcodeproj` in Xcode
3. Ensure all dependencies are resolved
4. Build and run on iOS Simulator or device

## API Compatibility

This iOS version maintains full compatibility with the Untis WebUntis API:
- JSON-RPC 2.0 protocol
- All authentication methods (getAppSharedSecret, getAuthToken)
- Timetable data fetching (getTimetable2017, getPeriodData2017)
- Info center endpoints (getMessagesOfDay2017, getHomeWork2017, getExams2017)
- Master data synchronization

## Development Status

### Completed Features ✅
- [x] Project structure and dependencies
- [x] Swift models for Untis API
- [x] UntisAPIClient implementation
- [x] Keychain credential management
- [x] Core Data stack and persistence
- [x] Repository pattern implementation
- [x] Custom WeekView component
- [x] Authentication flow and login UI
- [x] Main tab navigation
- [x] Info Center implementation
- [x] RoomFinder implementation
- [x] Settings and account management

### TODO - Future Enhancements 🚧
- [ ] iOS Widgets support
- [ ] Siri Shortcuts integration
- [ ] Background app refresh
- [ ] Push notifications
- [ ] Calendar export functionality
- [ ] QR code login scanning
- [ ] Accessibility improvements (VoiceOver)
- [ ] iPad-optimized layouts
- [ ] macOS Catalyst support
- [ ] Unit and UI test coverage

## Comparison with Android Version

### Shared Features
- Full Untis API compatibility
- Multi-account support
- Offline caching
- Info Center functionality
- RoomFinder capability

### iOS-Specific Advantages
- Native SwiftUI performance
- iOS design language compliance
- Keychain secure storage
- Potential for iOS-only features (Widgets, Shortcuts, etc.)

### Architecture Differences
- SwiftUI vs. Jetpack Compose
- Core Data vs. Room database
- URLSession/Alamofire vs. Ktor
- Keychain vs. Android Keystore

## Contributing

When contributing to the iOS version:
1. Follow Swift style guidelines
2. Use SwiftUI best practices
3. Maintain architectural patterns
4. Ensure iOS design compliance
5. Test on multiple device sizes
6. Consider accessibility requirements

## License

This project maintains the same license as the original BetterUntis Android application.

## Acknowledgments

- Original BetterUntis Android app by SapuSeven
- Untis/WebUntis API by Untis GmbH
- iOS development community for SwiftUI best practices