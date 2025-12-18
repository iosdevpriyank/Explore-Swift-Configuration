//
//  WeatherError.swift
//  Weather
//
//  Created by Akshat Gandhi on 15/12/25.
//


enum WeatherError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
}