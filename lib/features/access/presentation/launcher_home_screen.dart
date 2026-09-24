import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../shared/widgets/status_message.dart';
import '../../auth/presentation/logout_button.dart';
import 'launcher_access_controller.dart';

/// Inicio del lanzador autorizado por imSafeAPI.
class LauncherHomeScreen extends ConsumerWidget {
  const LauncherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(launcherAccessProvider);
    final access = state.value;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('imSafe · Lanzador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar estado',
            onPressed: () => ref.read(launcherAccessProvider.notifier).reload(),
          ),
          const LogoutButton(),
        ],
      ),
      body: SafeArea(
        child: access == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (state.isLoading) const LinearProgressIndicator(),
                  if (state.hasError) ...[
                    StatusMessage(
                      tone: StatusTone.error,
                      message:
                          'No se pudo actualizar. Se muestra la última '
                          'información recibida.\n'
                          '${describeFailure(state.error!)}',
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(access.user.name, style: textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Text(
                    'Autorizado como lanzador en:',
                    style: textTheme.titleMedium,
                  ),
                  for (final item in access.launcherInstitutions)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.verified_user_outlined),
                        title: Text(item.institution.name),
                        subtitle: item.institution.address == null
                            ? null
                            : Text(item.institution.address!),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const StatusMessage(
                    tone: StatusTone.info,
                    message:
                        'La emisión de alertas y la consulta de reportes aún '
                        'no están disponibles: la versión actual de imSafeAPI '
                        'no ofrece esas operaciones.',
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.go(AppRoutes.access),
                    child: const Text('Mis solicitudes de acceso'),
                  ),
                ],
              ),
      ),
    );
  }
}
