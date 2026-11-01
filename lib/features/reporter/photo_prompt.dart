import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/wingman_theme.dart';
import 'reporter_language.dart';

/// Five-second, fully optional photo prompt shown just before sending a report.
///
/// Returns the captured bytes, or null when the countdown expires / the user
/// skips. Never blocks a critical report for more than five seconds.
Future<Uint8List?> showIncidentPhotoPrompt(
  BuildContext context, {
  ReporterLanguage language = ReporterLanguage.ro,
}) {
  return showDialog<Uint8List?>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PhotoPromptDialog(language: language),
  );
}

class _PhotoPromptDialog extends StatefulWidget {
  const _PhotoPromptDialog({this.language = ReporterLanguage.ro});

  final ReporterLanguage language;

  @override
  State<_PhotoPromptDialog> createState() => _PhotoPromptDialogState();
}

class _PhotoPromptDialogState extends State<_PhotoPromptDialog> {
  final ImagePicker _picker = ImagePicker();
  Timer? _timer;
  int _secondsLeft = 5;
  bool _picking = false;
  bool _attempted = false;
  String? _error;

  Tr get _tr => Tr(widget.language);

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
      debugPrint('[photo] launching camera');
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        imageQuality: 60,
      );
      debugPrint('[photo] picker returned ${file?.path}');
      if (!mounted) return;
      if (file == null) {
        setState(() {
          _picking = false;
          _attempted = true;
          _error = _tr(
            'Poza nu a fost confirmată. În camera Samsung apasă OK '
                'după shutter, apoi revino aici.',
            'Photo not confirmed. In the Samsung camera press OK after '
                'the shutter, then come back here.',
          );
        });
        // Do not auto-send after an attempted capture: let the reporter retry
        // or explicitly choose "Trimite fără poză".
        return;
      }
      final bytes = await file.readAsBytes();
      debugPrint('[photo] read ${bytes.length} bytes');
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _attempted = true;
        _error = 'Camera indisponibilă: $error';
      });
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
              _tr('Adaugă o poză?', 'Add a photo?'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (!_attempted)
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
          Text(
            _attempted
                ? _tr(
                    'Apasă OK în camera Samsung după ce faci poza, apoi '
                        'revino aici. Poți încerca din nou sau trimite fără poză.',
                    'Press OK in the Samsung camera after taking the photo, then '
                        'come back. Retry or send without a photo.',
                  )
                : _tr(
                    'Opțional. Dacă situația e periculoasă, sari peste — raportul '
                        'pleacă oricum după 5 secunde.',
                    'Optional. If this is dangerous, skip it — the report is sent '
                        'anyway after 5 seconds.',
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            _tr(
              'După shutter, apasă OK în camera Samsung.',
              'After the shutter, press OK in the Samsung camera.',
            ),
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
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
                    _picking
                        ? _tr('Se deschide camera…', 'Opening the camera…')
                        : _attempted
                            ? _tr('Reîncearcă poza', 'Retry photo')
                            : _tr('Fă poza acum', 'Take the photo'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _tr('Buton mare · 5 secunde', 'Large button · 5 seconds'),
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
            child: Text(_tr('Trimite fără poză', 'Send without a photo')),
          ),
        ],
      ),
    );
  }
}
