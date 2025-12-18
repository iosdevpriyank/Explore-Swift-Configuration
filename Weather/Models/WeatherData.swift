//
//  WeatherData.swift
//  Weather
//
//  Created by Akshat Gandhi on 15/12/25.
//

import Foundation

struct WeatherData: Decodable {
    let city: String
    let temperature: Double
    let condition: String
    let humidity: Int
    let windSpeed: Double
    
    var displayTemperature: String {
        // This would use config to determine metric/imperial
        return String(format: "%.1f°C", temperature)
    }
}
