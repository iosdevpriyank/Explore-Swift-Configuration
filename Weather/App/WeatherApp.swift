//
//  WeatherApp.swift
//  Weather
//
//  Created by Akshat Gandhi on 15/12/25.
//

import SwiftUI

@main
struct WeatherApp: App {
    @State private var configManager = ConfigurationManager()
    var body: some Scene {
        WindowGroup {
            SwiftUI.Group {
                if configManager.isLoading {
                    LoadingView()
                } else if let error = configManager.error {
                    ErrorView(error: error) {
                        Task(name: "Reload Configuration") {
                            await configManager.reload()
                        }
                    }
                } else {
                    MainView()
                        .environment(\.config, configManager.config)
                }
            }
        }
    }
}
