import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_service.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../classes/classes_provider.dart';
import '../planning/planning_provider.dart';
import 'attendance_repository.dart';

class AttendanceMeetingsPage extends ConsumerWidget {
  const AttendanceMeetingsPage({super.key});

  Stream<Map<String, bool>> _getAttendanceStatus() {
    return AttendanceRepository().getAttendance().map((records) {
      return {for (final record in records) record['id'].toString(): true};
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final classesAsync = ref.watch(classesStreamProvider);
    final planningRepo = ref.watch(planningRepoProvider);

    return AppScaffold(
      title: 'Seleziona incontro',
      child: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _EmptyState(
          icon: Icons.gpp_bad_rounded,
          title: 'Errore',
          subtitle: e.toString(),
        ),
        data: (classes) {
          final myClass = classes.where(
            (c) => c.catechistIds.contains(AuthService.localUserId),
          );

          if (myClass.isEmpty) {
            return const _EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Attenzione',
              subtitle: 'Non sei associato a nessuna classe come catechista',
            );
          }

          final classId = myClass.first.id;

          return StreamBuilder(
            stream: planningRepo.getMeetings(),
            builder: (context, meetingsSnapshot) {
              if (!meetingsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final meetings = meetingsSnapshot.data!
                  .where((m) => m.classId == classId)
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date));

              if (meetings.isEmpty) {
                return const _EmptyState(
                  icon: Icons.event_note_rounded,
                  title: 'Nessun incontro',
                  subtitle: 'Non ci sono incontri programmati per la tua classe.',
                );
              }

              return StreamBuilder<Map<String, bool>>(
                stream: _getAttendanceStatus(),
                builder: (context, attendanceSnapshot) {
                  final attendanceMap = attendanceSnapshot.data ?? {};

                  return ListView.separated(
                    padding: const EdgeInsets.only(
                      bottom: 100,
                      left: 16,
                      right: 16,
                      top: 16,
                    ),
                    itemCount: meetings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final m = meetings[index];
                      final exists = attendanceMap[m.id] ?? false;
                      final formattedDate =
                          DateFormat('dd MMMM yyyy', 'it_IT').format(m.date);

                      return InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => context.push('/attendance', extra: m),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.blue.shade50.withOpacity(0.35),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.blue.shade100),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 74,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF174A7E),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      DateFormat('dd').format(m.date),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MMM', 'it_IT')
                                          .format(m.date)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formattedDate,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF174A7E),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.menu_book_rounded,
                                          size: 18,
                                          color: Colors.orange.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            m.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (m.activity.trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        m.activity,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                    if (exists) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.green.withOpacity(0.4),
                                          ),
                                        ),
                                        child: const Text(
                                          'Presenza gia registrata',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ],
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: const Color(0xFF174A7E)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
