import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failure_messages.dart';
import '../features/access/presentation/launcher_access_controller.dart';
import '../features/auth/presentation/logout_button.dart';
import '../features/auth/presentation/session_controller.dart';
import '../shared/widgets/status_message.dart';

/// Mientras se restaura la sesión o se consulta el estado en imSafeAPI.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Consultando imSafeAPI…'),
            ],
          ),
        ),
      ),
    );
  }
}

/// No se pudo determinar la sesión o el estado del lanzador. Un fallo de red
/// se muestra como tal: nunca como "no autorizado".
class StatusErrorScreen extends ConsumerWidget {
  const StatusErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final access = ref.watch(launcherAccessProvider);
    final error = session.error ?? access.error;
    final loading = session.isLoading || access.isLoading;
    final signedIn = session.value == SessionStatus.signedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('imSafe · Lanzadores'),
        actions: [if (signedIn) const LogoutButton()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'No se pudo consultar tu estado',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  if (error != null)
                    StatusMessage(
                      tone: StatusTone.error,
                      message: describeFailure(error),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: loading
                        ? null
                        : () => session.hasError
                              ? ref.invalidate(sessionControllerProvider)
                              : ref.invalidate(launcherAccessProvider),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
