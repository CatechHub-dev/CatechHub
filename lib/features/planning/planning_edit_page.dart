import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../shared/models/planning_meeting.dart';
import '../classes/classes_provider.dart';
import 'planning_provider.dart';

class PlanningEditPage extends ConsumerStatefulWidget {
  final PlanningMeeting? existing;

  const PlanningEditPage({super.key, this.existing});

  @override
  ConsumerState<PlanningEditPage> createState() => _PlanningEditPageState();
}

class _PlanningEditPageState extends ConsumerState<PlanningEditPage> {
  DateTime? selectedDate;

  final title = TextEditingController();
  final activity = TextEditingController();
  final notes = TextEditingController();

  @override
  void initState() {
    super.initState();

    final meeting = widget.existing;
    if (meeting != null) {
      selectedDate = meeting.date;
      title.text = meeting.title;
      activity.text = meeting.activity;
      notes.text = meeting.notes;
    }
  }

  @override
  void dispose() {
    title.dispose();
    activity.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(planningRepoProvider);
    final classesAsync = ref.watch(classesStreamProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF174A7E),
        foregroundColor: Colors.white,
        title: Text(
          widget.existing == null ? 'Nuova giornata' : 'Modifica giornata',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: classesAsync.when(
        data: (classes) {
          final myClass = classes.where(
            (c) => c.catechistIds.contains(AuthService.localUserId),
          );

          if (myClass.isEmpty) {
            return const Center(
              child: Text('Non sei assegnato a nessuna classe'),
            );
          }

          final classId = myClass.first.id;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _DatePickerCard(
                  selectedDate: selectedDate,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF174A7E),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                ),
                const SizedBox(height: 18),
                _ModernInputCard(
                  icon: Icons.title_rounded,
                  color: const Color(0xFF174A7E),
                  child: TextField(
                    controller: title,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Titolo giornata',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _ModernInputCard(
                  icon: Icons.menu_book_rounded,
                  color: Colors.orange,
                  child: TextField(
                    controller: activity,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Attivita / Argomenti',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _ModernInputCard(
                  icon: Icons.notes_rounded,
                  color: Colors.blue,
                  child: TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Note',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF174A7E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.save_rounded),
                    label: const Text(
                      'Salva giornata',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      if (selectedDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Seleziona una data')),
                        );
                        return;
                      }

                      if (title.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Inserisci un titolo per la giornata'),
                          ),
                        );
                        return;
                      }

                      final meeting = PlanningMeeting(
                        id: widget.existing?.id ?? '',
                        classId: classId,
                        createdBy: AuthService.localUserId,
                        date: selectedDate!,
                        title: title.text.trim(),
                        activity: activity.text.trim(),
                        notes: notes.text.trim(),
                      );

                      try {
                        if (widget.existing == null) {
                          await repo.addMeeting(meeting);
                        } else {
                          await repo.updateMeeting(meeting.id, meeting);
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Errore: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
      ),
    );
  }
}

class _DatePickerCard extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onTap;

  const _DatePickerCard({
    required this.selectedDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedDate != null;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [
                    const Color(0xFF174A7E),
                    const Color(0xFF2A6BB0),
                  ]
                : [
                    Colors.white,
                    Colors.blue.shade50.withOpacity(0.4),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.blue.shade100,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.15) : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                color: isSelected ? Colors.white : const Color(0xFF174A7E),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data incontro',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSelected
                        ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                        : 'Seleziona una data',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF174A7E),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isSelected ? Colors.white70 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernInputCard extends StatelessWidget {
  final Widget child;
  final IconData icon;
  final Color color;

  const _ModernInputCard({
    required this.child,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
