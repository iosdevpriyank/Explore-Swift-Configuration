//
//  ConfigurationManager.swift
//  Weather
//
//  Created by Akshat Gandhi on 15/12/25.
//

import Foundation
import Configuration

@Observable
class ConfigurationManager {
    private(set) var config: ConfigReader
    private(set) var isLoading = true
    private(set) var error: Error?
    
    init() {
        // Initialize with empty config
        self.config = ConfigReader(provider: InMemoryProvider(name: "EmptyDefaults", values: [:]))
        
        Task {
            await loadConfiguration()
        }
    }
    
    func loadConfiguration() async {
        isLoading = true
        error = nil
        
        do {
            config = try await AppConfiguration.makeConfigReader()
            isLoading = false
            print("Configuration loaded successfully")
        } catch {
            self.error = error
            isLoading = false
            print("Failed to load configuration: \(error)")
        }
    }
    
    func reload() async {
        await loadConfiguration()
    }
}


