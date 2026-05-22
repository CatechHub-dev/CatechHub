import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/app_scaffold.dart';
import '../../shared/models/student_model.dart';
import 'students_repository.dart';
import 'students_add_page.dart';
import 'edit_student_page.dart';

final studentsRepoProvider = Provider((ref) => StudentsRepository());

class StudentsPage extends ConsumerWidget {
  const StudentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(studentsRepoProvider);

    return AppScaffold(
      title: 'Ragazzi',

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF174A7E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuovo ragazzo'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddStudentPage(),
            ),
          );
        },
      ),

      child: StreamBuilder<List<Student>>(
        stream: repo.getAllStudents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _EmptyState();
          }

          final students = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final s = students[index];

              return _StudentCard(
                student: s,
                onEdit: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EditStudentPage(student: s),
                    ),
                  );
                },
                onDelete: () {
                  repo.deleteStudent(s.id);
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// =========================
/// STUDENT CARD
/// =========================
class _StudentCard extends StatelessWidget {
  final Student student;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StudentCard({
    required this.student,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        '${student.name} ${student.surname}';

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Colors.blue.shade50.withOpacity(0.35),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.blue.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            /// AVATAR
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF174A7E),
              child: Text(
                student.name.isNotEmpty
                    ? student.name[0]
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 14),

            /// TEXT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF174A7E),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Madre: ${student.motherName} ${student.motherSurname}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),

                  Text(
                    'Padre: ${student.fatherName} ${student.fatherSurname}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            /// MENU
            PopupMenuButton<String>(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 10),
                      Text('Modifica'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete),
                      SizedBox(width: 10),
                      Text('Elimina'),
                    ],
                  ),
                ),
              ],
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
      ),
    );
  }
}

/// =========================
/// EMPTY STATE
/// =========================
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline,
            size: 70,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'Nessun ragazzo presente',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}