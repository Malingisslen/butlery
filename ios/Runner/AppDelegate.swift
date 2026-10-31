import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var shareChannel: FlutterMethodChannel?
  /// What the share extension left before the app started, handed to Dart
  /// when it asks. Same contract as MainActivity.kt on Android.
  private var launchShare: ShareInbox.Taken?
  /// A share is pushed to Dart only after Dart has asked for the launch text,
  /// its last ask before it subscribes: before that nothing listens on the
  /// channel, and a pushed share would be taken out of the inbox and lost.
  private var dartIsListening = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "IncomingShare") {
      setUpShareChannel(registrar.messenger())
    }
    NotificationCenter.default.addObserver(
      self, selector: #selector(deliverWaitingShare),
      name: UIApplication.didBecomeActiveNotification, object: nil)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setUpShareChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "se.butlery.app/incoming_share", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      if self.launchShare == nil {
        self.launchShare = self.takeShare() ?? ShareInbox.Taken(text: nil, imagePaths: [])
      }
      switch call.method {
      case "getInitialMedia":
        result(self.launchShare?.imagePaths ?? [])
        self.launchShare?.imagePaths = []
      case "getInitialText":
        result(self.launchShare?.text)
        self.launchShare?.text = nil
        self.dartIsListening = true
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    shareChannel = channel
  }

  @objc private func deliverWaitingShare() {
    guard dartIsListening, let share = takeShare() else { return }
    if !share.imagePaths.isEmpty {
      shareChannel?.invokeMethod("onMedia", arguments: share.imagePaths)
    }
    if let text = share.text {
      shareChannel?.invokeMethod("onText", arguments: text)
    }
  }

  private func takeShare() -> ShareInbox.Taken? {
    ShareInbox.take(movingImagesTo: FileManager.default.temporaryDirectory)
  }
}
