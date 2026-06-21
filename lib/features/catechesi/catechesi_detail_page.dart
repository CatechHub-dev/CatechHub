import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../shared/models/attachment_parent_type.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../attachments/widgets/attachments_section.dart';
import '../../shared/models/catechesi_model.dart';

class CatechesiDetailPage extends StatelessWidget {
  final Catechesi catechesi;

  const CatechesiDetailPage({super.key, required this.catechesi});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMMM yyyy', 'it_IT');

    return AppScaffold(
      title: 'Catechesi',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              catechesi.title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF174A7E),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.update_rounded, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Modificata ${formatter.format(catechesi.updatedAt)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (catechesi.description.trim().isNotEmpty) ...[
              _Section(
                icon: Icons.description_rounded,
                color: Colors.blue,
                title: 'Descrizione',
                child: Text(
                  catechesi.description,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (catechesi.tags.isNotEmpty) ...[
              _Section(
                icon: Icons.label_rounded,
                color: Colors.deepPurple,
                title: 'Tag',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: catechesi.tags
                      .map(
                        (t) => Chip(
                          label: Text(t),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: Colors.purple.shade100),
                          backgroundColor: Colors.purple.shade50,
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (catechesi.biblicalReferences.isNotEmpty) ...[
              _Section(
                icon: Icons.menu_book_rounded,
                color: Colors.orange,
                title: 'Riferimenti biblici',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: catechesi.biblicalReferences
                      .map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '• $b',
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (catechesi.websiteReferences.isNotEmpty) ...[
              _Section(
                icon: Icons.link_rounded,
                color: Colors.teal,
                title: 'Riferimenti sitografici',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: catechesi.websiteReferences
                      .map(
                        (w) => InkWell(
                          onTap: () async {
                            final uri = Uri.tryParse(w);
                            if (uri != null) {
                              final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Impossibile aprire: $w')),
                                );
                              }
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(Icons.open_in_new_rounded,
                                    size: 16, color: Colors.teal.shade700),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    w,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.teal.shade700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],
            AttachmentsSection(
              parentId: catechesi.id,
              parentType: AttachmentParentType.catechesi,
              title: 'Foto',
              readOnly: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;

  const _Section({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
