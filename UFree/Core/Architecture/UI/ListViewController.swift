//
//  ListViewController.swift
//  UFree
//
//  A minimal list-style screen backed by SwiftUI. It currently shows a
//  single "Hello, world!" row and supports refresh/error/loading hooks
//  required by the clean architecture adapters.
//

import UIKit
import SwiftUI
import Combine

public final class ListViewController: UIViewController, ResourceLoadingView, ResourceErrorView {
    var onRefresh: (() -> Void)?
    
    private let viewModel = Model()
    private var hostingController: UIHostingController<RootView>?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let hosting = UIHostingController(rootView: RootView(
            model: viewModel,
            onRefresh: { [weak self] in self?.onRefresh?() }
        ))
        
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(hosting.view)
        
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
        
        hostingController = hosting
    }
    
    // MARK: - ResourceLoadingView
    public func display(_ viewModel: ResourceLoadingViewModel) {
        self.viewModel.isLoading = viewModel.isLoading
    }
    
    // MARK: - ResourceErrorView
    public func display(_ viewModel: ResourceErrorViewModel) {
        self.viewModel.errorMessage = viewModel.message
    }
}

// MARK: - SwiftUI backing view

private extension ListViewController {
    final class Model: ObservableObject {
        @Published var isLoading: Bool = false
        @Published var errorMessage: String?
    }
    
    struct RootView: View {
        @ObservedObject var model: Model
        var onRefresh: () -> Void
        
        var body: some View {
            List {
                Section {
                    Text("Hello, world!")
                }
                
                if let error = model.errorMessage {
                    Section("Error") {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .overlay(alignment: .top) {
                if model.isLoading {
                    ProgressView().padding()
                }
            }
            .refreshable {
                onRefresh()
            }
        }
    }
}

// MARK: - SwiftUI Preview

#if DEBUG
struct ListViewController_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                PreviewWrapper()
                    .navigationTitle("Preview")
            }
            .preferredColorScheme(.light)
            
            NavigationView {
                PreviewWrapper()
                    .navigationTitle("Preview")
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private struct PreviewWrapper: UIViewControllerRepresentable {
        func makeUIViewController(context: Context) -> ListViewController {
            let vc = ListViewController()
            vc.display(ResourceLoadingViewModel(isLoading: false))
            vc.display(ResourceErrorViewModel.noError)
            return vc
        }
        
        func updateUIViewController(_ uiViewController: ListViewController,
                                    context: Context) {
            // Static preview; no updates needed
        }
    }
}
#endif

