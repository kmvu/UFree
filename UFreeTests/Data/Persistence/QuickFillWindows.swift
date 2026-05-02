import Foundation

public struct QuickFillWindows {
    public static let morningStartHour: Int = 9
    public static let morningEndHour: Int = 12
    public static let afternoonEndHour: Int = 17
    public static let activeEndHour: Int = 22

    public struct Boundaries {
        public let startOfDay: Date
        public let endOfDay: Date
        public let activeStart: Date      // 09:00
        public let morningEnd: Date       // 12:00
        public let afternoonStart: Date   // 12:00
        public let afternoonEnd: Date     // 17:00
        public let eveningStart: Date     // 17:00
        public let activeEnd: Date        // 22:00
    }

    public static func boundaries(for date: Date, calendar: Calendar = .current) -> Boundaries {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        let activeStart = calendar.date(bySettingHour: morningStartHour, minute: 0, second: 0, of: startOfDay)!
        let morningEnd = calendar.date(bySettingHour: morningEndHour, minute: 0, second: 0, of: startOfDay)!
        let afternoonStart = morningEnd
        let afternoonEnd = calendar.date(bySettingHour: afternoonEndHour, minute: 0, second: 0, of: startOfDay)!
        let eveningStart = afternoonEnd
        let activeEnd = calendar.date(bySettingHour: activeEndHour, minute: 0, second: 0, of: startOfDay)!

        return Boundaries(
            startOfDay: startOfDay,
            endOfDay: endOfDay,
            activeStart: activeStart,
            morningEnd: morningEnd,
            afternoonStart: afternoonStart,
            afternoonEnd: afternoonEnd,
            eveningStart: eveningStart,
            activeEnd: activeEnd
        )
    }
}
