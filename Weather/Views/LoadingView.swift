//
//  LoadingView.swift
//  Weather
//
//  Created by Akshat Gandhi on 16/12/25.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Loading Configuration...")
                .font(.headline)
        }
    }
}

#Preview {
    LoadingView()
}
