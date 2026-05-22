import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_service.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../classes/classes_provider.dart';
import 'planning_provider.dart';
import 'planning_edit_page.dart';
import '../../shared/models/planning_meeting.dart';

class PlanningPage extends ConsumerWidget {
  const PlanningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(planningRepoProvider);
    final classesAsync = ref.watch(classesStreamProvider);

    const uid = AuthService.localUserId;
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Programmazione',

      ///
      /// FLOATING BUTTON
      ///
      floatingActionButton: FloatingActionButton.extended(
        elevation: 4,
        backgroundColor: const Color(0xFF174A7E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nuova giornata',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PlanningEditPage(),
            ),
          );
        },
      ),

      ///
      /// BODY
      ///
      child: classesAsync.when(
        data: (classes) {
          final myClass = classes.where(
            (c) => c.catechistIds.contains(uid),
          );

          if (myClass.isEmpty) {
            return _EmptyState(
              icon: Icons.groups_rounded,
              title: 'Nessuna classe assegnata',
              subtitle:
                  'Non risulti ancora assegnato ad un gruppo di catechismo.',
            );
          }

          final classId = myClass.first.id;

          return StreamBuilder<List<PlanningMeeting>>(
            stream: repo.getMeetings(),
            builder: (context, snapshot) {
              ///
              /// LOADING
              ///
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final meetings = snapshot.data!
                  .where((m) => m.classId == classId)
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date));

              ///
              /// EMPTY
              ///
              if (meetings.isEmpty) {
                return _EmptyState(
                  icon: Icons.event_note_rounded,
                  title: 'Nessuna programmazione',
                  subtitle:
                      'Inizia creando il primo incontro del percorso.',
                );
              }

              ///
              /// LISTA
              ///
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: meetings.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 14),
                itemBuilder: (_, i) {
                  final m = meetings[i];

                  final formattedDate =
                      DateFormat('dd MMMM yyyy', 'it_IT')
                          .format(m.date);

                  return InkWell(
                    borderRadius: BorderRadius.circular(24),

                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PlanningEditPage(existing: m),
                        ),
                      );
                    },

                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(20),

                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.blue.shade50.withOpacity(0.35),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),

                        borderRadius: BorderRadius.circular(24),

                        border: Border.all(
                          color: Colors.blue.shade100,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),

                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          ///
                          /// DATA BOX
                          ///
                          Container(
                            width: 74,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF174A7E),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  DateFormat('dd')
                                      .format(m.date),
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

                          ///
                          /// TESTI
                          ///
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.title,
                                  style: theme
                                      .textTheme.titleMedium
                                      ?.copyWith(
                                    fontWeight:
                                        FontWeight.bold,
                                    color:
                                        const Color(0xFF174A7E),
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                ///
                                /// ATTIVITA
                                ///
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.menu_book_rounded,
                                      size: 18,
                                      color:
                                          Colors.orange.shade700,
                                    ),

                                    const SizedBox(width: 8),

                                    Expanded(
                                      child: Text(
                                        m.activity,
                                        maxLines: 3,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          height: 1.4,
                                          fontSize: 15,
                                          fontWeight:
                                              FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                if (m.notes
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 14),

                                  Container(
                                    width: double.infinity,
                                    padding:
                                        const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.grey.shade100,
                                      borderRadius:
                                          BorderRadius.circular(
                                        16,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Icon(
                                          Icons.notes_rounded,
                                          size: 18,
                                          color: Colors
                                              .grey.shade700,
                                        ),

                                        const SizedBox(
                                            width: 8),

                                        Expanded(
                                          child: Text(
                                            m.notes,
                                            style:
                                                TextStyle(
                                              color: Colors
                                                  .grey
                                                  .shade800,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          ///
                          /// MENU
                          ///
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert_rounded,
                            ),

                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(18),
                            ),

                            onSelected: (v) async {
                              if (v == 'delete') {
                                await repo.deleteMeeting(m.id);
                              }

                              if (v == 'edit') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PlanningEditPage(
                                      existing: m,
                                    ),
                                  ),
                                );
                              }
                            },

                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_rounded),
                                    SizedBox(width: 10),
                                    Text('Modifica'),
                                  ],
                                ),
                              ),
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
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },

        ///
        /// LOADING
        ///
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),

        ///
        /// ERROR
        ///
        error: (e, _) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Errore: $e',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

///
/// EMPTY STATE
///
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
              width: 95,
              height: 95,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 46,
                color: const Color(0xFF174A7E),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
