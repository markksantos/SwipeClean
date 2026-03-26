import Foundation
import UserNotifications

final class ReminderManager {
    static let shared = ReminderManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let notificationIdentifier = "com.swipeclean.cleanup-reminder"

    private let bodies = [
        "Your photo library could use some love.",
        "Time to swipe through your recent photos!",
        "A quick cleanup keeps your library fresh.",
        "Got a few minutes? Swipe away the clutter.",
        "New photos piling up — let's clean house!"
    ]

    private init() {}

    // MARK: - Public API

    /// Enables reminders: requests permission, then schedules.
    func enableReminders(frequency: ReminderFrequency) {
        requestPermission { [weak self] granted in
            guard granted, let self else { return }
            self.scheduleNotification(frequency: frequency)
        }
    }

    /// Disables reminders by cancelling all pending notifications.
    func disableReminders() {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier, "\(notificationIdentifier)-biweekly"]
        )
    }

    /// Reschedules with a new frequency (cancels existing first).
    func updateFrequency(_ frequency: ReminderFrequency) {
        disableReminders()
        scheduleNotification(frequency: frequency)
    }

    // MARK: - Private

    private func requestPermission(completion: @escaping (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    private func scheduleNotification(frequency: ReminderFrequency) {
        let content = UNMutableNotificationContent()
        content.title = "Time to clean up!"
        content.body = bodies.randomElement() ?? bodies[0]
        content.sound = .default

        // Build a date components trigger based on frequency.
        // Fire at 10:00 AM on the appropriate weekday / day-of-month.
        var dateComponents = DateComponents()
        dateComponents.hour = 10
        dateComponents.minute = 0

        switch frequency {
        case .weekly:
            // Every Sunday
            dateComponents.weekday = 1
        case .biweekly:
            // UNCalendarNotificationTrigger doesn't support "every 2 weeks" natively.
            // Use day 1 and 15 of each month as a close approximation.
            // We schedule the "1st of month" trigger; the 15th is added as a second request.
            dateComponents.day = 1
            scheduleExtraBiweeklyTrigger()
        case .monthly:
            // 1st of every month
            dateComponents.day = 1
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)

        notificationCenter.add(request)
    }

    /// Adds a second trigger on the 15th for the biweekly approximation.
    private func scheduleExtraBiweeklyTrigger() {
        let content = UNMutableNotificationContent()
        content.title = "Time to clean up!"
        content.body = bodies.randomElement() ?? bodies[0]
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 10
        dateComponents.minute = 0
        dateComponents.day = 15

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "\(notificationIdentifier)-biweekly", content: content, trigger: trigger)

        notificationCenter.add(request)
    }
}
