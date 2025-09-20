# Design Document

## Overview

The Swift concurrency issues in BetterUntis are caused by improper Sendable conformance and main actor isolation conflicts. The solution involves ensuring all data models are properly marked as Sendable, removing unnecessary main actor isolation, and restructuring the AnyEncodable wrapper to work correctly with Swift's strict concurrency model.

## Architecture

The fix will focus on three main areas:

1. **Data Model Sendable Conformance**: Ensure all API and domain models properly implement Sendable
2. **AnyEncodable Wrapper**: Fix the type-erased encoding wrapper to work with strict concurrency
3. **API Client Thread Safety**: Ensure the UntisAPIClient can safely work across different actors

## Components and Interfaces

### 1. Sendable Data Models

All data models will be reviewed and updated to ensure proper Sendable conformance:

- **Explicit Sendable**: Models with only immutable, Sendable properties will use explicit `Sendable` conformance
- **@unchecked Sendable**: Models that are logically thread-safe but can't prove it to the compiler will use `@unchecked Sendable`
- **Remove @MainActor**: Any inadvertent main actor isolation will be removed from data models

### 2. AnyEncodable Wrapper

The current AnyEncodable implementation needs to be updated:

```swift
struct AnyEncodable: Codable, Sendable {
    private let _encode: @Sendable (Encoder) throws -> Void
    
    init<T: Encodable & Sendable>(_ encodable: T) {
        self._encode = { encoder in
            try encodable.encode(to: encoder)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
    
    init(from decoder: Decoder) throws {
        fatalError("AnyEncodable does not support decoding")
    }
}
```

### 3. Generic Request Method

The generic request method will be updated to ensure proper Sendable constraints:

```swift
private func request<T: Codable & Sendable>(
    url: String,
    method: String,
    parameters: [AnyEncodable]
) async throws -> T
```

### 4. Result Types

All result wrapper types will be properly marked as Sendable:

- `AuthTokenResult`
- `UserDataResult` 
- `TimetableResult`
- `PeriodDataResult`
- `SchoolSearchResult`

## Data Models

### API Models
- `RequestData`: Already properly marked as `@unchecked Sendable`
- `BaseResponse<T>`: Already properly marked as `Sendable` with constraint
- `AnyEncodable`: Needs redesign to work with Sendable constraints

### Domain Models
All domain models are already properly marked as `Sendable` or `@unchecked Sendable`:
- `UserData`, `MasterData`, `Settings`: Properly Sendable
- `Period`, `Timetable`: Properly Sendable
- `HomeWork`: Uses `@unchecked Sendable` (appropriate for mutable properties)

### Parameter Models
All parameter models in `Parameters.swift` are already properly marked as `Sendable`.

## Error Handling

The current error handling with `UntisAPIError` is already Sendable-compliant and doesn't need changes.

## Testing Strategy

### Unit Tests
1. **Sendable Conformance Tests**: Verify that all models can be safely passed between actors
2. **AnyEncodable Tests**: Test the new AnyEncodable implementation with various Sendable types
3. **Concurrency Tests**: Test API calls from different actors to ensure no isolation conflicts

### Integration Tests
1. **SwiftUI Integration**: Test API usage from SwiftUI views to ensure no main actor conflicts
2. **Background Processing**: Test API calls from background queues
3. **Actor Isolation**: Test data passing between different custom actors

## Implementation Notes

### Root Cause Analysis
The errors are occurring because:
1. Some types may be getting inadvertently isolated to the main actor
2. The AnyEncodable wrapper doesn't properly handle Sendable constraints
3. Generic type constraints in async functions require strict Sendable conformance

### Solution Approach
1. **Remove Main Actor Isolation**: Ensure no data models are inadvertently marked with @MainActor
2. **Fix AnyEncodable**: Redesign to use closure-based approach that maintains Sendable
3. **Verify Constraints**: Ensure all generic constraints properly specify Sendable requirements

### Backward Compatibility
All changes will maintain backward compatibility with existing API usage patterns while fixing the concurrency issues.