import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Riduce dimensioni e peso degli allegati prima della cifratura su disco.
class AttachmentOptimizer {
  /// Lato lungo massimo in pixel (sufficiente per lettura su schermo).
  static const maxImageLongEdge = 1600;

  /// Qualità JPEG (bilanciata tra nitidezza e spazio).
  static const jpegQuality = 75;

  /// PDF oltre questa soglia vanno compressi esternamente dall'utente.
  static const maxPdfBytes = 4 * 1024 * 1024;

  /// GIF animate: solo limite dimensione, senza ricodifica.
  static const maxGifBytes = 2 * 1024 * 1024;

  static Future<OptimizedAttachment> optimize({
    required Uint8List bytes,
    required String mimeType,
    required String originalName,
  }) async {
    final normalizedMime = mimeType.toLowerCase();

    if (normalizedMime.startsWith('image/')) {
      return _optimizeImage(bytes, originalName, normalizedMime);
    }
    if (normalizedMime == 'application/pdf') {
      return _optimizePdf(bytes, originalName);
    }

    return OptimizedAttachment(
      bytes: bytes,
      mimeType: mimeType,
      name: originalName,
      originalBytes: bytes.length,
    );
  }

  static Future<OptimizedAttachment> _optimizeImage(
    Uint8List bytes,
    String originalName,
    String mimeType,
  ) async {
    if (mimeType == 'image/gif') {
      if (bytes.length > maxGifBytes) {
        throw Exception(
          'GIF troppo grande (max ${maxGifBytes ~/ (1024 * 1024)} MB)',
        );
      }
      return OptimizedAttachment(
        bytes: bytes,
        mimeType: mimeType,
        name: originalName,
        originalBytes: bytes.length,
      );
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Impossibile elaborare l\'immagine');
    }

    var image = decoded;
    if (image.width > maxImageLongEdge || image.height > maxImageLongEdge) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxImageLongEdge)
          : img.copyResize(image, height: maxImageLongEdge);
    }

    // JPEG: molto più leggero di PNG/HEIC per foto di registro.
    final optimizedBytes = Uint8List.fromList(
      img.encodeJpg(image, quality: jpegQuality),
    );

    return OptimizedAttachment(
      bytes: optimizedBytes,
      mimeType: 'image/jpeg',
      name: _withExtension(originalName, '.jpg'),
      originalBytes: bytes.length,
    );
  }

  static OptimizedAttachment _optimizePdf(Uint8List bytes, String originalName) {
    if (bytes.length > maxPdfBytes) {
      throw Exception(
        'PDF troppo grande (max ${maxPdfBytes ~/ (1024 * 1024)} MB). '
        'Comprimilo con un\'app esterna prima di importarlo.',
      );
    }

    return OptimizedAttachment(
      bytes: bytes,
      mimeType: 'application/pdf',
      name: originalName,
      originalBytes: bytes.length,
    );
  }

  static String _withExtension(String name, String ext) {
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    return '$base$ext';
  }
}

class OptimizedAttachment {
  const OptimizedAttachment({
    required this.bytes,
    required this.mimeType,
    required this.name,
    required this.originalBytes,
  });

  final Uint8List bytes;
  final String mimeType;
  final String name;
  final int originalBytes;

  int get savedBytes => bytes.length;

  /// Percentuale di spazio risparmiato (0 se aumentato).
  int? get savingsPercent {
    if (originalBytes <= 0 || savedBytes >= originalBytes) return null;
    return ((1 - savedBytes / originalBytes) * 100).round();
  }
}
