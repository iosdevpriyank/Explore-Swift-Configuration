//
//  ErrorView.swift
//  Weather
//
//  Created by Akshat Gandhi on 16/12/25.
//

import SwiftUI

struct ErrorView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            
            Text("Configuration Error")
                .font(.title)
                .fontWeight(.bold)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: retry) {
                HStack {
                    Text("Retry")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Image(systemName: "arrow.2.circlepath.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    ErrorView(error: ConfigError.fileNotFound("featurs.json")) {
        print("Retry")
    }
}
