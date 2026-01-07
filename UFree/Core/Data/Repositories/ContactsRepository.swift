//
//  ContactsRepository.swift
//  UFree
//
//  Created by Khang Vu on 05/01/26.
//

import Foundation
import Contacts

// MARK: - Protocol
public protocol ContactsRepositoryProtocol {
    /// Requests access to the user's contacts.
    /// - Returns: Bool indicating if access was granted.
    func requestAccess() async -> Bool

    /// Fetches all phone numbers from the address book and returns them as SHA-256 hashes.
    /// - Returns: An array of unique hashed strings.
    func fetchHashedContacts() async throws -> [String]
}

// MARK: - Implementation
public final class AppleContactsRepository: ContactsRepositoryProtocol {

    private let store = CNContactStore()

    public init() {}

    public func requestAccess() async -> Bool {
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            print("⚠️ Contact access denied or failed: \(error)")
            return false
        }
    }

    public func fetchHashedContacts() async throws -> [String] {
        // 1. Check Authorization (with retry for timing)
        var status = CNContactStore.authorizationStatus(for: .contacts)
        
        // If pending/not yet determined, request again
        if status != .authorized {
            let granted = try await requestAccess()
            if !granted {
                throw NSError(domain: "UFree", code: 403, userInfo: [NSLocalizedDescriptionKey: "Contacts permission not granted."])
            }
            // Small delay to allow status to propagate
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }

        // 2. Define what we need (Phone Numbers only)
        let keys = [CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)

        var hashes: Set<String> = [] // Use Set to avoid duplicates
        var totalContacts = 0
        var contactsWithPhoneNumbers = 0
        var failedHashes = 0

        // 3. Fetch and Process
        do {
            try store.enumerateContacts(with: request) { (contact, stop) in
                totalContacts += 1
                
                if !contact.phoneNumbers.isEmpty {
                    contactsWithPhoneNumbers += 1
                }
                
                for phoneNumber in contact.phoneNumbers {
                    let rawString = phoneNumber.value.stringValue
                    print("📱 Processing phone: \(rawString)")

                    if let hash = CryptoUtils.hashPhoneNumber(rawString) {
                        hashes.insert(hash)
                        print("✅ Hashed: \(hash)")
                    } else {
                        failedHashes += 1
                        print("❌ Failed to hash: \(rawString)")
                    }
                }
            }
        } catch {
            print("❌ Error enumerating contacts: \(error)")
            throw NSError(domain: "UFree", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to read contacts: \(error.localizedDescription)"])
        }

        print("📊 Diagnostics:")
        print("   Total contacts: \(totalContacts)")
        print("   Contacts with phone numbers: \(contactsWithPhoneNumbers)")
        print("   Failed hashes: \(failedHashes)")
        print("   Unique hashes: \(hashes.count)")
        
        guard !hashes.isEmpty else {
            if totalContacts == 0 {
                throw NSError(domain: "UFree", code: 404, userInfo: [NSLocalizedDescriptionKey: "No contacts found in your address book."])
            } else if contactsWithPhoneNumbers == 0 {
                throw NSError(domain: "UFree", code: 404, userInfo: [NSLocalizedDescriptionKey: "No contacts with phone numbers found."])
            } else {
                throw NSError(domain: "UFree", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to process contact phone numbers."])
            }
        }
        
        return Array(hashes)
    }
}
