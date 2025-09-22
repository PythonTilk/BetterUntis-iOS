# Debug Setup Guide for BetterUntis

This guide explains how to configure Xcode for optimal debugging of the BetterUntis iOS application.

## Debug Features Added

### 1. Comprehensive Debug Logging System (`DebugLogger.swift`)

- **Structured Logging**: Organized by categories (Network, Auth, Data, UI, Error, Performance)
- **Automatic Debug/Release Configuration**: Only active in debug builds
- **Performance Measurement**: Built-in timing for operations
- **Memory Tracking**: Monitor memory usage at key points
- **Emoji-based Log Levels**: Easy visual identification of log types

**Usage Examples:**
```swift
// Basic logging
DebugLogger.logInfo("App started successfully")
DebugLogger.logWarning("Low memory warning received")

// Network logging
DebugLogger.logNetworkRequest(url: "https://api.example.com", method: "GET")
DebugLogger.logNetworkResponse(url: "https://api.example.com", statusCode: 200, duration: 0.5)

// Authentication logging
DebugLogger.logAuthAttempt(method: "JSONRPC", server: "server.com", user: "student")
DebugLogger.logAuthSuccess(method: "JSONRPC", user: "student")

// Performance measurement
let result = DebugLogger.measurePerformance(operation: "Data Loading") {
    return loadData()
}

// Error logging with context
DebugLogger.logError(error, context: "Failed to load user data")
```

### 2. Error Tracking System (`ErrorTracker.swift`)

- **Crash Detection**: Automatically captures uncaught exceptions and signals
- **Error History**: Maintains persistent error history across app launches
- **App State Capture**: Records memory usage, authentication state, and current view
- **Export Capabilities**: Generate and export error reports
- **Stack Trace Capture**: Full stack traces for debugging

**Features:**
- Automatic crash handling
- Error context preservation
- Memory and disk usage tracking
- Export to email or file sharing

### 3. In-App Debug Console (`DebugView.swift`)

Accessible via the "Debug" tab in debug builds only.

**Tabs:**
- **Errors**: View all tracked errors with timestamps and context
- **Logs**: Recent application logs (can be expanded)
- **System**: Device information, memory usage, disk space
- **Network**: Network status and recent API calls

**Actions:**
- Export error reports
- Clear error history
- Trigger test errors
- Toggle verbose logging

## Xcode Configuration

### 1. Scheme Configuration

#### Debug Scheme Settings:
1. Open **Product → Scheme → Edit Scheme...**
2. Select **Run** tab
3. Ensure **Build Configuration** is set to **Debug**
4. In **Arguments** tab:
   - Add environment variables if needed:
     - `VERBOSE_LOGGING=1` (optional, for extra verbose output)
     - `DEBUG_NETWORK=1` (optional, for detailed network logging)

#### Logging Configuration:
1. In Xcode Console (View → Debug Area → Activate Console):
   - Enable **All Output** in the console filter
   - Use the search filter to focus on specific log categories:
     - Search for `🔐` for authentication logs
     - Search for `🌐` for network logs
     - Search for `❌` for error logs
     - Search for `⚡️` for performance logs

### 2. Breakpoint Configuration

#### Symbolic Breakpoints:
1. **Error Tracking Breakpoint**:
   - Symbol: `ErrorTracker.trackError`
   - Condition: None
   - Action: Log message "Error tracked: %H"

2. **Network Error Breakpoint**:
   - Symbol: `DebugLogger.logNetworkError`
   - Condition: None
   - Action: Log message "Network error: %H"

3. **Critical Error Breakpoint**:
   - Symbol: `DebugLogger.logCriticalError`
   - Condition: None
   - Action: Log message "CRITICAL ERROR: %H"
   - Options: ✓ Automatically continue after evaluating actions

#### Exception Breakpoints:
1. **All Exceptions**:
   - Add Exception Breakpoint (⌘+8 → + → Exception Breakpoint)
   - Exception: All
   - Break: On Throw

2. **Swift Error Breakpoint**:
   - Add Swift Error Breakpoint
   - Break: On Throw

### 3. Console Usage

#### Viewing Logs in Xcode Console:
- **Real-time monitoring**: Console shows live logs from `DebugLogger`
- **Filter by category**: Use emoji searches (🔐, 🌐, ❌, etc.)
- **Performance logs**: Look for ⚡️ and 🐌 emojis to identify slow operations

#### Console Commands:
- `po ErrorTracker.shared.getRecentErrors(count: 5)` - Print recent errors
- `po DebugLogger.isVerboseLoggingEnabled` - Check verbose logging status
- `po DebugLogger.logMemoryUsage(context: "Manual Check")` - Log current memory

### 4. Instruments Integration

#### Recommended Instruments:
1. **Time Profiler**: Identify performance bottlenecks
2. **Allocations**: Monitor memory usage and leaks
3. **Network**: Analyze network traffic and performance
4. **Leaks**: Detect memory leaks

#### Custom Signposts:
The debug system includes os_signpost integration for Instruments:
```swift
// Automatic signposts for measured operations
DebugLogger.measurePerformance(operation: "API Call") {
    // This will create signposts visible in Instruments
}
```

## Usage During Development

### 1. Starting a Debug Session

1. **Set Active Scheme**: Ensure "BetterUntis" scheme is selected
2. **Choose Target**: Select iOS Simulator or connected device
3. **Start Debugging**: Press ⌘+R or click Run button
4. **Monitor Console**: Open Debug Area (⌘+Shift+Y) to see live logs

### 2. Monitoring Application State

#### In Xcode Console:
- Watch for colored emoji indicators in logs
- Monitor authentication flows (🔐 indicators)
- Track network requests (🌐 indicators)
- Identify errors immediately (❌ indicators)

#### In-App Debug Console:
- Switch to "Debug" tab in the app
- View real-time error list
- Check system information
- Export error reports when needed

### 3. Debugging Workflows

#### Network Debugging:
1. Start app in debugger
2. Perform actions that make network requests
3. Watch console for network logs with timing
4. Check "Network" tab in debug console for details

#### Error Debugging:
1. Trigger the error condition
2. Check Xcode console for immediate error logs
3. View "Errors" tab in debug console for persistent error history
4. Export error report if needed for analysis

#### Performance Debugging:
1. Use `DebugLogger.measurePerformance()` around suspected slow operations
2. Watch console for performance logs (⚡️ fast, 🐌 slow)
3. Use Instruments Time Profiler for detailed analysis
4. Check memory usage logs for memory issues

## Best Practices

### 1. Logging Guidelines

- **Use appropriate log levels**: Info for general flow, Warning for potential issues, Error for failures
- **Include context**: Always provide meaningful context with error logs
- **Avoid logging sensitive data**: Never log passwords, tokens, or personal information
- **Use performance measurement**: Wrap potentially slow operations in `measurePerformance()`

### 2. Error Handling

- **Track all errors**: Use `trackError()` for any caught exceptions
- **Provide context**: Include operation context when tracking errors
- **Use critical error tracking**: For errors that could crash the app
- **Regular error review**: Check error history during development

### 3. Debug Console Usage

- **Regular monitoring**: Check the debug console during testing
- **Export reports**: Generate reports for complex issues
- **Clear history**: Periodically clear error history during development
- **Test error scenarios**: Use "Trigger Test Error" to verify error tracking

## Integration with Existing Code

### Authentication Services
- `UntisAPIClient`: Enhanced with comprehensive auth logging
- `UntisRESTClient`: Added network request/response logging
- `HybridUntisService`: Integrated error tracking for fallback logic

### View Controllers
- Automatic view lifecycle logging in `BetterUntisApp.swift`
- Error tracking integration in all major services
- Performance measurement for data loading operations

## Release Configuration

**Important**: All debug features are automatically disabled in release builds through `#if DEBUG` conditionals. The release app will:
- Have no debug tab
- Generate no debug logs
- Have minimal performance impact
- Maintain only essential error tracking for crash reporting

This ensures that debug features don't impact production performance while providing comprehensive debugging capabilities during development.