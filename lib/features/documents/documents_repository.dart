import '../../core/storage/local_database.dart';

class DocumentsRepository {
  final _documentsBox = LocalDatabase.documents();
  final _deliveriesBox = LocalDatabase.documentDeliveries();

  Stream<List<Map<String, dynamic>>> getDocuments() {
    return LocalDatabase.watchList(
      _documentsBox,
      (id, data) => {'id': id, ...data},
    ).map((documents) {
      documents.sort((a, b) {
        final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return documents;
    });
  }

  List<Map<String, dynamic>> getDocumentsSync() {
    final documents = LocalDatabase.values(
      _documentsBox,
      (id, data) => {'id': id, ...data},
    );
    documents.sort((a, b) {
      final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return documents;
  }

  Future<void> addDocument(String title) async {
    final id = LocalDatabase.newId('document');
    await _documentsBox.put(id, {
      'title': title,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteDocument(String id) async {
    await _documentsBox.delete(id);
    await _deliveriesBox.delete(id);
  }

  Stream<Map<String, dynamic>> getDeliveries(String docId) async* {
    yield getDeliveriesSync(docId);
    yield* _deliveriesBox.watch(key: docId).map((_) => getDeliveriesSync(docId));
  }

  Map<String, dynamic> getDeliveriesSync(String docId) {
    return LocalDatabase.toStringDynamicMap(_deliveriesBox.get(docId));
  }

  Future<void> setGivenOut({
    required String docId,
    required String studentId,
    required bool isCurrentlyGiven,
  }) async {
    final deliveries = getDeliveriesSync(docId);
    final current = Map<String, dynamic>.from(deliveries[studentId] as Map? ?? {});

    if (isCurrentlyGiven) {
      current['givenOutAt'] = null;
      current['receivedAt'] = null;
    } else {
      current['givenOutAt'] = DateTime.now().toIso8601String();
    }

    deliveries[studentId] = current;
    await _deliveriesBox.put(docId, deliveries);
  }

  Future<void> setReceived({
    required String docId,
    required String studentId,
    required bool isCurrentlyReceived,
  }) async {
    final deliveries = getDeliveriesSync(docId);
    final current = Map<String, dynamic>.from(deliveries[studentId] as Map? ?? {});

    if (isCurrentlyReceived) {
      current['receivedAt'] = null;
    } else {
      current['receivedAt'] = DateTime.now().toIso8601String();
    }

    deliveries[studentId] = current;
    await _deliveriesBox.put(docId, deliveries);
  }
}
