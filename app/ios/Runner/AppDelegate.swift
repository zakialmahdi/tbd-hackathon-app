import Flutter
import CoreLocation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.example.app/background_location",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "openAppSettings" {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
          result(false)
          return
        }
        UIApplication.shared.open(settingsURL) { opened in
          result(opened)
        }
        return
      }
      guard call.method == "requestAlwaysLocationAuthorization" else {
        result(FlutterMethodNotImplemented)
        return
      }
      BackgroundLocationAuthorization.shared.requestAlwaysAuthorization(result)
    }
    _ = BackgroundLocationAuthorization.shared
  }
}

private final class BackgroundLocationAuthorization:
  NSObject, CLLocationManagerDelegate {
  static let shared = BackgroundLocationAuthorization()

  private let locationManager = CLLocationManager()
  private var pendingResult: FlutterResult?

  private override init() {
    super.init()
    locationManager.delegate = self
  }

  func requestAlwaysAuthorization(_ result: @escaping FlutterResult) {
    switch currentAuthorizationStatus() {
    case .authorizedAlways:
      result(true)
    case .authorizedWhenInUse, .notDetermined:
      pendingResult = result
      locationManager.requestAlwaysAuthorization()
    case .denied, .restricted:
      result(false)
    @unknown default:
      result(false)
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    completePermissionRequest(for: currentAuthorizationStatus())
  }

  func locationManager(
    _ manager: CLLocationManager,
    didChangeAuthorization status: CLAuthorizationStatus
  ) {
    completePermissionRequest(for: status)
  }

  private func completePermissionRequest(for status: CLAuthorizationStatus) {
    guard let pendingResult else { return }
    switch status {
    case .authorizedAlways:
      self.pendingResult = nil
      pendingResult(true)
    case .authorizedWhenInUse, .denied, .restricted:
      self.pendingResult = nil
      pendingResult(false)
    case .notDetermined:
      break
    @unknown default:
      self.pendingResult = nil
      pendingResult(false)
    }
  }

  private func currentAuthorizationStatus() -> CLAuthorizationStatus {
    if #available(iOS 14.0, *) {
      return locationManager.authorizationStatus
    }
    return CLLocationManager.authorizationStatus()
  }
}
