import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_controller.dart';

/// Cierra la sesión. Si imSafeAPI no confirma la revocación, la sesión se
/// cierra igualmente en el dispositivo y se informa al usuario.
class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Cerrar sesión',
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await ref.read(sessionControllerProvider.notifier).logout();
        } catch (_) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Sesión cerrada en este dispositivo. imSafeAPI no confirmó '
                'la revocación; expirará por sí sola.',
              ),
            ),
          );
        }
      },
    );
  }
}
