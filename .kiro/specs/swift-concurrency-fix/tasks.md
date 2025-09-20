# Implementation Plan

- [ ] 1. Fix AnyEncodable wrapper for Sendable conformance
  - Redesign AnyEncodable to use closure-based approach that maintains Sendable conformance
  - Replace the current Encodable storage with a Sendable closure
  - Update the initializer to only accept Encodable & Sendable types
  - _Requirements: 2.1, 2.2, 2.3_

- [ ] 2. Verify and fix data model Sendable conformance
  - Review all result types (AuthTokenResult, UserDataResult, TimetableResult, etc.) for proper Sendable marking
  - Ensure no inadvertent @MainActor isolation on data models
  - Add explicit Sendable conformance where @unchecked Sendable is not needed
  - _Requirements: 1.1, 1.2, 3.1, 3.3_

- [ ] 3. Update UntisAPIClient generic constraints
  - Verify the generic request method properly constrains T to Codable & Sendable
  - Ensure all API method return types are properly constrained
  - Fix any missing Sendable constraints in method signatures
  - _Requirements: 1.1, 1.3, 4.1_

- [ ] 4. Test concurrency fixes with unit tests
  - Create tests that verify Sendable conformance by passing models between actors
  - Test AnyEncodable with various Sendable parameter types
  - Verify API client can be used from different actor contexts
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 3.1, 3.2, 3.3_

- [ ] 5. Validate SwiftUI integration
  - Test API usage from SwiftUI views to ensure no main actor conflicts
  - Verify data binding works correctly with fixed Sendable conformance
  - Ensure background API calls can safely update UI on main actor
  - _Requirements: 4.1, 4.2, 4.3_