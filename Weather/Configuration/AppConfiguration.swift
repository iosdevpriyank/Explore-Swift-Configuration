//
//  AppConfiguration.swift
//  Weather
//
//  Created by Akshat Gandhi on 15/12/25.
//

import Configuration
import Foundation
import SwiftUI

enum AppConfiguration {
    
    // MARK: - Configuration Keys
    
    enum Keys {
        // API Configuration
        static let apiBaseURL: ConfigKey = "api.baseURL"
        static let apiTimeout: ConfigKey = "api.timeout"
        static let apiRetries: ConfigKey = "api.retries"
        
        // Cache Configuration
        static let cacheEnabled: ConfigKey = "cache.enabled"
        static let cacheDuration: ConfigKey = "cache.duration"
        
        // Feature Flags
        static let featureMetric: ConfigKey = "feature.metric"
        static let featureDarkMode: ConfigKey = "feature.darkMode"
        static let featurePremium: ConfigKey = "feature.premium"
        
        // UI Configuration
        static let animationDuration: ConfigKey = "ui.animationDuration"
        static let refreshInterval: ConfigKey = "ui.refreshInterval"
        
        // Location Configuration
        static let maxLocations: ConfigKey = "locations.max"
        static let defaultLocation: ConfigKey = "locations.default"
        
        // Debug Configuration
        static let debugLogging: ConfigKey = "debug.logging"
        static let showNetworkCalls: ConfigKey = "debug.showNetworkCalls"
    }
    
    enum Environment: String {
        case development
        case staging
        case production
        
        static var current: Environment {
#if DEBUG
            return .development
#else
            guard let envString = Bundle.main.infoDictionary?["APP_ENVIRONMENT"] as? String,
                  let env = Environment(rawValue: envString.lowercased()) else {
                return .production
            }
            return env
#endif
        }
    }
    
    /// Creates the configuration reader with proper provider hierarchy
    static func makeConfigReader() async throws -> ConfigReader {
        var providers: [any ConfigProvider] = []
        
        // 1. Environment-specific overrides (highest priority)
        providers.append(makeEnvironmentProvider())
        
        // 2. Remote feature flags (if available)
        if let remoteProvider = try? await makeRemoteConfigurationProvider() {
            providers.append(remoteProvider)
        }
        
        // 3. Local feature flags from JSON
        if let featureProvider = try? await makeFeatureFlagsProvider() {
            providers.append(featureProvider)
        }
        
        // 4. Base configuration from JSON
        if let baseProvider = try? await makeBaseConfigProvider() {
            providers.append(baseProvider)
        }
        
        // 5. Default values (lowest priority)
        if providers.isEmpty {
            providers.append(makeDefaultsProvider())
        }
        
        return ConfigReader(providers: providers)
    }
    
    // MARK: - Provider Factories
    // environment providers
    private static func makeEnvironmentProvider() -> InMemoryProvider {
        let env = Environment.current
        
        switch env {
        case .development:
            return InMemoryProvider(name: "Development", values: [
                "api.baseURL": "https://dev-api.weatherapp.com",
                "api.timeout": 60,
                "debug.logging": true,
                "feature.premium": true,  // Enable all features in dev
                "locations.max": 100
            ])
        case .staging:
            return InMemoryProvider(name: "Staging", values: [
                "api.baseURL": "https://staging-api.weatherapp.com",
                "api.timeout": 30,
                "debug.logging": true,
                "locations.max": 20
            ])
        case .production:
            return InMemoryProvider(name: "Staging", values: [
                "api.baseURL": "https://api.weatherapp.com",
                "api.timeout": 30,
                "debug.logging": false,
                "locations.max": 10
            ])
        }
    }
    
    private static func makeRemoteConfigurationProvider() async throws -> MutableInMemoryProvider {
        let provider = MutableInMemoryProvider(
            name: "RemoteConfig",
            initialValues: [:]
        )
        
        // Start background sync
        Task.detached {
            while !Task.isCancelled {
                do {
                    // Simulate fetching remote config
                    try await Task.sleep(for: .seconds(300)) // Every 5 minutes
                    
                    // In real app, fetch from your backend
                    let remoteConfig = [
                        "feature.premium": false,
                        "feature.darkMode": true
                    ]
                    
                    for (key, value) in remoteConfig {
                        let configValue = ConfigValue(.bool(value), isSecret: false)
                        provider.setValue(configValue, forKey: AbsoluteConfigKey(stringLiteral: key))
                    }
                } catch {
                    print("Failed to sync remote config: \(error)")
                }
            }
        }
        
        return provider
    }
    
    private static func makeFeatureFlagsProvider() async throws -> InMemoryProvider {
        guard let url = Bundle.main.url(forResource: "features", withExtension: "json") else {
            throw ConfigError.fileNotFound("features.json")
        }

        let json = try loadJSONDictionary(from: url)
        var values: [AbsoluteConfigKey: ConfigValue] = [:]
        flatten(json, into: &values, prefix: [])
        return InMemoryProvider(name: "Features", values: values)
    }
    
    private static func makeBaseConfigProvider() async throws -> InMemoryProvider {
        guard let url = Bundle.main.url(forResource: "config", withExtension: "json") else {
            throw ConfigError.fileNotFound("config.json")
        }

        let json = try loadJSONDictionary(from: url)
        var values: [AbsoluteConfigKey: ConfigValue] = [:]
        flatten(json, into: &values, prefix: [])
        return InMemoryProvider(name: "BaseConfig", values: values)
    }
    
    private static func makeDefaultsProvider() -> InMemoryProvider {
        InMemoryProvider(name: "Defaults", values: [
            // API Configuration
            "api.timeout": 30,
            "api.retries": 3,
            
            // Cache Configuration
            "cache.enabled": true,
            "cache.duration": 3600,
            
            // Feature Flags
            "feature.metric": true,
            "feature.darkMode": false,
            "feature.premium": false,
            
            // Limits
            "locations.max": 5
        ])
    }
    
    // MARK: - JSON Loading Helper
    private static func loadJSONDictionary(from url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw ConfigError.invalidJSON(url.lastPathComponent)
        }
        return json
    }
    
    private static func flatten(_ object: Any, into result: inout [AbsoluteConfigKey: ConfigValue], prefix: [String]) {
        if let dict = object as? [String: Any] {
            // It's a nested object - recurse
            for (key, value) in dict {
                let newPrefix = prefix + [key]
                flatten(value, into: &result, prefix: newPrefix)
            }
        } else {
            // It's a leaf value - convert and store
            let key = AbsoluteConfigKey(prefix)
            if let configValue = convertToConfigValue(object) {
                result[key] = configValue
            }
        }
    }
    
    private static func convertToConfigValue(_ value: Any) -> ConfigValue? {
        let content: ConfigContent
        
        switch value {
        case let string as String:
            content = .string(string)
        case let int as Int:
            content = .int(int)
        case let double as Double:
            content = .double(double)
        case let bool as Bool:
            content = .bool(bool)
        case let array as [String]:
            content = .stringArray(array)
        case let array as [Int]:
            content = .intArray(array)
        case let array as [Double]:
            content = .doubleArray(array)
        case let array as [Bool]:
            content = .boolArray(array)
        default:
            return nil
        }
        
        return ConfigValue(content, isSecret: false)
    }
    
}

// MARK: - Environment Key for SwiftUI

private struct ConfigReaderKey: EnvironmentKey {
    static let defaultValue: ConfigReader = ConfigReader(provider: InMemoryProvider(name: "DefaultEmpty", values: [:]))
}

extension EnvironmentValues {
    var config: ConfigReader {
        get { self[ConfigReaderKey.self] }
        set { self[ConfigReaderKey.self] = newValue }
    }
}

enum ConfigError: Error {
    case fileNotFound(String)
    case invalidJSON(String)
}
