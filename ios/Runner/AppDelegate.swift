import Flutter
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
    registerDeviceChannel(with: engineBridge.pluginRegistry)
  }

  /// The device part of the app's User-Agent (lib/core/network/user_agent.dart),
  /// so Signed-in Devices can tell one phone from another.
  private func registerDeviceChannel(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "MedibookDevice") else { return }
    let channel = FlutterMethodChannel(
      name: "medibook/device",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "describe" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let device = UIDevice.current
      result([
        "manufacturer": "Apple",
        "model": AppDelegate.modelIdentifier() ?? device.model,
        "os": device.systemName,
        "osVersion": device.systemVersion,
      ])
    }
  }

  /// "iPhone15,2" — the hardware model, which says which iPhone this is
  /// ("iPhone" alone does not). On the simulator, the simulated model.
  private static func modelIdentifier() -> String? {
    var info = utsname()
    uname(&info)
    let machine = Mirror(reflecting: info.machine).children.reduce(into: "") { name, element in
      guard let byte = element.value as? Int8, byte != 0 else { return }
      name.append(Character(UnicodeScalar(UInt8(byte))))
    }
    if machine == "x86_64" || machine == "arm64" {
      return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
    }
    return machine.isEmpty ? nil : machine
  }
}
