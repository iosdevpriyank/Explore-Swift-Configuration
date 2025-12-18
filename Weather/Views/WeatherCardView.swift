//
//  WeatherCardView.swift
//  Weather
//
//  Created by Akshat Gandhi on 17/12/25.
//

import SwiftUI
import Configuration

struct WeatherCardView: View {
    let weather: WeatherData
    @Environment(\.config) private var config
    
    var body: some View {
        VStack(spacing: 16) {
            Text(weather.city)
                .font(.title)
                .fontWeight(.bold)
            
            Text(weather.displayTemperature)
                .font(.system(size: 60.0, weight: .light))
            
            Text(weather.condition)
                .font(.title3)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 40) {
                VStack {
                    Text("Humidity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(weather.humidity)%")
                        .font(.headline)
                }
                
                VStack {
                    Text("Wind Speed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(displayWindSpeed)
                        .font(.headline)
                }
            }
            .padding(.top)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(.rect(cornerRadius: 20))
    }
    
    private var displayTemperature: String {
        let useMetric = config.bool(
            forKey: AppConfiguration.Keys.featureMetric,
            default: true
        )
        
        if useMetric {
            return String(format: "%.1f°C", weather.temperature)
        } else {
            let fahrenheit = weather.temperature * 9/5 + 32
            return String(format: "%.1f°F", fahrenheit)
        }
    }
    
    private var displayWindSpeed: String {
        let useMetric = config.bool(
            forKey: AppConfiguration.Keys.featureMetric,
            default: true
        )
        
        if useMetric {
            return String(format: "%.1f km/h", weather.windSpeed)
        } else {
            let mph = weather.windSpeed * 0.621371
            return String(format: "%.1f mph", mph)
        }
    }
}

#Preview {
    WeatherCardView(weather: WeatherData(city: "Ahmedabad", temperature: 42.0, condition: "Cloudy", humidity: 20, windSpeed: 22.5))
}
