import OSLog
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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private let widgetQueue = DispatchQueue(label: "iyiki.widget.publish")

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "iyiki/widgetSnapshot", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { [widgetQueue] call, result in
      guard call.method == "publish" else { result(FlutterMethodNotImplemented); return }
      guard let raw = call.arguments as? String else {
        result(FlutterError(code: "invalidSnapshot", message: nil, details: nil))
        return
      }
      widgetQueue.async {
        do {
          let snapshot = try WidgetStore.publish(Data(raw.utf8))
          WidgetStore.log.info("runner writeVerified revision=\(snapshot.revision.uuidString, privacy: .public) count=\(snapshot.events.count, privacy: .public)")
          DispatchQueue.main.async {
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetStore.kind)
            result(nil)
          }
        } catch {
          let code = (error as? WidgetStoreError)?.rawValue ?? "writeFailed"
          WidgetStore.log.error("runner publishFailed reason=\(code, privacy: .public)")
          DispatchQueue.main.async { result(FlutterError(code: code, message: nil, details: nil)) }
        }
      }
    }
  }
}
