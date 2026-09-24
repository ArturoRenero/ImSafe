import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../shared/widgets/status_message.dart';
import 'alert_preparation_controller.dart';
import 'alert_texts.dart';

/// Alertas activas de una institución según imSafeAPI. Un fallo de red se
/// muestra como error, nunca como "sin alertas".
class ActiveAlertsScreen extends ConsumerWidget {
  const ActiveAlertsScreen({super.key, required this.institutionId});

  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeAlertsProvider(institutionId));
    final catalog = ref.watch(emergencyTypesProvider).value;
    Future<void> reload() =>
        ref.refresh(activeAlertsProvider(institutionId).future);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas activas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: state.isLoading ? null : reload,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.isLoading) const LinearProgressIndicator(),
              switch (state) {
                AsyncData(:final value) when value.isEmpty => const Text(
                  'imSafeAPI no reporta alertas activas en esta institución.',
                ),
                AsyncData(:final value) => Column(
                  children: [
                    for (final alert in value)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.campaign_outlined),
                          title: Text(emergencyTypeLabel(catalog, alert.type)),
                          subtitle: Text(
                            '${alert.message}\n'
                            'Expira: ${formatAlertTime(context, alert.expiresAt)}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                            AppRoutes.alertDetail(institutionId, alert.id),
                          ),
                        ),
                      ),
                  ],
                ),
                AsyncError(:final error) => StatusMessage(
                  tone: StatusTone.error,
                  message: describeAlertFailure(error),
                ),
                _ => const SizedBox.shrink(),
              },
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Emitir alerta'),
                onPressed: () =>
                    context.push(AppRoutes.alertEmit(institutionId)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
