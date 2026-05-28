import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/services/data_export_service.dart';
import '../../shared/widgets/app_scaffold.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _isExporting = false;
  bool _isImporting = false;
  String? _statusMessage;
  bool _isError = false;

  // ────────────────────────────────────────────
  //  EXPORT
  // ────────────────────────────────────────────

  Future<void> _exportBackup() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isExporting = true;
      _statusMessage = null;
      _isError = false;
    });

    try {
      // Chiedi il PIN per cifrare il backup
      final pin = await _askPin(
        title: 'Cifra Backup',
        message: 'Inserisci il PIN per proteggere il file di backup.',
      );
      if (pin == null) {
        setState(() => _isExporting = false);
        return;
      }

      // Verifica che il PIN sia quello corretto dell'utente
      final authService = ref.read(authServiceProvider);
      final pinValid = await authService.signInWithPin(pin);
      if (!pinValid) {
        setState(() {
          _isExporting = false;
          _statusMessage = 'PIN non corretto';
          _isError = true;
        });
        return;
      }

      // Esporta e cifra
      final encrypted = await DataExportService.exportEncryptedData(pin);
      final bytes = Uint8List.fromList(utf8.encode(encrypted));

      // Permetti all'utente di scegliere dove salvare
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'catechhub_backup_$timestamp.catechhub';

      String? savedPath;
      // Try to use saveFile first (with bytes parameter as it's required)
      try {
        savedPath = await FilePicker.saveFile(
          dialogTitle: 'Salva backup',
          fileName: fileName,
          bytes: bytes,
        );
      } catch (e) {
        // If saveFile fails, try alternative approach
        final directory = await FilePicker.getDirectoryPath();
        if (directory != null) {
          savedPath = '$directory/$fileName';
          await File(savedPath).writeAsBytes(bytes, flush: true);
        }
      }

      if (savedPath != null) {
        // Assicura la scrittura del file anche quando FilePicker.saveFile restituisce solo il path
        final file = File(savedPath);
        await file.writeAsBytes(bytes, flush: true);

        if (await file.exists()) {
          final fileSize = await file.length();
          if (fileSize == 0) {
            await file.writeAsBytes(bytes, flush: true);
          }
        }
        setState(() {
          _statusMessage = 'Backup esportato con successo';
          _isError = false;
        });
      } else {
        setState(() {
          _statusMessage = 'Esportazione annullata';
          _isError = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Errore durante l\'esportazione: $e';
        _isError = true;
      });
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // ────────────────────────────────────────────
  //  IMPORT
  // ────────────────────────────────────────────

  Future<void> _importBackup() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isImporting = true;
      _statusMessage = null;
      _isError = false;
    });

    try {
      // Seleziona file
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: false,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _isImporting = false);
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        throw Exception('Impossibile leggere il file selezionato: percorso non disponibile');
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Il file selezionato non esiste: $filePath');
      }

      final encryptedData = await file.readAsString();

      // Chiedi il PIN per decifrare
      final pin = await _askPin(
        title: 'Decifra Backup',
        message: 'Inserisci il PIN usato per proteggere questo backup.',
      );
      if (pin == null) {
        setState(() => _isImporting = false);
        return;
      }

      // Verifica PIN provando a decifrare
      if (!DataExportService.verifyEncryptedPassword(encryptedData, pin)) {
        setState(() {
          _isImporting = false;
          _statusMessage = 'PIN non corretto o file non valido';
          _isError = true;
        });
        return;
      }

      // Conferma sovrascrittura
      final confirm = await _showConfirmDialog();
      if (confirm != true) {
        setState(() => _isImporting = false);
        return;
      }

      // Importa
      await DataExportService.importEncryptedData(encryptedData, pin);

      if (mounted) {
        setState(() {
          _statusMessage = 'Backup importato con successo';
          _isError = false;
        });
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Errore durante l\'importazione: $e';
        _isError = true;
      });
    } finally {
      setState(() => _isImporting = false);
    }
  }

  // ────────────────────────────────────────────
  //  DIALOGS
  // ────────────────────────────────────────────

  Future<String?> _askPin({
    required String title,
    required String message,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFF174A7E)),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 8,
              decoration: InputDecoration(
                labelText: 'PIN',
                hintText: 'Inserisci il PIN',
                prefixIcon: const Icon(Icons.security_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '',
              ),
              style: const TextStyle(fontSize: 20, letterSpacing: 8),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
    controller.dispose();
    return (result != null && result.isNotEmpty) ? result : null;
  }

  Future<bool?> _showConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text('Conferma Importazione')),
          ],
        ),
        content: const Text(
          'L\'importazione sostituirà tutti i dati esistenti '
          '(anagrafica, presenze, programmazione, documenti e allegati). '
          'Questa operazione non è reversibile.\n\n'
          'Vuoi continuare?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Importa'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Importazione Completata'),
          ],
        ),
        content: const Text(
          'Il backup è stato importato con successo. '
          'Tutti i dati sono stati ripristinati.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  //  BUILD
  // ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Backup',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_rounded, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Informazioni',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Il backup include tutti i dati dell\'app: anagrafica, '
                    'presenze, programmazione, documenti e allegati (foto e PDF).\n\n'
                    'Il file è protetto dal tuo PIN e può essere importato '
                    'su un altro dispositivo.',
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Export
            _ActionCard(
              icon: Icons.upload_file_rounded,
              title: 'Esporta Backup',
              subtitle: 'Salva tutti i dati in un file cifrato',
              color: const Color(0xFF174A7E),
              isLoading: _isExporting,
              onTap: _isImporting ? null : _exportBackup,
            ),

            const SizedBox(height: 16),

            // Import
            _ActionCard(
              icon: Icons.download_rounded,
              title: 'Importa Backup',
              subtitle: 'Ripristina i dati da un file di backup',
              color: Colors.green,
              isLoading: _isImporting,
              onTap: _isExporting ? null : _importBackup,
            ),

            const SizedBox(height: 24),

            // Status message
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isError
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isError
                        ? Colors.red.withOpacity(0.3)
                        : Colors.green.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isError
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      color: _isError ? Colors.red : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _isError ? Colors.red : Colors.green.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: color,
                      ),
                    )
                  : Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLoading ? 'Operazione in corso...' : subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLoading)
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
