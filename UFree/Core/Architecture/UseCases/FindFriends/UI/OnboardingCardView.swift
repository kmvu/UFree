//
//  OnboardingCardView.swift
//  UFree
//
//  Created by Khang Vu on 5/2/26.
//

import SwiftUI

public struct OnboardingCardView: View {
    let action: () -> Void
    
    public init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Icon with soft gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.15), Color.accentColor.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.accentColor)
                    .symbolEffect(.bounce, options: .repeating)
            }
            .padding(.top, 8)
            
            VStack(spacing: 10) {
                Text("Schedule looks quiet!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Add friends to see when they're free and start planning your next hangout.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button(action: {
                HapticManager.medium()
                action()
            }) {
                HStack(spacing: 10) {
                    Text("Invite Friends")
                        .fontWeight(.bold)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(18)
                .shadow(color: Color.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(InteractiveButtonStyle())
            .padding(.horizontal, 10)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color(UIColor.systemGroupedBackground).ignoresSafeArea()
        
        OnboardingCardView(action: {})
            .padding()
    }
}
