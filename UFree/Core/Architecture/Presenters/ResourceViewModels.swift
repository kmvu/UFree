//
//  ResourceViewModels.swift
//  Core Architecture
//

import Foundation

public struct ResourceLoadingViewModel {
    public let isLoading: Bool
    
    public init(isLoading: Bool) {
        self.isLoading = isLoading
    }
}

public struct ResourceErrorViewModel {
    public let message: String?
    
    public static var noError: ResourceErrorViewModel {
        return ResourceErrorViewModel(message: nil)
    }
    
    public static func error(message: String) -> ResourceErrorViewModel {
        return ResourceErrorViewModel(message: message)
    }
}
