//
//  DebugInfoView.swift
//  Weather
//
//  Created by Akshat Gandhi on 17/12/25.
//

import SwiftUI
import Configuration

struct DebugInfoView: View {
    @Environment(\.config) private var config
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Info")
                .font(.headline)
            Group {
                debugRow("Environment", AppConfiguration.Environment.current)
                debugRow("API URL", config.string(forKey: AppConfiguration.Keys.apiBaseURL, default: "N/A"))
                debugRow("Timeout", "\(config.int(forKey: AppConfiguration.Keys.apiTimeout, default: 0))s")
                debugRow("Cache", config.bool(forKey: AppConfiguration.Keys.cacheEnabled, default: false) ? "Enabled" : "Disabled")
                debugRow("Metric", config.bool(forKey: AppConfiguration.Keys.featureMetric, default: true) ? "Yes" : "No")
            }
        }
        .font(.caption)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func debugRow(_ label: String, _ value: Any) -> some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Spacer()
            Text(LocalizedStringResource(stringLiteral: "\(value)"))
                .fontWeight(.medium)
        }
    }
}

#Preview {
    DebugInfoView()
}
