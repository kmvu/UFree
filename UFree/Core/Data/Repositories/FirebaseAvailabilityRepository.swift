//
//  FirebaseAvailabilityRepository.swift
//  UFree
//
//  Created by Khang Vu on 31/12/25.
//

import Foundation

/// Remote availability repository using Firebase Firestore.
/// Sprint 2.5: Skeleton implementation. Methods throw "Not implemented yet".
/// Sprint 3: Implement actual Firestore read/write operations.
@MainActor
public final class FirebaseAvailabilityRepository: AvailabilityRepository {
    public init() {}
    
    public func getMySchedule() async throws -> UserSchedule {
        throw NSError(
            domain: "FirebaseAvailabilityRepository",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Not implemented yet"]
        )
    }
    
    public func updateMySchedule(for day: DayAvailability) async throws {
        throw NSError(
            domain: "FirebaseAvailabilityRepository",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Not implemented yet"]
        )
    }
    
    public func getFriendsSchedules() async throws -> [UserSchedule] {
        throw NSError(
            domain: "FirebaseAvailabilityRepository",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Not implemented yet"]
        )
    }
}
