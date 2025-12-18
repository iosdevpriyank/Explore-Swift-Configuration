//
//  WeatherService.swift
//  Weather
//
//  Created by Akshat Gandhi on 15/12/25.
//
import Configuration
import Foundation

class WeatherService {
    private let config: ConfigReader
    private let session: URLSession
    
    init(config: ConfigReader) {
        self.config = config
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(
            config.int(forKey: AppConfiguration.Keys.apiTimeout, default: 30)
        )
        self.session = URLSession(configuration: configuration)
    }
    
    func fetchWeather(for city: String) async throws -> WeatherData {
        let baseURL = config.string(
            forKey: AppConfiguration.Keys.apiBaseURL,
            default: "https://api.weatherapp.com"
        )
        
        guard let url = URL(string: "\(baseURL)/weather?city=\(city)") else {
            throw WeatherError.invalidURL
        }
        
        // Check cache first
        if config.bool(forKey: AppConfiguration.Keys.cacheEnabled, default: true),
           let cached = WeatherCache.shared.get(city) {
            return cached
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WeatherError.invalidResponse
        }
        
        let weather = try JSONDecoder().decode(WeatherData.self, from: data)
        
        // Cache the result
        if config.bool(forKey: AppConfiguration.Keys.cacheEnabled, default: true) {
            let duration = config.int(forKey: AppConfiguration.Keys.cacheDuration, default: 3600)
            WeatherCache.shared.set(weather, for: city, duration: TimeInterval(duration))
        }
        
        return weather
    }
}
