import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/models/attachment_parent_type.dart';
import '../../shared/models/student_model.dart';
import '../attachments/widgets/attachments_section.dart';
import '../documents/documents_provider.dart';
import '../meetings/attendance_repository.dart';
import '../planning/planning_repository.dart';
import 'students_repository.dart';

final studentsRepoProvider = Provider((ref) => StudentsRepository());

final _studentAbsencesProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, studentId) {
  final attendanceRepo = AttendanceRepository();
  final planningRepo = PlanningRepository();

  return attendanceRepo.getAttendance().map((attendanceRecords) {
    final meetings = planningRepo.getMeetingsSync();
    final meetingMap = {for (var m in meetings) m.id: m};

    final absences = <Map<String, dynamic>>[];

    for (final record in attendanceRecords) {
      final presenceMap = Map<String, dynamic>.from(record['presence'] as Map? ?? {});
      final studentStatus = presenceMap[studentId]?.toString();

      if (studentStatus == 'Assente') {
        final meeting = meetingMap[record['id']];
        final date = DateTime.tryParse(record['date']?.toString() ?? '') ?? DateTime.now();

        absences.add({
          'date': date,
          'meetingTitle': meeting?.title ?? 'Riunione sconosciuta',
          'meetingActivity': meeting?.activity ?? '',
          'isReunion': meeting?.isReunion ?? false,
        });
      }
    }

    absences.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return absences;
  });
});

class StudentQuickViewPage extends ConsumerWidget {
  final Student student;

  const StudentQuickViewPage({
    super.key,
    required this.student,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: const Color(0xFF174A7E),
        foregroundColor: Colors.white,
        title: const Text('Scheda Ragazzo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderCard(student: student),
            const SizedBox(height: 16),
            _PersonalInfoCard(student: student),
            const SizedBox(height: 16),
            _ParentsCard(student: student),
            const SizedBox(height: 16),
            _AllergiesCard(student: student),
            const SizedBox(height: 16),
            _DocumentsCard(studentId: student.id),
            const SizedBox(height: 16),
            AttachmentsSection(
              parentId: student.id,
              parentType: AttachmentParentType.student,
            ),
            const SizedBox(height: 16),
            _NotesCard(student: student),
            const SizedBox(height: 16),
            _AbsencesCard(studentId: student.id),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final Student student;

  const _HeaderCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF174A7E), Color(0xFF2E5A8F)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white,
            child: Text(
              student.name.isNotEmpty ? student.name[0] : '?',
              style: const TextStyle(
                color: Color(0xFF174A7E),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${student.surname} ${student.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd/MM/yyyy').format(student.birthDate),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalInfoCard extends StatelessWidget {
  final Student student;

  const _PersonalInfoCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Dati Personali',
      icon: Icons.person_rounded,
      color: const Color(0xFF174A7E),
      children: [
        _InfoRow('Nome', student.name),
        _InfoRow('Cognome', student.surname),
        _InfoRow(
          'Data di nascita',
          DateFormat('dd/MM/yyyy').format(student.birthDate),
        ),
        if (student.studentPhone.isNotEmpty)
          _InfoRow('Cellulare', student.studentPhone, isPhone: true),
      ],
    );
  }
}

class _ParentsCard extends StatelessWidget {
  final Student student;

  const _ParentsCard({required this.student});

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _whatsapp(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$normalized');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Genitori',
      icon: Icons.family_restroom_rounded,
      color: Colors.green,
      children: [
        if (student.motherName.isNotEmpty || student.motherSurname.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Madre',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                  fontSize: 14,
                ),
              ),
              _InfoRow('Nome', '${student.motherName} ${student.motherSurname}'),
              if (student.motherPhone.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: _InfoRow('Telefono', student.motherPhone),
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone, color: Colors.green),
                      onPressed: () => _call(student.motherPhone),
                    ),
                    IconButton(
                      icon: const Icon(Icons.message, color: Colors.green),
                      onPressed: () => _whatsapp(student.motherPhone),
                    ),
                  ],
                ),
            ],
          ),
        if (student.fatherName.isNotEmpty || student.fatherSurname.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'Padre',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                  fontSize: 14,
                ),
              ),
              _InfoRow('Nome', '${student.fatherName} ${student.fatherSurname}'),
              if (student.fatherPhone.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: _InfoRow('Telefono', student.fatherPhone),
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone, color: Colors.green),
                      onPressed: () => _call(student.fatherPhone),
                    ),
                    IconButton(
                      icon: const Icon(Icons.message, color: Colors.green),
                      onPressed: () => _whatsapp(student.fatherPhone),
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}

class _AllergiesCard extends StatelessWidget {
  final Student student;

  const _AllergiesCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Allergie e Autorizzazioni',
      icon: Icons.medical_information_rounded,
      color: Colors.orange,
      children: [
        if (student.allergies != null && student.allergies!.isNotEmpty)
          _InfoRow('Allergie', student.allergies!)
        else
          Text(
            'Nessuna allergia registrata',
            style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
        const SizedBox(height: 8),
        if (student.autonomousExits != null && student.autonomousExits!.isNotEmpty)
          _InfoRow('Uscite autonome', _formatExits(student.autonomousExits!))
        else
          Text(
            'Nessuna uscita autonome autorizzata',
            style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
      ],
    );
  }

  String _formatExits(String exits) {
    if (exits.startsWith('altro:')) {
      return exits.replaceFirst('altro:', 'Altro: ');
    }
    return exits;
  }
}

class _DocumentsCard extends ConsumerWidget {
  final String studentId;

  const _DocumentsCard({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsStreamProvider);

    return _InfoCard(
      title: 'Documenti da consegnare',
      icon: Icons.description_rounded,
      color: Colors.purple,
      children: [
        docsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('Errore caricamento documenti'),
          data: (documents) {
            if (documents.isEmpty) {
              return Text(
                'Nessun documento richiesto',
                style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: documents.map((doc) {
                final docId = doc['id'].toString();
                final deliveriesAsync = ref.watch(documentDeliveriesProvider(docId));

                return deliveriesAsync.when(
                  loading: () => const SizedBox(height: 30),
                  error: (_, __) => const SizedBox(height: 30),
                  data: (deliveries) {
                    final delivery = deliveries[studentId];
                    final isReceived = delivery != null && delivery['receivedAt'] != null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            isReceived ? Icons.check_circle_rounded : Icons.pending_rounded,
                            color: isReceived ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              doc['title']?.toString() ?? 'Documento',
                              style: TextStyle(
                                color: isReceived ? Colors.grey.shade700 : Colors.orange.shade800,
                                decoration: isReceived ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          if (!isReceived)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Da consegnare',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _NotesCard extends StatelessWidget {
  final Student student;

  const _NotesCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Note',
      icon: Icons.note_rounded,
      color: Colors.blue,
      children: [
        if (student.notes != null && student.notes!.isNotEmpty)
          Text(
            student.notes!,
            style: const TextStyle(fontSize: 14),
          )
        else
          Text(
            'Nessuna nota registrata',
            style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
      ],
    );
  }
}

class _AbsencesCard extends ConsumerWidget {
  final String studentId;

  const _AbsencesCard({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final absencesAsync = ref.watch(_studentAbsencesProvider(studentId));

    return _InfoCard(
      title: 'Assenze',
      icon: Icons.event_busy_rounded,
      color: Colors.red,
      children: [
        absencesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (e, _) => Text(
            'Errore nel caricamento assenze: $e',
            style: TextStyle(color: Colors.red.shade700),
          ),
          data: (absences) {
            if (absences.isEmpty) {
              return Text(
                'Nessuna assenza registrata',
                style: TextStyle(color: Colors.grey.shade600),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: absences.map((absence) {
                final date = absence['date'] as DateTime;
                final title = absence['meetingTitle'] as String;
                final activity = absence['meetingActivity'] as String;
                final isReunion = absence['isReunion'] as bool;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd/MM/yyyy').format(date),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (activity.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          activity,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (isReunion) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Riunione catechisti',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isPhone;

  const _InfoRow(this.label, this.value, {this.isPhone = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 14,
                fontWeight: isPhone ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}