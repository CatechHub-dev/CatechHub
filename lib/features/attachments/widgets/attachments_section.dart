import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../shared/models/attachment_model.dart';
import '../attachment_viewer_page.dart';
import '../attachments_repository.dart';

class AttachmentsSection extends ConsumerWidget {
  const AttachmentsSection({
    super.key,
    required this.parentId,
    required this.parentType,
    this.title = 'Foto e documenti',
  });

  final String parentId;
  final String parentType;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(attachmentsRepositoryProvider);

    return StreamBuilder<List<Attachment>>(
      stream: repo.watchForParent(
        parentId: parentId,
        parentType: parentType,
      ),
      builder: (context, snapshot) {
        final attachments = snapshot.data ?? [];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Color(0xFF174A7E), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF174A7E),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Aggiungi',
                    onPressed: () => _showAddMenu(context, ref),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    color: const Color(0xFF174A7E),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Salvati cifrati e compressi (foto max 1600px, JPEG).',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const Center(child: CircularProgressIndicator())
              else if (attachments.isEmpty)
                Text(
                  'Nessun allegato',
                  style: TextStyle(color: Colors.grey.shade500),
                )
              else
                ...attachments.map(
                  (att) => _AttachmentTile(
                    attachment: att,
                    onOpen: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AttachmentViewerPage(attachment: att),
                        ),
                      );
                    },
                    onDelete: () => _confirmDelete(context, ref, att),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddMenu(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Scatta foto'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Scegli dalla galleria'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('Importa PDF'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !context.mounted) return;

    try {
      switch (choice) {
        case 'camera':
          await _pickImage(context, ref, ImageSource.camera);
          break;
        case 'gallery':
          await _pickImage(context, ref, ImageSource.gallery);
          break;
        case 'pdf':
          await _pickPdf(context, ref);
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  Future<void> _pickImage(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        throw Exception('Permesso fotocamera negato');
      }
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (file == null) return;

    final repo = ref.read(attachmentsRepositoryProvider);
    final saved = await repo.addFromPath(
      parentId: parentId,
      parentType: parentType,
      filePath: file.path,
      name: file.name,
      mimeType: _mimeFromPath(file.path, fallback: 'image/jpeg'),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_savedMessage(saved.size, 'Foto'))),
      );
    }
  }

  Future<void> _pickPdf(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final path = file.path;
    if (path == null) {
      throw Exception('Impossibile leggere il PDF selezionato');
    }

    final repo = ref.read(attachmentsRepositoryProvider);
    final saved = await repo.addFromPath(
      parentId: parentId,
      parentType: parentType,
      filePath: path,
      name: file.name,
      mimeType: 'application/pdf',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_savedMessage(saved.size, 'PDF'))),
      );
    }
  }

  String _savedMessage(int bytes, String type) {
    final kb = (bytes / 1024).ceil();
    if (kb < 1024) {
      return '$type salvato in modo sicuro (~$kb KB)';
    }
    return '$type salvato in modo sicuro (~${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB)';
  }

  String _mimeFromPath(String path, {required String fallback}) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return fallback;
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Attachment att,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina allegato'),
        content: Text('Eliminare "${att.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(attachmentsRepositoryProvider).deleteAttachment(att.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Allegato eliminato')),
      );
    }
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.onOpen,
    required this.onDelete,
  });

  final Attachment attachment;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final icon = attachment.isImage
        ? Icons.image_rounded
        : attachment.isPdf
            ? Icons.picture_as_pdf_rounded
            : Icons.insert_drive_file_rounded;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.grey.shade50,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF174A7E)),
        title: Text(
          attachment.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${attachment.sizeLabel} · ${_formatDate(attachment.createdAt)}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          onPressed: onDelete,
        ),
        onTap: onOpen,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
