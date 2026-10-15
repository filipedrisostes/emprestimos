import Flutter
import UIKit
import UserNotifications
import GoogleSignIn

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let configuration = FlutterMethodChannel(
      name: "emprestimos/ios_configuration",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    configuration.setMethodCallHandler { call, result in
      guard call.method == "googleSignInConfiguration" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ?? ""
      let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
      let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
      result(["clientId": clientID, "schemes": schemes])
    }
  }
}

// The installed Google plugin still uses AppDelegate URL callbacks. Forward
// its OAuth callback explicitly when using the UIScene lifecycle.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let unhandled = URLContexts.filter { !GIDSignIn.sharedInstance.handle($0.url) }
    if !unhandled.isEmpty {
      super.scene(scene, openURLContexts: Set(unhandled))
    }
  }
}
