//
//  ContactsRepository.swift
//  UFree
//
//  Created by Khang Vu on 05/01/26.
//

import Foundation
import Contacts

// MARK: - Protocol
protocol ContactsRepositoryProtocol {
    /// Requests access to the user's contacts.
    /// - Returns: Bool indicating if access was granted.
    func requestAccess() async -> Bool
    
    /// Fetches all phone numbers from the address book and returns them as SHA-256 hashes.
    /// - Returns: An array of unique hashed strings.
    func fetchHashedContacts() async throws -> [String]
}

// MARK: - Implementation
final class AppleContactsRepository: ContactsRepositoryProtocol {
    
    private let store = CNContactStore()
    
    func requestAccess() async -> Bool {
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            print("⚠️ Contact access denied or failed: \(error)")
            return false
        }
    }
    
    func fetchHashedContacts() async throws -> [String] {
        // 1. Check Authorization
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .authorized else {
            throw NSError(domain: "UFree", code: 403, userInfo: [NSLocalizedDescriptionKey: "Contacts permission not granted."])
        }
        
        // 2. Define what we need (Phone Numbers only)
        let keys = [CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        var hashes: Set<String> = [] // Use Set to avoid duplicates
        
        // 3. Fetch and Process
        // Note: this block runs synchronously on the background thread we are on
        try store.enumerateContacts(with: request) { (contact, stop) in
            for phoneNumber in contact.phoneNumbers {
                let rawString = phoneNumber.value.stringValue
                
                if let hash = CryptoUtils.hashPhoneNumber(rawString) {
                    hashes.insert(hash)
                }
            }
        }
        
        print("✅ Processed \(hashes.count) unique contact hashes.")
        return Array(hashes)
    }
}
