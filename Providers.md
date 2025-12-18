# Configuration Providers - Deep Dive

This guide provides comprehensive coverage of all Configuration providers with real-world examples.

## Table of Contents

1. [InMemoryProvider](#inmemoryprovider)
2. [MutableInMemoryProvider](#mutableinmemoryprovider)
3. [EnvironmentVariablesProvider](#environmentvariablesprovider)
4. [FileProvider](#fileprovider)
5. [DirectoryFilesProvider](#directoryfilesprovider)
6. [ReloadingFileProvider](#reloadingfileprovider)
7. [KeyMappingProvider](#keymappingprovider)
8. [Custom Providers](#custom-providers)

---

## InMemoryProvider

### Overview

The `InMemoryProvider` stores configuration values in memory as an immutable dictionary. Values cannot be changed after initialization.

### When to Use

**Perfect for:**
- Default configuration values
- Test fixtures
- SwiftUI previews
- Compile-time constants
- Configuration fallbacks

**Avoid for:**
- Secrets in production
- User preferences
- Dynamic runtime values
- Build configuration

### API Reference

```swift
// Basic initialization
InMemoryProvider(values: [String: ConfigValue])

// With custom name
InMemoryProvider(
    name: String?, 
    values: [AbsoluteConfigKey: ConfigValue]
)
```

### Complete Examples

#### Example 1: Application Defaults

```swift
enum AppDefaults {
    static let provider = InMemoryProvider(values: [
        // API Configuration
        "api.timeout": 30,
        "api.retries": 3,
        "api.backoffMultiplier": 2.0,
        
        // Feature Flags
        "feature.newUI": false,
        "feature.betaFeatures": false,
        "feature.analytics": true,
        
        // Cache Configuration
        "cache.maxSize": 100,
        "cache.ttl": 3600,
        
        // UI Configuration
        "ui.animationDuration": 0.3,
        "ui.maxResults": 50
    ])
}

// Usage
let config = ConfigReader(providers: [
    EnvironmentVariablesProvider(),
    AppDefaults.provider
])

let timeout = config.int(forKey: "api.timeout", default: 30)
```

#### Example 2: Test Configuration

```swift
final class NetworkServiceTests: XCTestCase {
    func testWithShortTimeout() async throws {
        // Arrange
        let testConfig = InMemoryProvider(values: [
            "api.timeout": 1,  // 1 second for testing
            "api.retries": 1,
            "api.baseURL": "https://test.example.com"
        ])
        
        let config = ConfigReader(provider: testConfig)
        let service = NetworkService(config: config)
        
        // Act & Assert
        await assertThrowsError(try await service.fetchData()) { error in
            XCTAssertTrue(error is TimeoutError)
        }
    }
    
    func testWithMockAPI() async throws {
        let testConfig = InMemoryProvider(values: [
            "api.baseURL": "http://localhost:8080",
            "api.timeout": 10,
            "test.mode": true
        ])
        
        let config = ConfigReader(provider: testConfig)
        let service = NetworkService(config: config)
        
        let result = try await service.fetchData()
        XCTAssertNotNil(result)
    }
}
```

#### Example 3: SwiftUI Previews

```swift
#Preview("New UI Enabled") {
    let config = ConfigReader(provider: InMemoryProvider(values: [
        "feature.newUI": true,
        "ui.theme": "dark",
        "user.isPremium": true
    ]))
    
    ContentView()
        .environment(\.config, config)
}

#Preview("Default State") {
    let config = ConfigReader(provider: InMemoryProvider(values: [
        "feature.newUI": false,
        "ui.theme": "light",
        "user.isPremium": false
    ]))
    
    ContentView()
        .environment(\.config, config)
}
```

#### Example 4: Configuration Layers

```swift
struct ConfigurationBuilder {
    static func build(environment: Environment) -> ConfigReader {
        let baseConfig = InMemoryProvider(values: [
            "api.timeout": 30,
            "api.retries": 3,
            "cache.enabled": true
        ])
        
        let environmentConfig: InMemoryProvider
        
        switch environment {
        case .development:
            environmentConfig = InMemoryProvider(values: [
                "api.baseURL": "https://dev.api.example.com",
                "debug.logging": true,
                "cache.ttl": 60
            ])
        case .staging:
            environmentConfig = InMemoryProvider(values: [
                "api.baseURL": "https://staging.api.example.com",
                "debug.logging": true,
                "cache.ttl": 300
            ])
        case .production:
            environmentConfig = InMemoryProvider(values: [
                "api.baseURL": "https://api.example.com",
                "debug.logging": false,
                "cache.ttl": 3600
            ])
        }
        
        return ConfigReader(providers: [
            environmentConfig,
            baseConfig
        ])
    }
}
```

### Performance Characteristics

- **Lookup**: O(1)
- **Memory**: O(n) where n = number of values
- **Thread Safety**: Thread-safe (immutable)
- **Initialization**: One-time cost

### Best Practices

```swift
// DO: Use for type-safe defaults
enum APIConfig {
    static let defaults = InMemoryProvider(values: [
        "api.timeout": 30,
        "api.retries": 3
    ])
}

// DO: Document your configuration
/// Default configuration for the application.
/// - api.timeout: Request timeout in seconds (default: 30)
/// - api.retries: Number of retry attempts (default: 3)
static let defaults = InMemoryProvider(values: [...])

// DO: Use as last provider in chain
ConfigReader(providers: [
    EnvironmentVariablesProvider(),
    FileProvider<JSONSnapshot>(...),
    InMemoryProvider(values: defaultValues)  // Fallback
])

// DON'T: Hardcode secrets
let provider = InMemoryProvider(values: [
    "api.key": "sk_live_123"  // Security risk
])

// DON'T: Use for mutable data
let provider = InMemoryProvider(values: [
    "current.user": "john"  // Use app state instead
])
```

---

## MutableInMemoryProvider

### Overview

A thread-safe, mutable in-memory configuration provider that supports real-time updates and change notifications.

### When to Use

**Perfect for:**
- Feature flags with remote updates
- A/B testing configuration
- Runtime configuration changes
- Configuration bridges
- Testing dynamic behavior

**Avoid for:**
- Application state management
- High-frequency updates (>1/sec)
- Event broadcasting
- Persistent storage

### API Reference

```swift
// Initialization
MutableInMemoryProvider(
    name: String?,
    initialValues: [AbsoluteConfigKey: ConfigValue]
)

// Updating values
func setValue(
    _ value: ConfigValue?,
    forKey key: AbsoluteConfigKey
)
```

### Complete Examples

#### Example 1: Feature Flag System

```swift
class FeatureFlagManager {
    let provider = MutableInMemoryProvider(
        name: "FeatureFlags",
        initialValues: [
            AbsoluteConfigKey("feature.newCheckout"): ConfigValue(false, isSecret: false),
            AbsoluteConfigKey("feature.darkMode"): ConfigValue(true, isSecret: false),
            AbsoluteConfigKey("feature.socialLogin"): ConfigValue(false, isSecret: false)
        ]
    )
    
    private let config: ConfigReader
    
    init() {
        self.config = ConfigReader(provider: provider)
        startRemoteSync()
    }
    
    func startRemoteSync() {
        Task {
            for await update in remoteConfigStream() {
                updateFlag(update.key, enabled: update.enabled)
            }
        }
    }
    
    func updateFlag(_ name: String, enabled: Bool) {
        let key = AbsoluteConfigKey("feature.\(name)")
        provider.setValue(ConfigValue(enabled, isSecret: false), forKey: key)
        
        print("Feature '\(name)' is now \(enabled ? "enabled" : "disabled")")
        
        NotificationCenter.default.post(
            name: .featureFlagChanged,
            object: (name, enabled)
        )
    }
    
    func isEnabled(_ feature: String) -> Bool {
        config.bool(forKey: "feature.\(feature)", default: false)
    }
    
    private func remoteConfigStream() -> AsyncStream<(key: String, enabled: Bool)> {
        AsyncStream { continuation in
            // Simulate remote config updates
            Task {
                try? await Task.sleep(for: .seconds(5))
                continuation.yield(("newCheckout", true))
                
                try? await Task.sleep(for: .seconds(10))
                continuation.yield(("socialLogin", true))
            }
        }
    }
}

// Usage in SwiftUI
struct CheckoutView: View {
    @EnvironmentObject var featureFlags: FeatureFlagManager
    
    var body: some View {
        if featureFlags.isEnabled("newCheckout") {
            NewCheckoutFlow()
        } else {
            LegacyCheckoutFlow()
        }
    }
}
```

#### Example 2: A/B Testing

```swift
class ABTestManager {
    let provider = MutableInMemoryProvider(
        name: "ABTests",
        initialValues: [:]
    )
    
    private let config: ConfigReader
    private let userId: String
    
    init(userId: String) {
        self.userId = userId
        self.config = ConfigReader(provider: provider)
        assignVariants()
    }
    
    func assignVariants() {
        let experiments = [
            "checkout.flow",
            "pricing.display",
            "onboarding.steps"
        ]
        
        for experiment in experiments {
            let variant = determineVariant(for: experiment)
            let key = AbsoluteConfigKey("experiment.\(experiment)")
            provider.setValue(ConfigValue(variant, isSecret: false), forKey: key)
        }
    }
    
    private func determineVariant(for experiment: String) -> String {
        // Hash user ID + experiment name for consistent assignment
        let hash = "\(userId)-\(experiment)".hashValue
        return hash % 2 == 0 ? "variant-A" : "variant-B"
    }
    
    func getVariant(_ experiment: String) -> String {
        config.string(
            forKey: "experiment.\(experiment)",
            default: "control"
        )
    }
    
    func trackConversion(_ experiment: String) {
        let variant = getVariant(experiment)
        // Send to analytics
        Analytics.track("conversion", properties: [
            "experiment": experiment,
            "variant": variant,
            "userId": userId
        ])
    }
}

// Usage
let abTest = ABTestManager(userId: currentUser.id)
let checkoutVariant = abTest.getVariant("checkout.flow")

if checkoutVariant == "variant-A" {
    showOnePageCheckout()
} else {
    showMultiStepCheckout()
}

// Track when user completes purchase
abTest.trackConversion("checkout.flow")
```

#### Example 3: Remote Configuration Bridge

```swift
class RemoteConfigBridge {
    let provider = MutableInMemoryProvider(
        name: "RemoteConfig",
        initialValues: [:]
    )
    
    private var fetchTask: Task<Void, Never>?
    
    func startListening() {
        fetchTask = Task {
            while !Task.isCancelled {
                do {
                    let remoteConfig = try await fetchRemoteConfig()
                    updateLocalConfig(remoteConfig)
                    
                    // Fetch every 5 minutes
                    try await Task.sleep(for: .seconds(300))
                } catch {
                    print("Failed to fetch remote config: \(error)")
                    try? await Task.sleep(for: .seconds(60))
                }
            }
        }
    }
    
    func stopListening() {
        fetchTask?.cancel()
    }
    
    private func fetchRemoteConfig() async throws -> [String: Any] {
        let url = URL(string: "https://api.example.com/config")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    private func updateLocalConfig(_ config: [String: Any]) {
        for (key, value) in config {
            let configKey = AbsoluteConfigKey(key)
            let configValue = convertToConfigValue(value)
            provider.setValue(configValue, forKey: configKey)
        }
        
        print("Updated \(config.count) configuration values")
    }
    
    private func convertToConfigValue(_ value: Any) -> ConfigValue? {
        switch value {
        case let str as String:
            return ConfigValue(.string(str), isSecret: false)
        case let int as Int:
            return ConfigValue(.int(int), isSecret: false)
        case let bool as Bool:
            return ConfigValue(.bool(bool), isSecret: false)
        case let double as Double:
            return ConfigValue(.double(double), isSecret: false)
        default:
            return nil
        }
    }
}

// Usage
let remoteBridge = RemoteConfigBridge()
let config = ConfigReader(providers: [
    remoteBridge.provider,
    AppDefaults.provider
])

remoteBridge.startListening()

// Config automatically updates from remote source
```

#### Example 4: Testing Configuration Changes

```swift
final class ConfigurationChangeTests: XCTestCase {
    func testFeatureFlagToggle() async throws {
        // Arrange
        let provider = MutableInMemoryProvider(initialValues: [
            AbsoluteConfigKey("feature.newUI"): ConfigValue(false, isSecret: false)
        ])
        let config = ConfigReader(provider: provider)
        
        var receivedValues: [Bool] = []
        
        // Act - Watch for changes
        let watchTask = Task {
            try await config.watchBool(forKey: "feature.newUI") { updates in
                for await value in updates {
                    if let value = value {
                        receivedValues.append(value)
                    }
                    if receivedValues.count >= 3 {
                        break
                    }
                }
            }
        }
        
        // Give watch time to start
        try await Task.sleep(for: .milliseconds(100))
        
        // Toggle flag
        provider.setValue(
            ConfigValue(true, isSecret: false),
            forKey: AbsoluteConfigKey("feature.newUI")
        )
        try await Task.sleep(for: .milliseconds(100))
        
        provider.setValue(
            ConfigValue(false, isSecret: false),
            forKey: AbsoluteConfigKey("feature.newUI")
        )
        
        try await Task.sleep(for: .milliseconds(100))
        await watchTask.value
        
        // Assert
        XCTAssertEqual(receivedValues, [false, true, false])
    }
    
    func testMultipleWatchers() async throws {
        let provider = MutableInMemoryProvider(initialValues: [:])
        let config = ConfigReader(provider: provider)
        
        var watcher1Values: [Int] = []
        var watcher2Values: [Int] = []
        
        // Start multiple watchers
        let task1 = Task {
            try await config.watchInt(forKey: "counter") { updates in
                for await value in updates {
                    if let value = value {
                        watcher1Values.append(value)
                    }
                    if watcher1Values.count >= 3 {
                        break
                    }
                }
            }
        }
        
        let task2 = Task {
            try await config.watchInt(forKey: "counter") { updates in
                for await value in updates {
                    if let value = value {
                        watcher2Values.append(value)
                    }
                    if watcher2Values.count >= 3 {
                        break
                    }
                }
            }
        }
        
        try await Task.sleep(for: .milliseconds(100))
        
        // Update value
        for i in 1...3 {
            provider.setValue(
                ConfigValue(.int(i), isSecret: false),
                forKey: AbsoluteConfigKey("counter")
            )
            try await Task.sleep(for: .milliseconds(50))
        }
        
        await task1.value
        await task2.value
        
        // Both watchers should receive all updates
        XCTAssertEqual(watcher1Values, [1, 2, 3])
        XCTAssertEqual(watcher2Values, [1, 2, 3])
    }
}
```

### Performance Characteristics

- **Lookup**: O(1)
- **Update**: O(1) + notification overhead
- **Thread Safety**: Thread-safe with locks
- **Watchers**: O(w) where w = number of watchers

### Best Practices

```swift
// DO: Use for dynamic configuration
let provider = MutableInMemoryProvider(initialValues: [:])
// Update as needed
provider.setValue(newValue, forKey: key)

// DO: Clean up watchers
class FeatureManager {
    var watchTask: Task<Void, Never>?
    
    deinit {
        watchTask?.cancel()
    }
}

// DO: Debounce rapid updates
class ConfigUpdater {
    private var updateTimer: Timer?
    
    func scheduleUpdate(key: AbsoluteConfigKey, value: ConfigValue) {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.provider.setValue(value, forKey: key)
        }
    }
}

// DON'T: Use for high-frequency updates
// Avoid updating more than once per second
timer.schedule(every: .milliseconds(10)) {
    provider.setValue(...)  // Too frequent
}

// DON'T: Store complex state
provider.setValue(
    entireUserObject,  // Not for app state
    forKey: key
)
```

---

## EnvironmentVariablesProvider

### Overview

Reads configuration from environment variables, supporting both process environment and `.env` files.

### Key Transformation Rules

```
Configuration Key       →  Environment Variable
─────────────────────────────────────────────────
api.timeout            →  API_TIMEOUT
database.host          →  DATABASE_HOST
http.serverTimeout     →  HTTP_SERVER_TIMEOUT
myApp.apiKey           →  MY_APP_API_KEY
```

### When to Use

**Perfect for:**
- 12-Factor App configuration
- Docker/container deployments
- CI/CD environments
- Server applications
- Development overrides (.env files)

*Avoid for:**
- iOS app runtime config (won't work)
- Complex nested structures
- Large binary data
- Frequently changing values

### API Reference

```swift
// Read from process environment
EnvironmentVariablesProvider(
    secretsSpecifier: SecretsSpecifier<String, String> = .none,
    bytesDecoder: some ConfigBytesFromStringDecoder = .base64,
    arraySeparator: Character = ","
)

// Read from custom environment
EnvironmentVariablesProvider(
    environmentVariables: [String: String],
    secretsSpecifier: SecretsSpecifier<String, String> = .none,
    bytesDecoder: some ConfigBytesFromStringDecoder = .base64,
    arraySeparator: Character = ","
)

// Read from .env file
EnvironmentVariablesProvider(
    environmentFilePath: FilePath,
    allowMissing: Bool = false,
    secretsSpecifier: SecretsSpecifier<String, String> = .none,
    bytesDecoder: some ConfigBytesFromStringDecoder = .base64,
    arraySeparator: Character = ","
) async throws

// Direct access
func environmentValue(forName name: String) throws -> String?
```

### Complete Examples

#### Example 1: 12-Factor App

```swift
// Server.swift
import Configuration

@main
struct Server {
    static func main() async throws {
        // Load configuration
        let config = ConfigReader(provider: EnvironmentVariablesProvider(
            secretsSpecifier: .specific([
                "DATABASE_PASSWORD",
                "API_KEY",
                "JWT_SECRET",
                "SMTP_PASSWORD"
            ])
        ))
        
        // Database configuration
        let dbHost = config.string(forKey: "database.host", default: "localhost")
        let dbPort = config.int(forKey: "database.port", default: 5432)
        let dbName = config.string(forKey: "database.name", default: "myapp")
        let dbPassword = try config.requiredString(
            forKey: "database.password",
            isSecret: true
        )
        
        // Server configuration
        let serverPort = config.int(forKey: "server.port", default: 8080)
        let serverHost = config.string(forKey: "server.host", default: "0.0.0.0")
        
        // Feature flags
        let enableMetrics = config.bool(forKey: "feature.metrics", default: true)
        let enableCORS = config.bool(forKey: "feature.cors", default: false)
        
        print("""
        Starting server...
        Host: \(serverHost):\(serverPort)
        Database: \(dbHost):\(dbPort)/\(dbName)
        Features: metrics=\(enableMetrics), cors=\(enableCORS)
        """)
        
        // Start server...
    }
}

// Run with:
// DATABASE_HOST=prod-db.example.com \
// DATABASE_PORT=5432 \
// DATABASE_PASSWORD=secret \
// SERVER_PORT=8080 \
// FEATURE_METRICS=true \
// ./Server
```

#### Example 2: Docker Deployment

```dockerfile
# Dockerfile
FROM swift:5.9
WORKDIR /app
COPY . .
RUN swift build -c release

# Configuration via environment variables
ENV SERVER_PORT=8080
ENV SERVER_HOST=0.0.0.0
ENV DATABASE_HOST=postgres
ENV DATABASE_PORT=5432
ENV DATABASE_NAME=myapp
ENV LOG_LEVEL=info

CMD [".build/release/Server"]
```

```yaml
# docker-compose.yml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - DATABASE_HOST=postgres
      - DATABASE_PORT=5432
      - DATABASE_NAME=myapp
      - DATABASE_PASSWORD=${DATABASE_PASSWORD}
      - API_KEY=${API_KEY}
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      - postgres
  
  postgres:
    image: postgres:15
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_PASSWORD=${DATABASE_PASSWORD}
```

#### Example 3: Development with .env File

```swift
// Config.swift
enum AppConfig {
    static func load() async throws -> ConfigReader {
        var providers: [any ConfigProvider] = []
        
        // Try to load .env file in development
        #if DEBUG
        let envPath = FilePath(".env")
        do {
            let envProvider = try await EnvironmentVariablesProvider(
                environmentFilePath: envPath,
                allowMissing: true,
                secretsSpecifier: .dynamic { key, _ in
                    key.contains("PASSWORD") ||
                    key.contains("SECRET") ||
                    key.contains("KEY") ||
                    key.contains("TOKEN")
                }
            )
            providers.append(envProvider)
            print("Loaded .env file")
        } catch {
            print("No .env file found, using system environment")
        }
        #endif
        
        // Always add system environment
        providers.append(EnvironmentVariablesProvider(
            secretsSpecifier: .dynamic { key, _ in
                key.contains("PASSWORD") ||
                key.contains("SECRET") ||
                key.contains("KEY") ||
                key.contains("TOKEN")
            }
        ))
        
        // Add defaults
        providers.append(InMemoryProvider(values: [
            "server.port": 8080,
            "server.host": "localhost",
            "log.level": "info"
        ]))
        
        return ConfigReader(providers: providers)
    }
}
```

```bash
# .env (for development only - never commit to git!)
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=myapp_dev
DATABASE_PASSWORD=devpassword
API_KEY=dev_key_123
LOG_LEVEL=debug
FEATURE_DEBUG_MODE=true
```

```gitignore
# .gitignore
.env
.env.local
.env.*.local
```

#### Example 4: CI/CD Configuration

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run tests
        env:
          DATABASE_HOST: localhost
          DATABASE_PORT: 5432
          DATABASE_NAME: test_db
          DATABASE_PASSWORD: ${{ secrets.TEST_DB_PASSWORD }}
          API_KEY: ${{ secrets.TEST_API_KEY }}
          TEST_MODE: true
        run: swift test
```

### Secret Handling

```swift
// Specific secrets
let provider = EnvironmentVariablesProvider(
    secretsSpecifier: .specific([
        "DATABASE_PASSWORD",
        "API_KEY",
        "JWT_SECRET"
    ])
)

// Pattern-based secrets
let provider = EnvironmentVariablesProvider(
    secretsSpecifier: .dynamic { key, value in
        // Mark as secret if key contains these words
        let secretKeywords = ["PASSWORD", "SECRET", "KEY", "TOKEN", "PRIVATE"]
        return secretKeywords.contains { key.contains($0) }
    }
)

// All secrets (for sensitive environments)
let provider = EnvironmentVariablesProvider(
    secretsSpecifier: .all
)

// No secrets (for non-sensitive config only)
let provider = EnvironmentVariablesProvider(
    secretsSpecifier: .none
)
```

### Array Handling

```swift
// Environment variable
// ALLOWED_HOSTS=example.com,api.example.com,admin.example.com

let provider = EnvironmentVariablesProvider(
    arraySeparator: ","
)

let config = ConfigReader(provider: provider)
let hosts = config.stringArray(forKey: "allowed.hosts", default: [])
// ["example.com", "api.example.com", "admin.example.com"]

// Custom separator
// PORTS=8080:8081:8082
let provider = EnvironmentVariablesProvider(
    arraySeparator: ":"
)
let ports = config.intArray(forKey: "ports", default: [])
// [8080, 8081, 8082]
```

### Binary Data Handling

```swift
// Base64 encoded certificate
// TLS_CERT=LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...

let provider = EnvironmentVariablesProvider(
    bytesDecoder: .base64,
    secretsSpecifier: .specific(["TLS_CERT", "TLS_KEY"])
)

let config = ConfigReader(provider: provider)
let certData = try config.requiredBytes(forKey: "tls.cert", isSecret: true)

// Hex encoded data
// API_SIGNATURE=48656c6c6f
let provider = EnvironmentVariablesProvider(
    bytesDecoder: .hex
)
let signature = config.bytes(forKey: "api.signature")
```

### Performance Characteristics

- **Lookup**: O(1) (case-insensitive)
- **Initialization**: O(n) where n = number of env vars
- **Memory**: O(n)
- **Thread Safety**: Thread-safe

### Best Practices

```swift
// DO: Use for deployment configuration
let config = ConfigReader(provider: EnvironmentVariablesProvider())

// DO: Provide sensible defaults
let timeout = config.int(forKey: "api.timeout", default: 30)

// DO: Validate required values at startup
func validateConfig(_ config: ConfigReader) throws {
    _ = try config.requiredString(forKey: "database.host")
    _ = try config.requiredInt(forKey: "database.port")
    _ = try config.requiredString(forKey: "database.password", isSecret: true)
}

// DO: Document environment variables
/// Environment Variables:
/// - DATABASE_HOST: PostgreSQL host (required)
/// - DATABASE_PORT: PostgreSQL port (default: 5432)
/// - DATABASE_PASSWORD: Database password (required, secret)
/// - LOG_LEVEL: Logging level (default: info)

// DON'T: Use in iOS apps
#if os(iOS)
// This won't read any environment variables at runtime
let provider = EnvironmentVariablesProvider()
#endif

// DON'T: Commit .env files
// Add to .gitignore:
// .env
// .env.local

// DON'T: Use for complex nested structures
// Use JSON files instead for complex configs
```

---

## Conclusion

Each provider has specific use cases where it excels. Choose the right provider based on your needs:

- **InMemoryProvider**: Defaults and testing
- **MutableInMemoryProvider**: Dynamic runtime config
- **EnvironmentVariablesProvider**: Deployment config
- **FileProvider**: Structured configuration
- **DirectoryFilesProvider**: Secret management

Mix and match providers for powerful, flexible configuration management!
