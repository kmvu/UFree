//
//  CryptoUtils.swift
//  UFree
//
//  Created by Khang Vu on 05/01/26.
//

import Foundation
import CryptoKit

public struct CryptoUtils {

    // MARK: - Core Hash Primitive

    /// Produces a SHA-256 hex string for an already-normalised digit string.
    /// - Parameter digits: A non-empty string containing only decimal digits.
    /// - Returns: SHA-256 hex string.
    private static func sha256Hex(_ digits: String) -> String {
        let data = Data(digits.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Public API

    /// Converts a raw phone number string into a single privacy-safe SHA-256 hash.
    ///
    /// Normalization: strips every character except ASCII decimal digits.
    /// e.g. `"+1 (555) 123-4567"` → `"15551234567"` → hash.
    ///
    /// - Parameter phoneNumber: Any raw phone number string.
    /// - Returns: A SHA-256 hex string, or `nil` if no digits are present.
    public static func hashPhoneNumber(_ phoneNumber: String) -> String? {
        let digits = phoneNumber.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return sha256Hex(digits)
    }

    /// Returns **all candidate hashes** for a phone number so that different
    /// formatting conventions (local vs. E.164) still match in Firestore.
    ///
    /// Strategy — given raw input we generate up to **two** canonical digit strings:
    ///
    /// | Input example         | Digit string 1 | Digit string 2 (E.164 variant) |
    /// |----------------------|----------------|-------------------------------|
    /// | `"+61412345678"`     | `"61412345678"` | *(same, already international)* |
    /// | `"0412345678"`       | `"0412345678"`  | `"61412345678"` (AU: strip 0, prepend 61) |
    /// | `"+15551234567"`     | `"15551234567"` | *(same)*                        |
    /// | `"5551234567"` (US)  | `"5551234567"`  | `"15551234567"` (US: prepend 1) |
    ///
    /// Both hashes are stored in `UserProfile.hashedPhoneNumbers` (array field) at
    /// registration time and queried via Firestore `array-contains-any`.
    ///
    /// - Parameter phoneNumber: Any raw phone number string.
    /// - Returns: 1-2 unique SHA-256 hashes, ordered deterministically (raw first).
    ///            Empty if the input contains no digits.
    public static func phoneNumberHashes(for phoneNumber: String) -> [String] {
        // Strip all non-digit characters while noting whether the original had a '+'
        let hasPlus = phoneNumber.hasPrefix("+") || phoneNumber.contains("+")
        let digits = phoneNumber.filter(\.isNumber)

        guard !digits.isEmpty else { return [] }

        var candidates: [String] = []

        if hasPlus {
            // Already in international form — the digit string IS the E.164 body.
            // Only one canonical form: the raw digits (country code included, no '+').
            candidates.append(digits)
        } else {
            // No '+' — could be local format.
            candidates.append(digits)

            // Heuristic E.164 variants based on common leading-digit patterns:
            // • Leading "0"  → likely national trunk prefix (AU/UK/DE/…).
            //                   Strip the '0' and store as-is (caller can prepend country
            //                   code at registration if they know it, but we also store the
            //                   stripped variant to maximise collision probability).
            // • 10 digits, no leading 0 → likely US/CA NANP local; prepend "1".
            if digits.hasPrefix("0") {
                let stripped = String(digits.dropFirst())
                if !stripped.isEmpty {
                    candidates.append(stripped)
                }
            } else if digits.count == 10 {
                // US/CA NANP: prepend country code 1
                candidates.append("1" + digits)
            }
        }

        // Deduplicate while preserving order, then hash each candidate.
        var seen = Set<String>()
        return candidates
            .filter { seen.insert($0).inserted }
            .map { sha256Hex($0) }
    }
}
