import 'package:flutter/material.dart';

/// Compact WSS link status strip for the crew phone UI.
class WssBanner extends StatelessWidget {
  const WssBanner({super.key, required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected
        ? const Color(0xFF1B7F4E)
        : const Color(0xFFB3261E);
    final bg = connected
        ? const Color(0xFFE8F5EE)
        : const Color(0xFFFCE8E6);
    final label = connected ? 'WSS: conectat' : 'WSS: deconectat';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.25))),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            connected ? Icons.wifi : Icons.wifi_off,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          if (!connected)
            Text(
              'Reconectare…',
              style: TextStyle(
                color: color.withValues(alpha: 0.85),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}
