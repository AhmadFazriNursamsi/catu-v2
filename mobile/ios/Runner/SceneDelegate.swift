import Flutter
import UIKit
import UserNotifications

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
       let window = self.window,
       let flutterVC = window.rootViewController as? FlutterViewController {
      appDelegate.setupTapChannel(messenger: flutterVC.binaryMessenger)
    }
  }
}
