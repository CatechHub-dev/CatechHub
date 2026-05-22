import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/student_model.dart';
import '../../shared/widgets/app_scaffold.dart';
import 'documents_provider.dart';
import 'documents_repository.dart';

class DocumentDetailPage extends ConsumerWidget {
  final Map<String, dynamic> document;
  final List<Student> students;

  const DocumentDetailPage({
    super.key,
    required this.document,
    required this.students,
  });

  String _formatTimestamp(dynamic timestamp) {
    final DateTime? date = DateTime.tryParse(timestamp?.toString() ?? '');
    if (date == null) return '';
    
    final List<String> mesi = [
      'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 
      'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
    ];
    
    return '${date.day} ${mesi[date.month - 1]}';
  }

  /// Gestisce l'aggiornamento della data di Consegna (Modulo dato al ragazzo)
  Future<void> _toggleGivenOut({
    required String docId,
    required String studentId,
    required bool isCurrentlyGiven,
  }) async {
    await DocumentsRepository().setGivenOut(
      docId: docId,
      studentId: studentId,
      isCurrentlyGiven: isCurrentlyGiven,
    );
  }

  /// Gestisce l'aggiornamento della data di Ritiro (Modulo firmato e restituito)
  Future<void> _toggleReceived({
    required String docId,
    required String studentId,
    required bool isCurrentlyReceived,
  }) async {
    await DocumentsRepository().setReceived(
      docId: docId,
      studentId: studentId,
      isCurrentlyReceived: isCurrentlyReceived,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docId = document['id']?.toString() ?? '';
    final deliveriesAsync = ref.watch(documentDeliveriesProvider(docId));

    return AppScaffold(
      title: document['title']?.toString() ?? 'Dettaglio Documento',
      child: deliveriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore nel caricamento: $e')),
        data: (deliveries) {
          if (students.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Nessun ragazzo presente in questo gruppo.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              final studentId = student.id;

              final deliveryData = deliveries[studentId];
              
              // Leggiamo i dati effettivi registrati
              final dynamic givenOutTimestamp = deliveryData?['givenOutAt'];
              final dynamic receivedTimestamp = deliveryData?['receivedAt'];

              final bool isGivenOut = givenOutTimestamp != null;
              final bool isReceived = receivedTimestamp != null;

              // Generiamo le stringhe delle date (es. "14 Mag" o stringa vuota "")
              final String dateGivenStr = _formatTimestamp(givenOutTimestamp);
              final String dateReceivedStr = _formatTimestamp(receivedTimestamp);

              // Determina lo stato riassuntivo in alto
              String statusText = 'Da consegnare';
              Color statusColor = Colors.grey.shade600;
              if (isGivenOut && !isReceived) {
                statusText = 'Consegnato (In attesa di riconsegna)';
                statusColor = Colors.orange.shade800;
              } else if (isReceived) {
                statusText = 'Ritirato e Completato';
                statusColor = Colors.green;
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF174A7E).withOpacity(0.1),
                              child: Text(
                                student.name.isNotEmpty ? student.name[0].toUpperCase() : 'R',
                                style: const TextStyle(
                                  color: Color(0xFF174A7E),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${student.name} ${student.surname}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF174A7E),
                                    ),
                                  ),
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20, thickness: 0.5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Sezione Consegna: Pulsante + Data sotto
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _ActionButton(
                                  label: 'Consegnato',
                                  icon: Icons.outbox,
                                  isActive: isGivenOut,
                                  activeColor: Colors.orange.shade700,
                                  onTap: () => _toggleGivenOut(
                                    docId: docId,
                                    studentId: studentId,
                                    isCurrentlyGiven: isGivenOut,
                                  ),
                                ),
                                if (isGivenOut && dateGivenStr.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    dateGivenStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ]
                              ],
                            ),
                            const SizedBox(width: 12),
                            // Sezione Ritiro: Pulsante + Data sotto
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _ActionButton(
                                  label: 'Ritirato',
                                  icon: Icons.assignment_turned_in,
                                  isActive: isReceived,
                                  activeColor: Colors.green,
                                  onTap: !isGivenOut 
                                      ? null 
                                      : () => _toggleReceived(
                                          docId: docId,
                                          studentId: studentId,
                                          isCurrentlyReceived: isReceived,
                                        ),
                                ),
                                if (isReceived && dateReceivedStr.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    dateReceivedStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Pulsante di azione interno invariato, mantiene lo stile pulito dell'app
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isButtonDisabled = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isButtonDisabled
              ? Colors.grey.shade100
              : isActive
                  ? activeColor.withOpacity(0.12)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isButtonDisabled
                ? Colors.grey.shade300
                : isActive
                    ? activeColor
                    : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isButtonDisabled
                  ? Colors.grey.shade400
                  : isActive
                      ? activeColor
                      : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isButtonDisabled
                    ? Colors.grey.shade400
                    : isActive
                        ? activeColor
                        : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
