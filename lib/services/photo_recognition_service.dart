import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PhotoRecognitionResult {
  final String suggestedName;
  final String packageQuantity;
  final String recognizedText;

  const PhotoRecognitionResult({
    required this.suggestedName,
    required this.packageQuantity,
    required this.recognizedText,
  });
}

class PhotoRecognitionService {
  PhotoRecognitionService._();

  static const _channel = MethodChannel('easy_vorrat/vision');

  static bool get isSupported {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  }

  static Future<PhotoRecognitionResult> recognize(String imagePath) async {
    if (!isSupported) {
      throw UnsupportedError(
        'Die Fotoerkennung ist derzeit nur auf dem iPhone verfügbar.',
      );
    }

    final recognizedText =
        await _channel.invokeMethod<String>('recognizeText', {
          'path': imagePath,
        }) ??
        '';

    final lines = recognizedText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.length >= 2 && line.length <= 70)
        .toList();

    final quantityMatch = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(ml|cl|dl|l|g|kg|stück|stk\.?)\b',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(recognizedText);

    final packageQuantity = quantityMatch == null
        ? ''
        : '${quantityMatch.group(1)} ${quantityMatch.group(2)}';

    final ignored = RegExp(
      r'^(zutaten|nährwerte?|mindestens haltbar|mhd|'
      r'energie|fett|eiweiß|kohlenhydrate|salz|'
      r'www\.|[\d\s.,%]+)',
      caseSensitive: false,
      unicode: true,
    );

    final nameLines = lines
        .where((line) {
          return RegExp(r'[A-Za-zÄÖÜäöüß]').hasMatch(line) &&
              !ignored.hasMatch(line) &&
              !RegExp(
                r'\d+(?:[.,]\d+)?\s*(ml|cl|dl|l|g|kg)\b',
                caseSensitive: false,
              ).hasMatch(line);
        })
        .take(2)
        .toList();

    return PhotoRecognitionResult(
      suggestedName: nameLines.join(' '),
      packageQuantity: packageQuantity,
      recognizedText: recognizedText,
    );
  }
}
