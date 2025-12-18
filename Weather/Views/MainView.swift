//
//  MainView.swift
//  Weather
//
//  Created by Akshat Gandhi on 16/12/25.
//

import SwiftUI
import Configuration

struct MainView: View {
    @Environment(\.config) private var config
    @State private var weatherService: WeatherService?
    @State private var selectedCity = "London"
    @State private var weather: WeatherData?
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let weather = weather {
                    WeatherCardView(weather: weather)
                } else if isLoading {
                    ProgressView("Loading Weather...")
                } else if let error {
                    Text("Failed to load weather: \(error.localizedDescription)")
                        .foregroundStyle(.red)
                }
                
                Button("Refresh") {
                    Task {
                        await loadWeather()
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                if config.bool(forKey: AppConfiguration.Keys.debugLogging, default: false) {
                    DebugInfoView()
                }
            }
            .padding()
            .navigationTitle("Weather App")
            .task {
                weatherService = WeatherService(config: config)
                await loadWeather()
            }
        }
    }
    
    private func loadWeather() async {
        guard let service = weatherService else { return }
        
        isLoading = true
        error = nil
        
        do {
            weather = try await service.fetchWeather(for: selectedCity)
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
}

#Preview {
    MainView()
}
