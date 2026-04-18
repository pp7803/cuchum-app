import Cocoa
import FlutterMacOS
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    FirebaseApp.configure()

    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      if let error = error {
        print("[FCM/APNs macOS] Authorization error: \(error.localizedDescription)")
        return
      }
      print("[FCM/APNs macOS] Authorization granted: \(granted)")
      DispatchQueue.main.async {
        NSApplication.shared.registerForRemoteNotifications(matching: [.alert, .badge, .sound])
      }
    }

    super.applicationDidFinishLaunching(notification)
  }

  override func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("[FCM/APNs macOS] APNs token: \(token)")
  }

  override func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("[FCM/APNs macOS] Failed to register for APNs: \(error.localizedDescription)")
  }
  
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
