import Flutter
import UIKit
import UserNotifications
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    // Repair the shared widget snapshot from the app's local records on upgrade/foreground.
    NotificationCenter.default.addObserver(self, selector: #selector(syncWidgetSnapshot), name: UIApplication.didBecomeActiveNotification, object: nil)
    syncWidgetSnapshot()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @objc private func syncWidgetSnapshot() {
    let group = "group.com.birthdaycalendar.shared"
    guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil,
          let raw = UserDefaults.standard.string(forKey: "flutter.birthdays"),
          let data = raw.data(using: .utf8),
          (try? JSONSerialization.jsonObject(with: data)) is [[String: Any]],
          let shared = UserDefaults(suiteName: group) else { return }
    guard shared.string(forKey: "birthdays") != raw else { return }
    shared.set(raw, forKey: "birthdays")
    WidgetCenter.shared.reloadTimelines(ofKind: "BirthdayWidget")
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
