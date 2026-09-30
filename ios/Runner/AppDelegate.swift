import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var visionChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    visionChannel = FlutterMethodChannel(
      name: "easy_vorrat/vision",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    visionChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "recognizeText" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String
      else {
        result(FlutterError(
          code: "invalid_image",
          message: "Kein gültiges Produktfoto.",
          details: nil
        ))
        return
      }

      self?.recognizeText(at: path, result: result)
    }
  }

  private func recognizeText(
    at path: String,
    result: @escaping FlutterResult
  ) {
    let request = VNRecognizeTextRequest { request, error in
      if let error {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "recognition_failed",
            message: error.localizedDescription,
            details: nil
          ))
        }
        return
      }

      let observations = request.results as? [VNRecognizedTextObservation] ?? []
      let text = observations.compactMap {
        $0.topCandidates(1).first?.string
      }.joined(separator: "\n")

      DispatchQueue.main.async {
        result(text)
      }
    }

    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["de-DE", "en-US"]
    request.usesLanguageCorrection = true

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try VNImageRequestHandler(
          url: URL(fileURLWithPath: path),
          options: [:]
        ).perform([request])
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "image_failed",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }
}
