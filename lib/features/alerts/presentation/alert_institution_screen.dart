import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../access/presentation/institution_capability_tile.dart';
import '../../access/presentation/launcher_access_controller.dart';

/// Selección de la institución para la que se prepara la alerta. Solo las
/// instituciones con `capabilities.launcher == true` permiten continuar.
class AlertInstitutionScreen extends ConsumerWidget {
  const AlertInstitutionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(launcherAccessProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Generar alerta')),
      body: SafeArea(
        child: access == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Selecciona la institución',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (access.institutions.isEmpty)
                    const Text(
                      'imSafeAPI no reporta instituciones asociadas a tu '
                      'cuenta.',
                    ),
                  for (final item in access.institutions)
                    InstitutionCapabilityTile(
                      item: item,
                      onSelected: () => context.push(
                        AppRoutes.alertEmit(item.institution.id),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
