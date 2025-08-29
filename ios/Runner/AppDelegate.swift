import UIKit
import Flutter
import UniformTypeIdentifiers

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {

  private var channel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Set up a channel to notify Flutter when TurboScan returns.
    let controller = window?.rootViewController as! FlutterViewController
    channel = FlutterMethodChannel(name: "receipts/pasteboard",
                                   binaryMessenger: controller.binaryMessenger)

    // No calls to ReceiveSharingIntentPlugin here.
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle your custom return URL, e.g. receiptsapp://
  override func application(_ app: UIApplication,
                            open url: URL,
                            options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    // Notify Flutter that we've returned from TurboScan; Flutter can then read UIPasteboard.
    channel?.invokeMethod("didReturnFromTurboScan", arguments: nil)
    return true
  }
}
