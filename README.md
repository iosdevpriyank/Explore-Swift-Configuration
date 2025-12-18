# Swift Configuration Library - (Exploring)

[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

A comprehensive guide to Apple's Swift Configuration library with real-world examples, best practices, and detailed use cases.

## 📚 Table of Contents

- [Overview](#overview)
- [What is Swift Configuration?](#what-is-swift-configuration)
- [Platform Support](#platform-support)
- [Core Concepts](#core-concepts)
- [Providers Deep Dive](#providers-deep-dive)
- [Complete Examples](#complete-examples)
- [Best Practices](#best-practices)
- [Common Pitfalls](#common-pitfalls)

---

## Overview

Swift Configuration is Apple's official library for managing application configuration in a type-safe, hierarchical manner. It provides a unified interface for reading configuration from multiple sources with automatic type conversion and provider chaining.

### Key Features

- Type-safe configuration access  
- Multiple provider support (environment, files, in-memory)  
- Hierarchical key structure  
- Secret value protection  
- Real-time configuration watching  
- Snapshot consistency  
- Automatic type conversion  

### What It's NOT

- NOT a replacement for Info.plist  
- NOT a replacement for .xcconfig  
- NOT a replacement for UserDefaults  
- NOT a secrets manager  
- NOT a dependency injection container  

---

## What is Swift Configuration?

Swift Configuration is a **read-only configuration reader framework** that:

1. **Reads** key-value configuration
2. **From** multiple sources (providers)
3. **In** a predictable priority order

### Mental Model

```
ConfigKey     → WHAT you want
ConfigProvider→ WHERE it comes from
ConfigReader  → HOW you read it
```

---

## Platform Support

| Platform | Support | Notes |
|----------|---------|-------|
| **macOS app** |  Full | Best experience, all features work |
| **Swift CLI** |  Full | Designed for this use case |
| **Server** |  Full | (Vapor, Hummingbird, etc.) |
| **iOS app** |  Limited | **No runtime env vars** - use JSON/in-memory |
| **iOS tests** |  Full | Excellent for testing |
| **Swift Package** |  Full | Perfect for library configuration |

### iOS Limitations

- **No runtime environment variables** - iOS doesn't support reading env vars
- **No command-line arguments** - iOS apps don't have CLI args
- **Works great for**: JSON/in-memory providers, tests, SwiftUI previews

---

## Core Concepts

### 1. Configuration Keys

Keys are hierarchical paths to configuration values:

```swift
// String literal
let key: ConfigKey = "api.timeout"

// Array of components
let key = ConfigKey(["api", "timeout"])

// With context
let key = ConfigKey(
    "database.url",
    context: ["environment": "production"]
)
```

### 2. Configuration Providers

Providers answer: **"Do you have a value for this key?"**

Available providers:
- `InMemoryProvider` - Hardcoded values
- `EnvironmentVariablesProvider` - Environment variables (macOS/Server only)
- `DirectoryFilesProvider` - Directory of files
- `MutableInMemoryProvider` - Dynamic values

### 3. ConfigReader

The main interface for reading configuration:

```swift
let config = ConfigReader(providers: [
    InMemoryProvider(values: [
        AbsoluteConfigKey("api.key"): ConfigValue(.string("secret"), isSecret: true)
    ]),
    EnvironmentVariablesProvider()
])

let apiKey = config.string(forKey: "api.key")
```

### 4. Provider Priority

**First provider wins!**

```swift
let config = ConfigReader(providers: [
    InMemoryProvider(values: [
        AbsoluteConfigKey("port"): ConfigValue(.int(8080), isSecret: false)
    ]),  // Highest priority
    EnvironmentVariablesProvider()  // Fallback
])
```

###  Critical Requirement

**ConfigReader MUST have at least one provider:**

```swift
// WILL CRASH - empty providers not allowed
let config = ConfigReader(providers: [])

// CORRECT - at least one provider
let config = ConfigReader(provider: InMemoryProvider(values: [:]))

// CORRECT - multiple providers
let config = ConfigReader(providers: [
    InMemoryProvider(values: [...]),
    EnvironmentVariablesProvider()
])
```

---

## Providers Deep Dive

### InMemoryProvider

**Purpose**: Static configuration values in code

#### Positive Use Cases

```swift
// 1. Default values
let defaults = InMemoryProvider(values: [
    AbsoluteConfigKey("api.timeout"): ConfigValue(.int(30), isSecret: false),
    AbsoluteConfigKey("api.retries"): ConfigValue(.int(3), isSecret: false),
    AbsoluteConfigKey("feature.newUI"): ConfigValue(.bool(false), isSecret: false)
])

// 2. Test fixtures
let testConfig = InMemoryProvider(values: [
    AbsoluteConfigKey("database.host"): ConfigValue(.string("localhost"), isSecret: false),
    AbsoluteConfigKey("database.port"): ConfigValue(.int(5432), isSecret: false),
    AbsoluteConfigKey("test.mode"): ConfigValue(.bool(true), isSecret: false)
])

// 3. SwiftUI Previews
#Preview {
    let config = ConfigReader(provider: InMemoryProvider(values: [
        AbsoluteConfigKey("user.name"): ConfigValue(.string("Preview User"), isSecret: false),
        AbsoluteConfigKey("feature.beta"): ConfigValue(.bool(true), isSecret: false)
    ]))
    ContentView()
        .environment(\.config, config)
}
```

#### Negative Use Cases (Anti-patterns)

```swift
// DON'T: Store actual secrets
let bad = InMemoryProvider(values: [
    AbsoluteConfigKey("api.key"): ConfigValue(.string("sk_live_123"), isSecret: false)
])

// DON'T: Use for user preferences (use UserDefaults)
// DON'T: Use for build-specific values (use .xcconfig)
// DON'T: Use for dynamic runtime values (use MutableInMemoryProvider)
```

---

### Loading JSON Configuration (iOS Compatible)

Since `FileProvider<JSONSnapshot>` is not available in Configuration 1.0, use this helper:

```swift
import Configuration
import Foundation

enum AppConfiguration {
    
    static func loadJSONAsProvider(filename: String) throws -> InMemoryProvider {
        // 1. Load JSON file from bundle
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            throw ConfigError.fileNotFound("\(filename).json")
        }
        
        // 2. Parse JSON
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConfigError.invalidJSON(filename)
        }
        
        // 3. Flatten nested JSON into config keys
        var values: [AbsoluteConfigKey: ConfigValue] = [:]
        flatten(json, into: &values, prefix: [])
        
        // 4. Return as InMemoryProvider
        return InMemoryProvider(name: filename, values: values)
    }
    
    private static func flatten(_ object: Any, into result: inout [AbsoluteConfigKey: ConfigValue], prefix: [String]) {
        if let dict = object as? [String: Any] {
            for (key, value) in dict {
                flatten(value, into: &result, prefix: prefix + [key])
            }
        } else if let configValue = convertToConfigValue(object) {
            result[AbsoluteConfigKey(prefix)] = configValue
        }
    }
    
    private static func convertToConfigValue(_ value: Any) -> ConfigValue? {
        switch value {
        case let string as String:
            return ConfigValue(.string(string), isSecret: false)
        case let int as Int:
            return ConfigValue(.int(int), isSecret: false)
        case let double as Double:
            return ConfigValue(.double(double), isSecret: false)
        case let bool as Bool:
            return ConfigValue(.bool(bool), isSecret: false)
        case let array as [String]:
            return ConfigValue(.stringArray(array), isSecret: false)
        case let array as [Int]:
            return ConfigValue(.intArray(array), isSecret: false)
        case let array as [Double]:
            return ConfigValue(.doubleArray(array), isSecret: false)
        case let array as [Bool]:
            return ConfigValue(.boolArray(array), isSecret: false)
        default:
            return nil
        }
    }
}

enum ConfigError: Error {
    case fileNotFound(String)
    case invalidJSON(String)
}
```

**Usage:**

```swift
// Load JSON configuration
let config = try AppConfiguration.loadJSONAsProvider(filename: "config")

// config.json file:
// {
//   "api": {
//     "baseURL": "https://api.example.com",
//     "timeout": 30
//   }
// }

// Access: config.string(forKey: "api.baseURL")
```

---

### EnvironmentVariablesProvider

**Purpose**: Read from environment variables (macOS/Server only)

#### Key Transformations

```
http.serverTimeout → HTTP_SERVER_TIMEOUT
database.host      → DATABASE_HOST
api.key            → API_KEY
```

#### Positive Use Cases

```swift
// 1. Server configuration
let provider = EnvironmentVariablesProvider(
    secretsSpecifier: .specific(["API_KEY", "DATABASE_PASSWORD"])
)

// 2. Docker deployments
// docker run -e DATABASE_URL=postgres://...

// 3. CI/CD environments
let apiKey = config.string(forKey: "api.key", isSecret: true)
```

#### Negative Use Cases

```swift
// DON'T: Use in iOS apps (won't work at runtime)
#if os(iOS)
let provider = EnvironmentVariablesProvider()
// This won't read any runtime env vars in iOS!
#endif
```

---

## Complete Examples

### iOS App Example with JSON Configuration

```swift
import Configuration
import SwiftUI

enum AppConfig {
    static func makeConfigReader() throws -> ConfigReader {
        var providers: [any ConfigProvider] = []
        
        // 1. In-memory overrides (highest priority)
        providers.append(InMemoryProvider(values: [
            AbsoluteConfigKey("feature.newUI"): ConfigValue(.bool(true), isSecret: false),
            AbsoluteConfigKey("debug.showBorders"): ConfigValue(.bool(false), isSecret: false)
        ]))
        
        // 2. JSON configuration from bundle
        if let jsonProvider = try? loadJSONAsProvider(filename: "config") {
            providers.append(jsonProvider)
        }
        
        // 3. Fallback defaults (always present - REQUIRED)
        providers.append(InMemoryProvider(values: [
            AbsoluteConfigKey("api.timeout"): ConfigValue(.int(30), isSecret: false),
            AbsoluteConfigKey("api.retries"): ConfigValue(.int(3), isSecret: false)
        ]))
        
        return ConfigReader(providers: providers)
    }
}

// Usage in App
@main
struct MyApp: App {
    @State private var config: ConfigReader?
    
    var body: some Scene {
        WindowGroup {
            if let config = config {
                ContentView()
                    .environment(\.config, config)
            } else {
                ProgressView("Loading...")
                    .task {
                        config = try? AppConfig.makeConfigReader()
                    }
            }
        }
    }
}
```

### Server/CLI Example

```swift
import Configuration

// Server configuration
let config = ConfigReader(providers: [
    EnvironmentVariablesProvider(
        secretsSpecifier: .specific([
            "DATABASE_PASSWORD",
            "API_KEY",
            "JWT_SECRET"
        ])
    ),
    InMemoryProvider(values: [
        AbsoluteConfigKey("server.port"): ConfigValue(.int(8080), isSecret: false),
        AbsoluteConfigKey("server.host"): ConfigValue(.string("0.0.0.0"), isSecret: false)
    ])
])

let port = config.int(forKey: "server.port", default: 8080)
let host = config.string(forKey: "server.host", default: "localhost")
```

---

## Best Practices

### 1. Always Provide At Least One Provider

```swift
// Correct: Always have at least one provider
@MainActor
class ConfigurationManager: ObservableObject {
    @Published var config: ConfigReader
    
    init() {
        // Start with empty defaults to avoid crash
        self.config = ConfigReader(provider: InMemoryProvider(
            name: "EmptyDefaults",
            values: [:]
        ))
        
        Task {
            await loadConfiguration()
        }
    }
}
```

### 2. Provider Ordering

```swift
// Correct: Overrides first
let config = ConfigReader(providers: [
    InMemoryProvider(values: [/* overrides */]),  // Override
    InMemoryProvider(values: [/* defaults */])    // Defaults
])

// Wrong: Defaults first (gets ignored!)
let config = ConfigReader(providers: [
    InMemoryProvider(values: [/* defaults */]),
    InMemoryProvider(values: [/* overrides */])
])
```

### 3. Secret Handling

```swift
// Mark secrets explicitly
let apiKey = config.string(forKey: "api.key", isSecret: true)

// Use secrets specifier
let provider = EnvironmentVariablesProvider(
    secretsSpecifier: .dynamic { key, value in
        key.contains("PASSWORD") || 
        key.contains("SECRET") || 
        key.contains("KEY")
    }
)
```

### 4. Use Proper Key Types

```swift
// Type-safe keys
enum ConfigKeys {
    static let apiTimeout: ConfigKey = "api.timeout"
    static let apiRetries: ConfigKey = "api.retries"
}

// Usage
let timeout = config.int(forKey: ConfigKeys.apiTimeout, default: 30)
```

---

## Common Pitfalls

### 1. Empty Provider Array

```swift
// CRASH - ConfigReader requires at least one provider
let config = ConfigReader(providers: [])

// Always provide at least one
let config = ConfigReader(provider: InMemoryProvider(values: [:]))
```

### 2. iOS Runtime Environment Variables

```swift
// This won't work in iOS apps
let provider = EnvironmentVariablesProvider()
let apiKey = config.string(forKey: "api.key")  // Always nil in iOS

// Use JSON or in-memory instead
let provider = try loadJSONAsProvider(filename: "config")
```

### 3. JSONSnapshot Not Available

```swift
// FileProvider<JSONSnapshot> doesn't exist in Configuration 1.0
let provider = try await FileProvider<JSONSnapshot>(filePath: "config.json")

// Use helper function to load JSON
let provider = try loadJSONAsProvider(filename: "config")
```

### 4. Type Mismatches

```swift
// Type mismatch
let provider = InMemoryProvider(values: [
    AbsoluteConfigKey("port"): ConfigValue(.string("8080"), isSecret: false)
])
let port = config.int(forKey: "port")  // nil - expects Int

// Use correct type
let provider = InMemoryProvider(values: [
    AbsoluteConfigKey("port"): ConfigValue(.int(8080), isSecret: false)
])
```

## License

Apache 2.0

## Resources

- [Official Documentation](https://github.com/apple/swift-configuration)
- [Swift Forums](https://forums.swift.org)

---

**Made with ❤️ by the Swift Community**
