import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/models/student_model.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../students/students_repository.dart';

final studentsRepoProvider = Provider((ref) => StudentsRepository());

class VerifyNumberPage extends ConsumerStatefulWidget {
  const VerifyNumberPage({super.key});

  @override
  ConsumerState<VerifyNumberPage> createState() => _VerifyNumberPageState();
}

class _VerifyNumberPageState extends ConsumerState<VerifyNumberPage> {
  final _phoneController = TextEditingController();
  final List<PhoneMatch> _matches = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _searchNumber() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) return;

    setState(() {
      _isSearching = true;
      _matches.clear();
    });

    final repo = ref.read(studentsRepoProvider);
    final allStudents = await repo.getAllStudents().first;

    final foundMatches = <PhoneMatch>[];

    for (final student in allStudents) {
      // Normalizza i numeri per il confronto (rimuovi spazi, trattini, ecc.)
      final searchNumber = _normalizePhone(phoneNumber);
      
      // Controlla numero studente
      if (student.studentPhone.isNotEmpty) {
        final studentPhone = _normalizePhone(student.studentPhone);
        if (studentPhone.contains(searchNumber) || searchNumber.contains(studentPhone)) {
          foundMatches.add(PhoneMatch(
            type: PhoneMatchType.student,
            name: '${student.name} ${student.surname}',
            phone: student.studentPhone,
            studentId: student.id,
          ));
        }
      }

      // Controlla numero madre
      if (student.motherPhone.isNotEmpty) {
        final motherPhone = _normalizePhone(student.motherPhone);
        if (motherPhone.contains(searchNumber) || searchNumber.contains(motherPhone)) {
          foundMatches.add(PhoneMatch(
            type: PhoneMatchType.mother,
            name: '${student.motherName} ${student.motherSurname}',
            phone: student.motherPhone,
            studentName: '${student.name} ${student.surname}',
            studentId: student.id,
          ));
        }
      }

      // Controlla numero padre
      if (student.fatherPhone.isNotEmpty) {
        final fatherPhone = _normalizePhone(student.fatherPhone);
        if (fatherPhone.contains(searchNumber) || searchNumber.contains(fatherPhone)) {
          foundMatches.add(PhoneMatch(
            type: PhoneMatchType.father,
            name: '${student.fatherName} ${student.fatherSurname}',
            phone: student.fatherPhone,
            studentName: '${student.name} ${student.surname}',
            studentId: student.id,
          ));
        }
      }
    }

    setState(() {
      _isSearching = false;
      _matches.addAll(foundMatches);
    });
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> _callNumber(String phone) async {
    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _whatsappNumber(String phone) async {
    final normalized = _normalizePhone(phone);
    final uri = Uri.parse('https://wa.me/$normalized');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Verifica Numero',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SearchCard(
              controller: _phoneController,
              isSearching: _isSearching,
              onSearch: _searchNumber,
            ),
            const SizedBox(height: 20),
            if (_matches.isNotEmpty) ...[
              Text(
                'Risultati (${_matches.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF174A7E),
                ),
              ),
              const SizedBox(height: 12),
              ..._matches.map((match) => _MatchCard(
                match: match,
                onCall: () => _callNumber(match.phone),
                onWhatsapp: () => _whatsappNumber(match.phone),
              )),
            ] else if (!_isSearching && _phoneController.text.isNotEmpty)
              _EmptyResult(),
          ],
        ),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;
  final VoidCallback onSearch;

  const _SearchCard({
    required this.controller,
    required this.isSearching,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inserisci numero di telefono',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF174A7E),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'es. 3331234567',
              prefixIcon: const Icon(Icons.phone_rounded),
              suffixIcon: isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF174A7E)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSearching ? null : onSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF174A7E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(isSearching ? 'Ricerca in corso...' : 'Cerca'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final PhoneMatch match;
  final VoidCallback onCall;
  final VoidCallback onWhatsapp;

  const _MatchCard({
    required this.match,
    required this.onCall,
    required this.onWhatsapp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: _getMatchColor(match.type).withOpacity(0.1),
          child: Icon(
            _getMatchIcon(match.type),
            color: _getMatchColor(match.type),
          ),
        ),
        title: Text(
          match.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF174A7E),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              match.phone,
              style: const TextStyle(color: Colors.grey),
            ),
            if (match.studentName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Figlio/a di: ${match.studentName}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.phone, color: Colors.green),
              onPressed: onCall,
              tooltip: 'Chiama',
            ),
            IconButton(
              icon: const Icon(Icons.message, color: Colors.green),
              onPressed: onWhatsapp,
              tooltip: 'WhatsApp',
            ),
          ],
        ),
      ),
    );
  }

  Color _getMatchColor(PhoneMatchType type) {
    switch (type) {
      case PhoneMatchType.student:
        return Colors.blue;
      case PhoneMatchType.mother:
        return Colors.pink;
      case PhoneMatchType.father:
        return Colors.indigo;
    }
  }

  IconData _getMatchIcon(PhoneMatchType type) {
    switch (type) {
      case PhoneMatchType.student:
        return Icons.person_rounded;
      case PhoneMatchType.mother:
        return Icons.woman_rounded;
      case PhoneMatchType.father:
        return Icons.man_rounded;
    }
  }
}

class _EmptyResult extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Nessun risultato trovato',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Prova con un altro numero di telefono',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

enum PhoneMatchType { student, mother, father }

class PhoneMatch {
  final PhoneMatchType type;
  final String name;
  final String phone;
  final String? studentName;
  final String? studentId;

  PhoneMatch({
    required this.type,
    required this.name,
    required this.phone,
    this.studentName,
    this.studentId,
  });
}