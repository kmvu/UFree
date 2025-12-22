//
//  ContentView.swift
//  UFree
//
//  Created by Khang Vu on 19/12/25.
//

import SwiftUI
import Combine

// Simple bridge to render the UIKit ListViewController via SwiftUI
struct UpdateMyStatusUseCaseView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ListViewController {
        UpdateMyStatusUseCaseComposer.LUpdateMyStatusUseCaseComposedWith(
            loader: {
                Just(UpdateMyStatusUseCase(id: UUID()))
                    .delay(for: .milliseconds(500), scheduler: DispatchQueue.main)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
        )
    }
    
    func updateUIViewController(_ uiViewController: ListViewController, context: Context) {
        // No-op: stateless demo view
    }
}

struct ContentView: View {
    var body: some View {
        UpdateMyStatusUseCaseView()
    }
}

#Preview {
    ContentView()
}
