# Requirements Document

## Introduction

The BetterUntis iOS app is experiencing Swift concurrency issues where data models marked as `Sendable` are causing "Main actor-isolated conformance" errors. These errors occur when types that should be `Sendable` are being used in async contexts but are getting isolated to the main actor, preventing them from satisfying the `Sendable` requirement for generic type parameters in async functions.

## Requirements

### Requirement 1

**User Story:** As a developer, I want all API data models to properly conform to Sendable requirements, so that async API calls work without concurrency warnings or errors.

#### Acceptance Criteria

1. WHEN compiling the UntisAPIClient.swift file THEN the system SHALL NOT produce any "Main actor-isolated conformance" errors
2. WHEN using RequestData in async contexts THEN the system SHALL properly encode without Sendable conformance issues
3. WHEN using BaseResponse<T> in async contexts THEN the system SHALL properly decode without Sendable conformance issues
4. WHEN using result types (AuthTokenResult, UserDataResult, TimetableResult, etc.) in async contexts THEN the system SHALL handle them without Sendable conformance issues

### Requirement 2

**User Story:** As a developer, I want the AnyEncodable wrapper to work correctly with Swift's strict concurrency model, so that parameter encoding doesn't cause concurrency issues.

#### Acceptance Criteria

1. WHEN using AnyEncodable with various parameter types THEN the system SHALL properly encode without main actor isolation issues
2. WHEN AnyEncodable wraps Sendable types THEN the system SHALL maintain Sendable conformance
3. WHEN AnyEncodable is used in async parameter encoding THEN the system SHALL not require main actor isolation

### Requirement 3

**User Story:** As a developer, I want all domain models to be properly thread-safe, so that they can be used across different actors without concurrency issues.

#### Acceptance Criteria

1. WHEN domain models are used in async/await contexts THEN the system SHALL not require main actor isolation
2. WHEN domain models are passed between different actors THEN the system SHALL maintain data integrity
3. WHEN domain models implement Sendable THEN the system SHALL properly validate their thread-safety at compile time

### Requirement 4

**User Story:** As a developer, I want the API client to work seamlessly with SwiftUI and other UI frameworks, so that data can be safely passed between background and main threads.

#### Acceptance Criteria

1. WHEN API responses are received on background threads THEN the system SHALL allow safe transfer to the main actor for UI updates
2. WHEN using the API client from SwiftUI views THEN the system SHALL not produce concurrency warnings
3. WHEN API data is bound to SwiftUI views THEN the system SHALL properly handle actor isolation