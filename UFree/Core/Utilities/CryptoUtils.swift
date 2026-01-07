//
//  CryptoUtils.swift
//  UFree
//
//  Created by Khang Vu on 05/01/26.
//

import Foundation
import CryptoKit

public struct CryptoUtils {
    
    /// Converts a phone number into a privacy-safe SHA-256 hash.
    /// - Parameter phoneNumber: The raw phone number string (e.g., "(555) 123-4567")
    /// - Returns: A SHA-256 hash string, or nil if the number is invalid.
    public static func hashPhoneNumber(_ phoneNumber: String) -> String? {
        // 1. Normalize: Remove all non-numeric characters (except '+')
        // We want "+15551234567" to match "555-123-4567" if possible,
        // but for MVP consistency, we often strip everything to pure digits.
        // Let's strip to pure digits to ensure maximum matching compatibility.
        let allowed = CharacterSet.decimalDigits
        let cleanedNumber = phoneNumber.components(separatedBy: allowed.inverted).joined()
        
        guard !cleanedNumber.isEmpty else { return nil }
        
        // 2. Convert to Data
        guard let data = cleanedNumber.data(using: .utf8) else { return nil }
        
        // 3. Hash using SHA-256 (Standard for privacy matching)
        let digest = SHA256.hash(data: data)
        
        // 4. Return as Hex String
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
