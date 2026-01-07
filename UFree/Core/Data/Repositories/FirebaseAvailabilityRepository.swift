//
//  FirebaseAvailabilityRepository.swift
//  UFree
//
//  Created by Khang Vu on 31/12/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class FirebaseAvailabilityRepository: AvailabilityRepository {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    // MARK: - Write (Update Status)

    func updateMySchedule(for day: DayAvailability) async throws {
        // 1. Authenticate
        guard let uid = auth.currentUser?.uid else {
            throw NSError(
                domain: "UFree",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not logged in"]
            )
        }

        // 2. Prepare Path: users/{uid}/availability/{yyyy-MM-dd}
        let dateString = DateFormatter.yyyyMMdd.string(from: day.date)
        let docRef = db.collection("users")
            .document(uid)
            .collection("availability")
            .document(dateString)

        // 3. Convert to DTO & Write
        let data = FirestoreDayDTO.fromDomain(day)

        // merge: true ensures we don't overwrite fields we didn't touch (like 'createdAt')
        try await docRef.setData(data, merge: true)
    }

    // MARK: - Read (Get My Schedule)

    func getMySchedule() async throws -> UserSchedule {
        guard let currentUser = auth.currentUser else {
            throw NSError(
                domain: "UFree",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not logged in"]
            )
        }

        // 1. Define the range (Today -> Next 7 days)
        let today = Date()
        let todayString = DateFormatter.yyyyMMdd.string(from: today)

        // 2. Query Firestore
        // "Get documents in 'availability' collection where ID is >= Today"
        // This efficiently fetches only future dates.
        let snapshot = try await db.collection("users")
            .document(currentUser.uid)
            .collection("availability")
            .whereField(FieldPath.documentID(), isGreaterThanOrEqualTo: todayString)
            .limit(to: 7) // Optimization: Don't fetch the whole year
            .getDocuments()

        // 3. Map Firestore Documents -> Domain Entities
        var fetchedDays: [DayAvailability] = []

        for doc in snapshot.documents {
            // Decode the DTO
            if let dto = try? doc.data(as: FirestoreDayDTO.self),
               let date = DateFormatter.yyyyMMdd.date(from: dto.dateString) {
                fetchedDays.append(dto.toDomain(originalDate: date))
            }
        }

        // 4. Merge with a "Full Week" structure
        // Firestore might only return 3 days if the user hasn't set the other 4.
        // We need to fill in the gaps with "Unknown" status to keep the UI happy.
        let fullWeek = normalizeToFullWeek(fetchedDays: fetchedDays, startDate: today)

        return UserSchedule(
            id: currentUser.uid,
            name: currentUser.displayName ?? "Me",
            avatarURL: currentUser.photoURL,
            weeklyStatus: fullWeek
        )
    }

    // MARK: - Helper (Gap Filling)

    private func normalizeToFullWeek(fetchedDays: [DayAvailability], startDate: Date) -> [DayAvailability] {
        var result: [DayAvailability] = []
        let calendar = Calendar.current

        // Loop 0 to 6 (Next 7 days)
        for i in 0 ..< 7 {
            guard let targetDate = calendar.date(byAdding: .day, value: i, to: startDate) else { continue }
            let targetString = DateFormatter.yyyyMMdd.string(from: targetDate)

            // Did we fetch data for this day?
            if let existing = fetchedDays.first(where: { DateFormatter.yyyyMMdd.string(from: $0.date) == targetString }) {
                result.append(existing)
            } else {
                // No? Return an empty "Unknown" day
                result.append(DayAvailability(date: targetDate, status: .unknown))
            }
        }
        return result
    }

    // MARK: - Friends' Schedules (Parallel Fetching)

    func getSchedules(for userIds: [String]) async throws -> [UserSchedule] {
        guard !userIds.isEmpty else { return [] }

        // Firestore 'in' queries are limited to 10 items.
        // If you have >10 friends, we must chunk the requests.
        let chunks = userIds.chunked(into: 10)
        var allSchedules: [UserSchedule] = []

        // Use a TaskGroup to fetch all batches in parallel
        try await withThrowingTaskGroup(of: [UserSchedule].self) { group in
            for chunk in chunks {
                group.addTask {
                    return try await self.fetchBatchSchedules(for: chunk)
                }
            }

            for try await batchSchedules in group {
                allSchedules.append(contentsOf: batchSchedules)
            }
        }

        return allSchedules
    }

    // MARK: - Private Helper for Batch Fetching

    private func fetchBatchSchedules(for userIds: [String]) async throws -> [UserSchedule] {
        guard !userIds.isEmpty else { return [] }

        let today = Date()
        let sevenDaysFromNow = Calendar.current.date(byAdding: .day, value: 7, to: today)!

        var batchResult: [UserSchedule] = []

        // Fetch each friend's availability in parallel
        try await withThrowingTaskGroup(of: UserSchedule?.self) { group in
            for userId in userIds {
                group.addTask {
                    return try await self.fetchUserSchedule(for: userId, from: today, to: sevenDaysFromNow)
                }
            }

            for try await schedule in group {
                if let schedule = schedule {
                    batchResult.append(schedule)
                }
            }
        }

        return batchResult
    }

    private func fetchUserSchedule(for userId: String, from startDate: Date, to endDate: Date) async throws -> UserSchedule? {
        let startString = DateFormatter.yyyyMMdd.string(from: startDate)
        let endString = DateFormatter.yyyyMMdd.string(from: endDate)

        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("availability")
            .whereField(FieldPath.documentID(), isGreaterThanOrEqualTo: startString)
            .whereField(FieldPath.documentID(), isLessThan: endString)
            .getDocuments()

        var days: [DayAvailability] = []

        for doc in snapshot.documents {
            if let dto = try? doc.data(as: FirestoreDayDTO.self),
               let date = DateFormatter.yyyyMMdd.date(from: dto.dateString) {
                days.append(dto.toDomain(originalDate: date))
            }
        }

        // If no availability data found, return nil (not found) rather than empty schedule
        guard !days.isEmpty else { return nil }

        return UserSchedule(
            id: userId,
            name: "Friend", // Note: Would need to fetch UserProfile separately if display name needed
            avatarURL: nil,
            weeklyStatus: days
        )
    }
}
