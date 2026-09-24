import 'package:flutter/material.dart';

enum StatusTone { info, success, error }

/// Mensaje de estado con icono y texto (no depende solo del color).
class StatusMessage extends StatelessWidget {
  const StatusMessage({super.key, required this.message, required this.tone});

  final String message;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, background, foreground) = switch (tone) {
      StatusTone.info => (
        Icons.info_outline,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      StatusTone.success => (
        Icons.check_circle_outline,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      StatusTone.error => (
        Icons.error_outline,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}
