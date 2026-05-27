import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../core/services/qr_data_service.dart';
import '../../core/providers/data_share_provider.dart';

class DataShareSendPage extends ConsumerStatefulWidget {
  const DataShareSendPage({super.key});

  @override
  ConsumerState<DataShareSendPage> createState() => _DataShareSendPageState();
}

class _DataShareSendPageState extends ConsumerState<DataShareSendPage> {
  Map<String, dynamic>? _data;
  String? _pin;
  List<QRChunk> _chunks = [];
  int _currentChunkIndex = 0;
  Timer? _timer;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Pulisci i provider quando la pagina viene distrutta
    ref.read(dataShareDataProvider.notifier).state = null;
    ref.read(dataSharePinProvider.notifier).state = null;
    super.dispose();
  }

  void _initializeData() {
    // Recupera i dati dai provider
    final data = ref.read(dataShareDataProvider);
    final pin = ref.read(dataSharePinProvider);
    
    if (data != null && pin != null) {
      setState(() {
        _data = data;
        _pin = pin;
      });

      _prepareChunks();
    } else {
      // Se non ci sono dati, torna alla selezione
      if (mounted) {
        context.go('/data-share');
      }
    }
  }

  void _prepareChunks() {
    if (_data == null || _pin == null) return;

    // Crea il pacchetto dati
    final package = QRDataService.createPackage(_data!, _pin!);
    
    // Comprimi i dati del pacchetto
    final compressedPackage = QRDataService.compressData(package.toMap());
    
    // Segmenta in chunk
    final chunkStrings = QRDataService.segmentData(compressedPackage);
    
    // Crea QR chunk
    setState(() {
      _chunks = chunkStrings.asMap().entries.map((entry) {
        return QRDataService.createQRChunk(
          entry.value,
          entry.key,
          chunkStrings.length,
        );
      }).toList();
      
      _currentChunkIndex = 0;
      _startAnimation();
    });
  }

  void _startAnimation() {
    // Mostra ogni chunk a 3 FPS (circa 333ms per frame)
    _timer = Timer.periodic(const Duration(milliseconds: 333), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _currentChunkIndex = (_currentChunkIndex + 1) % _chunks.length;
      });
    });
  }

  void _pauseAnimation() {
    _timer?.cancel();
  }

  void _resumeAnimation() {
    _startAnimation();
  }

  void _completeSharing() {
    _pauseAnimation();
    
    // Pulisci i provider
    ref.read(dataShareDataProvider.notifier).state = null;
    ref.read(dataSharePinProvider.notifier).state = null;
    
    setState(() {
      _isCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null || _pin == null) {
      return AppScaffold(
        title: 'Errore',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Dati non disponibili'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/data-share'),
                child: const Text('Torna indietro'),
              ),
            ],
          ),
        ),
      );
    }

    if (_chunks.isEmpty) {
      return AppScaffold(
        title: 'Preparazione...',
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF174A7E)),
        ),
      );
    }

    final currentChunk = _chunks[_currentChunkIndex];

    return AppScaffold(
      title: 'Invio Dati',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_isCompleted)
              _CompletionCard(pin: _pin!)
            else
              _QRDisplayCard(
                chunk: currentChunk,
                currentChunkIndex: _currentChunkIndex,
                totalChunks: _chunks.length,
                onPause: _pauseAnimation,
                onResume: _resumeAnimation,
                onComplete: _completeSharing,
              ),
          ],
        ),
      ),
    );
  }
}

class _QRDisplayCard extends StatelessWidget {
  final QRChunk chunk;
  final int currentChunkIndex;
  final int totalChunks;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onComplete;

  const _QRDisplayCard({
    required this.chunk,
    required this.currentChunkIndex,
    required this.totalChunks,
    required this.onPause,
    required this.onResume,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProgressCard(
          current: currentChunkIndex + 1,
          total: totalChunks,
        ),
        const SizedBox(height: 24),

        _PinCard(pin: '****'), // PIN nascosto durante trasmissione
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: QrImageView(
            data: chunk.toJson(),
            version: QrVersions.auto,
            errorCorrectionLevel: QrErrorCorrectLevel.L,
            size: 280,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 24),

        _InfoText(
          text: 'Chunk ${currentChunkIndex + 1} di $totalChunks',
          icon: Icons.qr_code_2_rounded,
        ),
        const SizedBox(height: 8),

        _InfoText(
          text: 'I QR code vengono mostrati ciclicamente',
          icon: Icons.autorenew_rounded,
        ),
        const SizedBox(height: 32),

        Row(
          children: [
            Expanded(
              child: _ControlButton(
                icon: Icons.pause_rounded,
                label: 'Pausa',
                color: Colors.orange,
                onTap: onPause,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ControlButton(
                icon: Icons.play_arrow_rounded,
                label: 'Riprendi',
                color: Colors.green,
                onTap: onResume,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ControlButton(
                icon: Icons.check_rounded,
                label: 'Completa',
                color: const Color(0xFF174A7E),
                onTap: onComplete,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressCard({
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = current / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF174A7E).withOpacity(0.8),
            const Color(0xFF2E5A8F).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progresso Trasmissione',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$current/$total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  final String pin;

  const _PinCard({required this.pin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.security_rounded,
            color: Colors.amber,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PIN di Sicurezza',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Comunica questo PIN al ricevente: $pin',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.amber.shade900,
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

class _CompletionCard extends StatelessWidget {
  final String pin;

  const _CompletionCard({required this.pin});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Trasmissione Completata',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF174A7E),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'PIN: $pin',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Il ricevente deve inserire questo PIN per completare l\'importazione',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton.icon(
          onPressed: () => context.go('/data-share'),
          icon: const Icon(Icons.home_rounded),
          label: const Text('Torna alla selezione'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF174A7E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ],
    );
  }
}

class _InfoText extends StatelessWidget {
  final String text;
  final IconData icon;

  const _InfoText({
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
