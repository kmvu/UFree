//
//  SplashView.swift
//  UFree
//
//  Created by Khang Vu on 3/1/26.
//

import SwiftUI

struct SplashView: View {
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            // Subtle centered circle that pulses
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 120, height: 120)
                .scaleEffect(isVisible ? 1.0 : 0.8)
                .opacity(isVisible ? 0.6 : 0.3)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isVisible = true
            }
        }
    }
}

#Preview {
    SplashView()
}
