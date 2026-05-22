import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/app_scaffold.dart';
import 'package:go_router/go_router.dart';
import 'documents_provider.dart';

class DocumentsPage extends ConsumerWidget {
  const DocumentsPage({super.key});

  void _showCreateDocumentDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Nuovo Documento',
          style: TextStyle(color: Color(0xFF174A7E), fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Titolo del documento',
            hintText: 'es. Autorizzazione Campi Estivi',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF174A7E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final text = titleController.text.trim();
              if (text.isNotEmpty) {
                // Catturiamo il Navigator prima del blocco asincrono per evitare GoRouterState Error
                final navigator = Navigator.of(dialogContext);

                await ref.read(documentsRepoProvider).addDocument(text);
                
                navigator.pop();
              }
            },
            child: const Text('Crea'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsStreamProvider);
    final studentsAsync = ref.watch(myGroupStudentsProvider);

    return AppScaffold(
      title: 'Documenti',
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF174A7E),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _showCreateDocumentDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      child: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (documents) {
          if (documents.isEmpty) {
            return const Center(
              child: Text('Nessun documento. Premi + per aggiungerne uno.'),
            );
          }

          return studentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Errore ragazzi: $e')),
            data: (myStudents) {
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final doc = documents[index];
                  final docId = doc['id'].toString();
                  final deliveriesAsync = ref.watch(documentDeliveriesProvider(docId));

                  return deliveriesAsync.when(
                    loading: () => const SizedBox(height: 70),
                    error: (_, __) => const Text('Errore dati'),
                    data: (deliveries) {
                      // Calcolo dei mancanti focalizzato unicamente sulla classe del catechista
                      int mancanti = 0;
                      for (final student in myStudents) {
                        final d = deliveries[student.id];
                        if (d == null || d['receivedAt'] == null) {
                          mancanti++;
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF174A7E).withOpacity(0.1),
                              child: const Icon(Icons.description, color: Color(0xFF174A7E)),
                            ),
                            title: Text(
                              doc['title']?.toString() ?? 'Documento',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              mancanti == 0 ? 'Completato' : '$mancanti mancanti',
                              style: TextStyle(
                                color: mancanti == 0 ? Colors.green : Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (value) async {
                                if (value == 'delete') {
                                  await ref
                                      .read(documentsRepoProvider)
                                      .deleteDocument(docId);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_rounded),
                                      SizedBox(width: 10),
                                      Text('Elimina'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              context.push(
                                '/document-detail',
                                extra: {
                                  'document': doc,
                                  'students': myStudents,
                                },
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
