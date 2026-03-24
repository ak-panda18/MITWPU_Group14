import Foundation
import UserNotifications
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AksharApp", category: "ProfileStore")

// MARK: - ProfileStore
final class ProfileStore {

    // MARK: - UserDefaults Keys
    private func enabledKey(_ uid: String)  -> String { "reminder_enabled_\(uid)" }
    private func daysKey(_ uid: String)     -> String { "reminder_days_\(uid)" }
    private func hourKey(_ uid: String)     -> String { "reminder_hour_\(uid)" }
    private func minuteKey(_ uid: String)   -> String { "reminder_minute_\(uid)" }
    private func lastOpenKey(_ uid: String) -> String { "last_open_date_\(uid)" }

    // MARK: - Reminder Enabled
    func isReminderEnabled(uid: String) -> Bool {
        guard UserDefaults.standard.object(forKey: enabledKey(uid)) != nil else { return true }
        return UserDefaults.standard.bool(forKey: enabledKey(uid))
    }

    func setReminderEnabled(_ enabled: Bool, uid: String) {
        UserDefaults.standard.set(enabled, forKey: enabledKey(uid))
    }

    // MARK: - Reminder Days
    func reminderDays(uid: String) -> [Bool] {
        guard let data = UserDefaults.standard.data(forKey: daysKey(uid)),
              let days = try? JSONDecoder().decode([Bool].self, from: data),
              days.count == 7
        else { return Array(repeating: true, count: 7) }
        return days
    }

    func setReminderDays(_ days: [Bool], uid: String) {
        if let data = try? JSONEncoder().encode(days) {
            UserDefaults.standard.set(data, forKey: daysKey(uid))
        }
    }

    // MARK: - Reminder Time
    func reminderHour(uid: String) -> Int {
        let v = UserDefaults.standard.integer(forKey: hourKey(uid))
        return v == 0 ? 17 : v
    }

    func reminderMinute(uid: String) -> Int {
        UserDefaults.standard.integer(forKey: minuteKey(uid))
    }

    func setReminderTime(hour: Int, minute: Int, uid: String) {
        UserDefaults.standard.set(hour,   forKey: hourKey(uid))
        UserDefaults.standard.set(minute, forKey: minuteKey(uid))
    }

    // MARK: - Last Open Date
    func recordAppOpen(uid: String) {
        let today = Calendar.current.startOfDay(for: Date())
        if let data = try? JSONEncoder().encode(today) {
            UserDefaults.standard.set(data, forKey: lastOpenKey(uid))
        }
    }

    func wasAppOpenedToday(uid: String) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: lastOpenKey(uid)),
              let date = try? JSONDecoder().decode(Date.self, from: data)
        else { return false }
        return Calendar.current.isDateInToday(date)
    }

    // MARK: - Schedule / Cancel
    func scheduleNotifications(uid: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { self.reschedule(uid: uid, center: center) }
        }
    }

    func cancelAllNotifications() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: allIDs())
    }

    // MARK: - Private
    private func allIDs() -> [String] { (0..<7).map { "akshar_day_\($0)" } }

    private func reschedule(uid: String, center: UNUserNotificationCenter) {
        center.removePendingNotificationRequests(withIdentifiers: allIDs())
        guard isReminderEnabled(uid: uid) else { return }

        let days      = reminderDays(uid: uid)
        let hour      = reminderHour(uid: uid)
        let minute    = reminderMinute(uid: uid)
        let weekdayMap = [2, 3, 4, 5, 6, 7, 1]

        for (i, isOn) in days.enumerated() {
            guard isOn else { continue }

            let content      = UNMutableNotificationContent()
            content.title    = "Time to learn!"
            content.body     = "Akshar is waiting for you. Keep your streak going!"
            content.sound    = .default
            content.userInfo = ["uid": uid]

            var dc        = DateComponents()
            dc.hour       = hour
            dc.minute     = minute
            dc.weekday    = weekdayMap[i]

            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            let request = UNNotificationRequest(
                identifier: "akshar_day_\(i)",
                content:    content,
                trigger:    trigger
            )
            center.add(request) { error in
                if let error {
                    logger.error("ProfileStore: failed to schedule notification day \(i) – \(error)")
                }
            }
        }
    }
}
