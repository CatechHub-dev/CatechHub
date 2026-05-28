import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:math';

class DataShareOptions {
  final bool includeAnagrafica;
  final bool includeAgenda;
  final bool includeProgrammazione;
  final bool includeDocumenti;
  final bool includeAllegati;

  const DataShareOptions({
    this.includeAnagrafica = true,
    this.includeAgenda = true,
    this.includeProgrammazione = true,
    this.includeDocumenti = true,
    this.includeAllegati = false,
  });
}

class DataPackage {
  final String pin;
  final Map<String, dynamic> data;
  final int totalChunks;
  final String checksum;

  DataPackage({
    required this.pin,
    required this.data,
    required this.totalChunks,
    required this.checksum,
  });

  Map<String, dynamic> toMap() {
    return {
      'pin': pin,
      'data': data,
      'totalChunks': totalChunks,
      'checksum': checksum,
    };
  }

  factory DataPackage.fromMap(Map<String, dynamic> map) {
    return DataPackage(
      pin: map['pin'] ?? '',
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      totalChunks: map['totalChunks'] ?? 1,
      checksum: map['checksum'] ?? '',
    );
  }
}

class QRChunk {
  final int chunkIndex;
  final int totalChunks;
  final String data;
  final String checksum;

  QRChunk({
    required this.chunkIndex,
    required this.totalChunks,
    required this.data,
    required this.checksum,
  });

  Map<String, dynamic> toMap() {
    return {
      'i': chunkIndex,
      't': totalChunks,
      'd': data,
      'c': checksum,
    };
  }

  factory QRChunk.fromMap(Map<String, dynamic> map) {
    return QRChunk(
      chunkIndex: map['i'] ?? 0,
      totalChunks: map['t'] ?? 1,
      data: map['d'] ?? '',
      checksum: map['c'] ?? '',
    );
  }

  String toJson() {
    return jsonEncode(toMap());
  }

  factory QRChunk.fromJson(String jsonStr) {
    return QRChunk.fromMap(jsonDecode(jsonStr));
  }
}

class QRDataService {
  static const int maxQRSize = 1200; // Massimi caratteri per QR code (ridotto per migliore leggibilità)
  static const int pinLength = 8;

  // Genera PIN di 8 cifre
  static String generatePin() {
    final random = Random.secure();
    return List.generate(pinLength, (_) => random.nextInt(10)).join();
  }

  // Verifica PIN
  static bool verifyPin(String inputPin, String expectedPin) {
    return inputPin == expectedPin;
  }

  // Calcola checksum dei dati
  static String calculateChecksum(Map<String, dynamic> data) {
    final jsonString = jsonEncode(data);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8); // Prime 8 caratteri
  }

  // Comprime dati JSON usando base64 semplice
  static String compressData(Map<String, dynamic> data) {
    final jsonString = jsonEncode(data);
    final encoded = base64Encode(utf8.encode(jsonString));
    return encoded;
  }

  // Decomprime dati
  static Map<String, dynamic> decompressData(String compressed) {
    try {
      final decoded = utf8.decode(base64Decode(compressed));
      return Map<String, dynamic>.from(jsonDecode(decoded));
    } catch (e) {
      throw Exception('Errore nella decompressione dei dati: $e');
    }
  }

  // Segmenta dati in chunk per QR code
  static List<String> segmentData(String data) {
    final List<String> chunks = [];
    for (int i = 0; i < data.length; i += maxQRSize) {
      final end = (i + maxQRSize < data.length) ? i + maxQRSize : data.length;
      chunks.add(data.substring(i, end));
    }
    return chunks;
  }

  // Crea pacchetto dati completo
  static DataPackage createPackage(
    Map<String, dynamic> data,
    String pin,
  ) {
    final checksum = calculateChecksum(data);

    return DataPackage(
      pin: pin,
      data: data,
      totalChunks: 0, // Verrà calcolato dopo la segmentazione
      checksum: checksum,
    );
  }

  // Genera QR chunk da inviare
  static QRChunk createQRChunk(String data, int index, int total) {
    final chunkChecksum = _calculateChunkChecksum(data);
    return QRChunk(
      chunkIndex: index,
      totalChunks: total,
      data: data,
      checksum: chunkChecksum,
    );
  }

  // Calcola checksum per singolo chunk
  static String _calculateChunkChecksum(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 4);
  }

  // Verifica integrità chunk
  static bool verifyChunkChecksum(QRChunk chunk) {
    final expectedChecksum = _calculateChunkChecksum(chunk.data);
    return chunk.checksum == expectedChecksum;
  }

  // Verifica checksum del pacchetto completo
  static bool verifyPackageChecksum(DataPackage package) {
    final expectedChecksum = calculateChecksum(package.data);
    return package.checksum == expectedChecksum;
  }

  // Assembla chunk ricevuti
  static String assembleChunks(List<QRChunk> chunks) {
    // Ordina chunk per indice
    chunks.sort((a, b) => a.chunkIndex.compareTo(b.chunkIndex));
    
    // Verifica che tutti i chunk siano presenti
    if (chunks.isEmpty) return '';
    
    final total = chunks.first.totalChunks;
    if (chunks.length != total) {
      throw Exception('Mancano ${total - chunks.length} chunk');
    }

    // Verifica checksum di ogni chunk
    for (final chunk in chunks) {
      if (!verifyChunkChecksum(chunk)) {
        throw Exception('Checksum non valido per chunk ${chunk.chunkIndex}');
      }
    }

    // Assembla dati
    return chunks.map((chunk) => chunk.data).join();
  }

  // Estrae dati dal pacchetto ricevuto
  static Map<String, dynamic> extractPackageData(String assembledData) {
    try {
      final packageMap = jsonDecode(assembledData) as Map<String, dynamic>;
      final package = DataPackage.fromMap(packageMap);
      
      // I dati non sono più compressi internamente
      return Map<String, dynamic>.from(package.data);
    } catch (e) {
      throw Exception('Errore nell\'estrazione dei dati: $e');
    }
  }

  // Prepara dati per condivisione basato su opzioni
  static Map<String, dynamic> prepareDataForShare(
    DataShareOptions options,
    Map<String, dynamic> allData,
  ) {
    final Map<String, dynamic> shareData = {};

    if (options.includeAnagrafica) {
      shareData['anagrafica'] = allData['anagrafica'] ?? {};
      // Includi automaticamente allegati dei ragazzi
      shareData['allegati_studenti'] = allData['allegati_studenti'] ?? {};
    }

    if (options.includeAgenda) {
      shareData['agenda'] = allData['agenda'] ?? {};
    }

    if (options.includeProgrammazione) {
      shareData['programmazione'] = allData['programmazione'] ?? {};
      // Includi automaticamente allegati delle giornate
      shareData['allegati_giornate'] = allData['allegati_giornate'] ?? {};
    }

    if (options.includeDocumenti) {
      shareData['documenti'] = allData['documenti'] ?? {};
    }

    return shareData;
  }
}
