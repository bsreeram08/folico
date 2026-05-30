import Foundation
import UserNotifications

final class FolicoNotificationService: NSObject, UNUserNotificationCenterDelegate {
    private var center: UNUserNotificationCenter?

    override init() {
        super.init()
    }

    func requestAuthorizationIfNeeded() {
        guard let center = notificationCenter() else { return }
        center.getNotificationSettings { [center] settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    func notify(title: String, body: String) {
        guard let center = notificationCenter() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: "folico-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    private func notificationCenter() -> UNUserNotificationCenter? {
        if let center {
            return center
        }

        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return nil
        }

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        self.center = center
        return center
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}
