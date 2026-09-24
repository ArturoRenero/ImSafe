import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure_messages.dart';
import '../../../shared/widgets/status_message.dart';
import '../../access/presentation/institution_capability_tile.dart';
import '../../access/presentation/launcher_access_controller.dart';
import '../domain/alert_api_feature.dart';
import '../domain/alert_preparation.dart';
import 'alert_preparation_controller.dart';

/// Texto visible cuando imSafeAPI todavía no ofrece [feature].
String alertFeatureUnavailableMessage(AlertApiFeature feature) =>
    switch (feature) {
      AlertApiFeature.emergencyTypes =>
        'Los tipos de emergencia todavía no están disponibles en la API.',
      AlertApiFeature.affectedAreas =>
        'Las áreas afectadas todavía no están disponibles en la API.',
      AlertApiFeature.createAlert =>
        'La creación de alertas todavía no está disponible en la API.',
      AlertApiFeature.updateAlert =>
        'La actualización de alertas todavía no está disponible en la API.',
      AlertApiFeature.finishAlert =>
        'La finalización de alertas todavía no está disponible en la API.',
    };

/// Preparación de una alerta para una institución.
///
/// Mientras imSafeAPI no publique el contrato de alertas, la pantalla muestra
/// qué falta y no permite enviar nada: no simula que una alerta se creó.
class AlertPreparationScreen extends ConsumerWidget {
  const AlertPreparationScreen({super.key, required this.institutionId});

  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(alertPreparationProvider(institutionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Preparar alerta')),
      body: SafeArea(
        child: switch (state) {
          AsyncData(:final value) => _Preparation(preparation: value),
          AsyncError(:final error) => _LoadError(error: error),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Preparation extends StatelessWidget {
  const _Preparation({required this.preparation});

  final AlertPreparation preparation;

  @override
  Widget build(BuildContext context) {
    final institution = preparation.institution;
    final textTheme = Theme.of(context).textTheme;

    if (preparation.status == AlertPreparationStatus.permissionDenied) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (institution != null) ...[
            Text(institution.institution.name, style: textTheme.titleLarge),
            const SizedBox(height: 16),
          ],
          StatusMessage(
            tone: StatusTone.error,
            message: institution?.isAdministrator ?? false
                ? '$launcherDeniedMessage\n$administratorIsNotLauncherMessage'
                : launcherDeniedMessage,
          ),
        ],
      );
    }

    final missing = preparation.missingFeatures;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(institution!.institution.name, style: textTheme.titleLarge),
        const SizedBox(height: 8),
        const StatusMessage(
          tone: StatusTone.success,
          message:
              'imSafeAPI reporta que tienes permiso de lanzador en esta '
              'institución. La API vuelve a validarlo al emitir la alerta.',
        ),
        const SizedBox(height: 24),
        Text('Tipo de emergencia', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        if (missing.contains(AlertApiFeature.emergencyTypes)) ...[
          StatusMessage(
            tone: StatusTone.info,
            message: alertFeatureUnavailableMessage(
              AlertApiFeature.emergencyTypes,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sismo será la opción predeterminada cuando imSafeAPI publique los '
            'tipos de emergencia.',
          ),
        ],
        const SizedBox(height: 24),
        Text('Áreas afectadas', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        if (missing.contains(AlertApiFeature.affectedAreas))
          StatusMessage(
            tone: StatusTone.info,
            message: alertFeatureUnavailableMessage(
              AlertApiFeature.affectedAreas,
            ),
          ),
        const SizedBox(height: 32),
        StatusMessage(
          tone: StatusTone.info,
          message: alertFeatureUnavailableMessage(AlertApiFeature.createAlert),
        ),
        const SizedBox(height: 12),
        const FilledButton(onPressed: null, child: Text('Revisar alerta')),
      ],
    );
  }
}

class _LoadError extends ConsumerWidget {
  const _LoadError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatusMessage(tone: StatusTone.error, message: describeFailure(error)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => ref.read(launcherAccessProvider.notifier).reload(),
          child: const Text('Reintentar'),
        ),
      ],
    );
  }
}
