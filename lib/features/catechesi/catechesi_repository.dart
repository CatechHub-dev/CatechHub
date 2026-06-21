import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_database.dart';
import '../../shared/models/attachment_parent_type.dart';
import '../../shared/models/catechesi_model.dart';
import '../attachments/attachments_repository.dart';

final catechesiRepositoryProvider = Provider<CatechesiRepository>((ref) {
  return CatechesiRepository();
});

class CatechesiRepository {
  final _box = LocalDatabase.catechesi();

  Stream<List<Catechesi>> watchCatechesi() {
    return LocalDatabase.watchList(
      _box,
      (id, data) => Catechesi.fromMap(id, data),
    );
  }

  List<Catechesi> getCatechesiSync() {
    return LocalDatabase.values(
      _box,
      (id, data) => Catechesi.fromMap(id, data),
    );
  }

  Future<void> addCatechesi(Catechesi c) async {
    final id = c.id.isEmpty ? LocalDatabase.newId('catechesi') : c.id;
    await _box.put(id, c.toMap());
  }

  Future<void> updateCatechesi(String id, Catechesi c) async {
    await _box.put(id, c.toMap());
  }

  Future<void> deleteCatechesi(String id) async {
    await AttachmentsRepository().deleteAllForParent(
      parentId: id,
      parentType: AttachmentParentType.catechesi,
    );
    await _box.delete(id);
  }

  List<Catechesi> search(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return getCatechesiSync();

    return getCatechesiSync().where((c) {
      final matchesTitle = c.title.toLowerCase().contains(q);
      final matchesTag = c.tags.any((t) => t.toLowerCase().contains(q));
      final matchesBiblical = c.biblicalReferences.any((b) => b.toLowerCase().contains(q));
      final matchesWebsite = c.websiteReferences.any((w) => w.toLowerCase().contains(q));
      return matchesTitle || matchesTag || matchesBiblical || matchesWebsite;
    }).toList();
  }
}
