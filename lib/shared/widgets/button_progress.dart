import 'package:flutter/material.dart';

/// Contenido de un botón mientras su solicitud está en proceso.
class ButtonProgress extends StatelessWidget {
  const ButtonProgress({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Flexible(child: Text(label)),
      ],
    );
  }
}
