import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/wingman_theme.dart';

/// Five-second, fully optional photo prompt shown just before sending a report.
///
/// Returns the captured bytes, or null when the countdown expires / the user
/// skips. Never blocks a critical report for more than five seconds.
Future<Uint8List?> showIncidentPhotoPrompt(BuildContext context) {
  return showDialog<Uint8List?>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PhotoPromptDialog(),
  );
}

class _PhotoPromptDialog extends StatefulWidget {
  const _PhotoPromptDialog();

  @override
  State<_PhotoPromptDialog> createState() => _PhotoPromptDialogState();
}

class _PhotoPromptDialogState extends State<_PhotoPromptDialog> {
  final ImagePicker _picker = ImagePicker();
  Timer? _timer;
  int _secondsLeft = 5;
  bool _picking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _secondsLeft = 5;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        if (!_picking) Navigator.of(context).pop();
      }
    });
  }

  Future<void> _takePhoto() async {
    _timer?.cancel();
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        imageQuality: 60,
      );
      if (!mounted) return;
      if (file == null) {
        setState(() => _picking = false);
        _startCountdown();
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = 'Camera indisponibilă: $error';
      });
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      title: Row(
        children: <Widget>[
          const Icon(Icons.photo_camera_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Adaugă o poză?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: WingmanColors.criticalFill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$_secondsLeft s',
              style: const TextStyle(
                color: WingmanColors.critical,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'Opțional. Dacă situația e periculoasă, sari peste — raportul '
            'pleacă oricum după 5 secunde.',
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _picking ? null : _takePhoto,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26),
              decoration: BoxDecoration(
                color: WingmanColors.navy,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: <Widget>[
                  Icon(
                    _picking ? Icons.hourglass_top : Icons.photo_camera,
                    color: Colors.white,
                    size: 44,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _picking ? 'Se deschide camera…' : 'Fă poza acum',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Buton mare · 5 secunde',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: WingmanColors.critical),
            ),
          ],
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Trimite fără poză'),
          ),
        ],
      ),
    );
  }
}
