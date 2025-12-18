//
//  WeatherCache.swift
//  Weather
//
//  Created by Akshat Gandhi on 15/12/25.
//
import Foundation

class WeatherCache {
    static let shared = WeatherCache()
    
    private var cache: [String: (data: WeatherData, expiry: Date)] = [:]
    
    func get(_ key: String) -> WeatherData? {
        guard let entry = cache[key],
              entry.expiry > Date() else {
            cache.removeValue(forKey: key)
            return nil
        }
        return entry.data
    }
    
    func set(_ data: WeatherData, for key: String, duration: TimeInterval) {
        cache[key] = (data, Date().addingTimeInterval(duration))
    }
}
