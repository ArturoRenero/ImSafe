import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/button_progress.dart';
import '../../../shared/widgets/status_message.dart';
import '../../access/presentation/launcher_access_controller.dart';
import '../data/alert_dtos.dart';
import '../domain/alert_command.dart';
import 'alert_command_controller.dart';
import 'alert_preparation_controller.dart';
import 'alert_texts.dart';

/// Estado actual de una alerta y sus comandos (actualizar, finalizar,
/// cancelar). Tras cada comando aceptado se vuelve a consultar la API: el
/// estado mostrado siempre es el del backend.
class AlertDetailScreen extends ConsumerWidget {
  const AlertDetailScreen({
    super.key,
    required this.institutionId,
    required this.alertId,
  });

  final String institutionId;
  final String alertId;

  AlertRef get _ref => (institutionId: institutionId, alertId: alertId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(alertProvider(_ref));
    void reload() {
      ref.invalidate(alertProvider(_ref));
      ref.invalidate(alertDeliveryProvider(_ref));
      ref.invalidate(activeAlertsProvider(institutionId));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: state.isLoading ? null : reload,
          ),
        ],
      ),
      body: SafeArea(
        child: switch (state) {
          AsyncValue(:final value?) => _AlertDetail(
            alert: value,
            alertRef: _ref,
            refreshing: state.isLoading,
            onChanged: reload,
          ),
          AsyncError(:final error) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StatusMessage(
                tone: StatusTone.error,
                message: describeAlertFailure(error),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: reload, child: const Text('Reintentar')),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

enum _Action { update, close, cancel }

class _AlertDetail extends ConsumerStatefulWidget {
  const _AlertDetail({
    required this.alert,
    required this.alertRef,
    required this.refreshing,
    required this.onChanged,
  });

  final InstitutionAlert alert;
  final AlertRef alertRef;
  final bool refreshing;
  final VoidCallback onChanged;

  @override
  ConsumerState<_AlertDetail> createState() => _AlertDetailState();
}

class _AlertDetailState extends ConsumerState<_AlertDetail> {
  _Action? _lastAction;

  String get _scope => 'alert:${widget.alert.id}';

  Future<void> _run(_Action action) async {
    final alert = widget.alert;
    final text = await showDialog<String>(
      context: context,
      builder: (context) => _CommandDialog(action: action, alert: alert),
    );
    if (text == null || !mounted) return;

    final command = switch (action) {
      _Action.update => UpdateAlertMessage(
        institutionId: alert.institutionId,
        alertId: alert.id,
        expectedRevision: alert.revision,
        message: text,
      ),
      _Action.close || _Action.cancel => TransitionAlert(
        institutionId: alert.institutionId,
        alertId: alert.id,
        expectedRevision: alert.revision,
        target: action == _Action.close
            ? AlertTransitionTarget.closed
            : AlertTransitionTarget.cancelled,
        reason: text,
      ),
    };
    setState(() => _lastAction = action);
    await ref.read(alertCommandProvider(_scope).notifier).send(command);
    // Aceptado o rechazado (p. ej. REVISION_CONFLICT): el estado real vuelve
    // a consultarse a la API.
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final catalog = ref.watch(emergencyTypesProvider).value;
    final delivery = ref.watch(alertDeliveryProvider(widget.alertRef));
    final command = ref.watch(alertCommandProvider(_scope));
    final sending = command?.isLoading ?? false;
    final isLauncher =
        ref
            .watch(launcherAccessProvider)
            .value
            ?.institutionById(alert.institutionId)
            ?.isLauncher ??
        false;
    final textTheme = Theme.of(context).textTheme;

    Widget field(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelLarge),
          Text(value),
        ],
      ),
    );

    Widget actionButton(_Action action, String label, {bool filled = false}) {
      final child = sending && _lastAction == action
          ? const ButtonProgress(label: 'Enviando…')
          : Text(label);
      final onPressed = sending || widget.refreshing
          ? null
          : () => _run(action);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: filled
            ? FilledButton(onPressed: onPressed, child: child)
            : OutlinedButton(onPressed: onPressed, child: child),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.refreshing) const LinearProgressIndicator(),
        Text(
          emergencyTypeLabel(catalog, alert.type),
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text('Estado: ${alertStateLabel(alert.state)}'),
        const SizedBox(height: 16),
        if (alert.otherDescription case final description?)
          field('Descripción', description),
        field('Instrucciones', alert.message),
        field('Emitida', formatAlertTime(context, alert.createdAt)),
        field(
          'Última actualización',
          formatAlertTime(context, alert.updatedAt),
        ),
        if (alert.endedAt case final ended?)
          field('Terminó', formatAlertTime(context, ended))
        else
          field('Expira', formatAlertTime(context, alert.expiresAt)),
        field('Revisión', '${alert.revision}'),
        if (command case AsyncError(:final error)) ...[
          const SizedBox(height: 8),
          StatusMessage(
            tone: StatusTone.error,
            message: describeAlertFailure(error),
          ),
        ],
        if (command case AsyncData(:final value)) ...[
          const SizedBox(height: 8),
          StatusMessage(
            tone: StatusTone.success,
            message:
                'imSafeAPI aceptó el cambio (revisión '
                '${value.acceptedRevision}). Consulta abajo el estado de su '
                'distribución.',
          ),
        ],
        if (alert.state == AlertState.active && isLauncher) ...[
          const SizedBox(height: 16),
          actionButton(_Action.update, 'Actualizar instrucciones'),
          actionButton(_Action.close, 'Finalizar alerta', filled: true),
          actionButton(_Action.cancel, 'Cancelar alerta'),
        ],
        const SizedBox(height: 24),
        Text('Distribución del último cambio', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        switch (delivery) {
          AsyncValue(:final value?) => _DeliverySummary(status: value),
          AsyncError(:final error) => StatusMessage(
            tone: StatusTone.error,
            message: describeAlertFailure(error),
          ),
          _ => const LinearProgressIndicator(),
        },
      ],
    );
  }
}

class _DeliverySummary extends StatelessWidget {
  const _DeliverySummary({required this.status});

  final AlertDeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estado de envío: ${outboxStateLabel(status.outboxState)}'
          '${status.fanoutComplete ? '' : ' (conteo aún no definitivo)'}',
        ),
        Text(
          'Pendientes ${status.pending} · Aceptadas por el proveedor '
          '${status.accepted} · Fallidas ${status.failed} · Omitidas '
          '${status.skipped}',
        ),
        Text(
          'Acuses: recibidas ${status.received} · abiertas ${status.opened}',
        ),
        const SizedBox(height: 4),
        Text(
          '"Aceptadas" no significa entregadas y los acuses los declara cada '
          'dispositivo: no confirman que una persona esté a salvo.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _CommandDialog extends StatefulWidget {
  const _CommandDialog({required this.action, required this.alert});

  final _Action action;
  final InstitutionAlert alert;

  @override
  State<_CommandDialog> createState() => _CommandDialogState();
}

class _CommandDialogState extends State<_CommandDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _text = TextEditingController(
    text: widget.action == _Action.update ? widget.alert.message : '',
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (title, label, confirm, rule) = switch (widget.action) {
      _Action.update => (
        '¿Actualizar las instrucciones?',
        'Instrucciones breves',
        'Actualizar',
        AlertTextRules.message,
      ),
      _Action.close => (
        '¿Finalizar la alerta?',
        'Motivo',
        'Finalizar',
        AlertTextRules.reason,
      ),
      _Action.cancel => (
        '¿Cancelar la alerta?',
        'Motivo',
        'Cancelar alerta',
        AlertTextRules.reason,
      ),
    };

    return AlertDialog(
      title: Text(title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.action == _Action.update)
              const Text(
                'imSafeAPI conserva el tipo, renueva la duración y avisa del '
                'cambio.',
              )
            else
              Text(
                'La alerta quedará como '
                '"${widget.action == _Action.close ? 'Finalizada' : 'Cancelada'}"'
                ' y no podrá reactivarse.',
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _text,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              maxLength: rule.maxLength,
              decoration: InputDecoration(labelText: label),
              validator: (value) => validateAlertText(value, rule),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _text.text.trim());
            }
          },
          child: Text(confirm),
        ),
      ],
    );
  }
}
