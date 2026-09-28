import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late final MobileScannerController _controller;
  bool _handled = false;
  bool _lensConfigured = false;

  @override
  void initState() {
    super.initState();

    _controller = MobileScannerController(
      cameraResolution: const Size(1920, 1080),
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 250,
      facing: CameraFacing.back,
    );

    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (_lensConfigured || !_controller.value.isInitialized) return;

    _lensConfigured = true;
    unawaited(_configureBestLens());
  }

  Future<void> _configureBestLens() async {
    try {
      final bestLens = await _controller.getBestCloseRangeScanningLens(
        facing: CameraFacing.back,
      );
      final supportedLenses = await _controller.getSupportedLenses(
        facing: CameraFacing.back,
      );

      if (bestLens != null && supportedLenses.contains(bestLens)) {
        await _controller.switchCamera(
          SelectCamera(facingDirection: CameraFacing.back, lensType: bestLens),
        );
      }
    } catch (_) {
      // Der Scanner funktioniert weiterhin mit der Standardlinse.
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    String? code;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        code = value;
        break;
      }
    }

    if (code == null) return;

    _handled = true;
    unawaited(_controller.stop());
    Navigator.pop(context, code);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode scannen'),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, child) {
              return IconButton(
                onPressed: state.isInitialized
                    ? () {
                        unawaited(_controller.toggleTorch());
                      }
                    : null,
                icon: Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                ),
                tooltip: 'Licht ein-/ausschalten',
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 300,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.greenAccent, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Text(
              'Barcode vollständig in den grünen Rahmen halten.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                shadows: [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
