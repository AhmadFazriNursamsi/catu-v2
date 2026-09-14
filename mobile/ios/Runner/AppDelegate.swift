import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var tapChannel: FlutterMethodChannel?
  private var pendingTapData: [String: Any]?
  private var binaryMessenger: FlutterBinaryMessenger?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    application.registerForRemoteNotifications()

    if let remoteNotif = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      pendingTapData = serializeUserInfo(remoteNotif)
    }

    if let messenger = getBinaryMessenger() {
      setupTapChannel(messenger: messenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    self.binaryMessenger = messenger
    setupTapChannel(messenger: messenger)
  }

  func setupTapChannel(messenger: FlutterBinaryMessenger) {
    if tapChannel != nil { return }
    self.binaryMessenger = messenger
    tapChannel = FlutterMethodChannel(name: "catu/notification_tap", binaryMessenger: messenger)
    tapChannel?.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "getInitialTap" {
        result(self?.pendingTapData)
        self?.pendingTapData = nil
      } else if call.method == "clearBadge" {
        if #available(iOS 16.0, *) {
          UNUserNotificationCenter.current().setBadgeCount(0)
        }
        UIApplication.shared.applicationIconBadgeNumber = 0
        result(true)
      } else if call.method == "setBadge" {
        let count = (call.arguments as? [String: Any])?["count"] as? Int ?? 0
        if #available(iOS 16.0, *) {
          UNUserNotificationCenter.current().setBadgeCount(count)
        }
        UIApplication.shared.applicationIconBadgeNumber = count
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    if let pending = pendingTapData {
      tapChannel?.invokeMethod("onTap", arguments: pending)
      pendingTapData = nil
    }
  }

  private func getBinaryMessenger() -> FlutterBinaryMessenger? {
    if let messenger = binaryMessenger { return messenger }
    for scene in UIApplication.shared.connectedScenes {
      if let windowScene = scene as? UIWindowScene {
        for win in windowScene.windows {
          if let flutterVC = win.rootViewController as? FlutterViewController {
            return flutterVC.binaryMessenger
          }
        }
      }
    }
    if let flutterVC = window?.rootViewController as? FlutterViewController {
      return flutterVC.binaryMessenger
    }
    return nil
  }

  private func serializeUserInfo(_ userInfo: [AnyHashable: Any]) -> [String: Any] {
    var result: [String: Any] = [:]
    for (k, v) in userInfo {
      let key = String(describing: k)
      if let subDict = v as? [AnyHashable: Any] {
        result[key] = serializeUserInfo(subDict)
      } else if let subArr = v as? [Any] {
        result[key] = subArr.map { item -> Any in
          if let itemDict = item as? [AnyHashable: Any] {
            return serializeUserInfo(itemDict)
          }
          return item
        }
      } else {
        result[key] = v
      }
    }
    return result
  }

  // 1. FOREGROUND: Display banner, play sound, update badge when app is open
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge, .list])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  // 2. TAP INTERACTION: Forward notification payload directly to Flutter
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    let stringDict = serializeUserInfo(userInfo)

    if let messenger = getBinaryMessenger() {
      setupTapChannel(messenger: messenger)
    }

    if let channel = tapChannel {
      channel.invokeMethod("onTap", arguments: stringDict)
    } else {
      pendingTapData = stringDict
    }

    completionHandler()
  }
}
