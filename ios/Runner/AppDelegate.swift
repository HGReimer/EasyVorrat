import Flutter
import UIKit
import Vision
import StoreKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var visionChannel: FlutterMethodChannel?
  private var plusChannel: FlutterMethodChannel?
  private var plusUpdatesTask: Task<Void, Never>?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configurePlusChannel(messenger: engineBridge.applicationRegistrar.messenger())

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


  private let plusProductId = "de.easyschmiede.easyvorrat.plus"

  private func configurePlusChannel(messenger: FlutterBinaryMessenger) {
    plusChannel = FlutterMethodChannel(
      name: "easy_vorrat/plus", binaryMessenger: messenger
    )
    plusChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "Plus ist nicht verfügbar.", details: nil))
        return
      }
      guard ["hasPlus", "product", "buy", "restore"].contains(call.method) else {
        result(FlutterMethodNotImplemented)
        return
      }
      Task { @MainActor in
        do {
          switch call.method {
          case "hasPlus":
            result(try await self.verifiedPlusEntitlement())
          case "product":
            let product = try await self.loadPlusProduct()
            result(["id": product.id, "price": product.displayPrice])
          case "buy":
            result(try await self.purchasePlus())
          case "restore":
            try await AppStore.sync()
            result(try await self.verifiedPlusEntitlement())
          default:
            result(FlutterMethodNotImplemented)
          }
        } catch {
          result(FlutterError(code: "plus_failed", message: error.localizedDescription, details: nil))
        }
      }
    }

    plusUpdatesTask?.cancel()
    plusUpdatesTask = Task { @MainActor [weak self] in
      for await outcome in StoreKit.Transaction.updates {
        if Task.isCancelled { return }
        guard let self else { return }
        switch outcome {
        case .verified(let transaction):
          guard transaction.productID == self.plusProductId,
                transaction.productType == .nonConsumable else { continue }
          // Refresh from current entitlements rather than replaying an old purchase.
          do {
            let active = try await self.verifiedPlusEntitlement()
            self.plusChannel?.invokeMethod("entitlementChanged", arguments: active)
            await transaction.finish()
          } catch {
            self.plusChannel?.invokeMethod("verificationError", arguments: nil)
          }
        case .unverified(let transaction, _):
          if transaction.productID == self.plusProductId {
            self.plusChannel?.invokeMethod("verificationError", arguments: nil)
          }
        @unknown default:
          break
        }
      }
    }
  }

  private func plusError(_ message: String) -> NSError {
    NSError(domain: "EasyVorrat.Plus", code: 1,
            userInfo: [NSLocalizedDescriptionKey: message])
  }

  @MainActor
  private func verifiedPlusEntitlement() async throws -> Bool {
    var foundUnverified = false
    for await outcome in StoreKit.Transaction.currentEntitlements {
      switch outcome {
      case .verified(let transaction):
        if transaction.productID == plusProductId,
           transaction.productType == .nonConsumable,
           transaction.revocationDate == nil {
          return true
        }
      case .unverified(let transaction, _):
        if transaction.productID == plusProductId { foundUnverified = true }
      @unknown default:
        break
      }
    }
    if foundUnverified {
      throw plusError("Apple konnte den Plus-Kauf nicht bestätigen.")
    }
    return false
  }

  @MainActor
  private func loadPlusProduct() async throws -> Product {
    let products = try await Product.products(for: [plusProductId])
    guard let product = products.first, product.type == .nonConsumable else {
      throw plusError("Der Plus-Einmalkauf ist gerade nicht verfügbar.")
    }
    return product
  }

  @MainActor
  private func purchasePlus() async throws -> [String: Any] {
    // An existing entitlement must never be purchased a second time.
    if try await verifiedPlusEntitlement() {
      return ["status": "purchased", "isPlus": true]
    }
    let product = try await loadPlusProduct()
    switch try await product.purchase() {
    case .success(let verification):
      guard case .verified(let transaction) = verification,
            transaction.productID == plusProductId,
            transaction.productType == .nonConsumable,
            transaction.revocationDate == nil else {
        throw plusError("Apple konnte den Plus-Kauf nicht bestätigen.")
      }
      // StoreKit durably owns the verified entitlement, including offline access.
      await transaction.finish()
      return ["status": "purchased", "isPlus": true]
    case .pending:
      return ["status": "pending", "isPlus": false]
    case .userCancelled:
      return ["status": "cancelled", "isPlus": false]
    @unknown default:
      throw plusError("Unbekannter Kaufstatus.")
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
