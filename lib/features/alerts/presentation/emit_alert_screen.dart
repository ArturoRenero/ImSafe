import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../shared/widgets/button_progress.dart';
import '../../../shared/widgets/status_message.dart';
import '../../access/data/access_dtos.dart';
import '../../access/presentation/institution_capability_tile.dart';
import '../../access/presentation/launcher_access_controller.dart';
import '../data/alert_dtos.dart';
import '../domain/alert_command.dart';
import '../domain/alert_preparation.dart';
import 'alert_command_controller.dart';
import 'alert_preparation_controller.dart';
import 'alert_texts.dart';

/// Emisión de una alerta en una institución.
///
/// Solo se envía tras una confirmación explícita y la alerta se presenta como
/// registrada únicamente cuando imSafeAPI responde `202 AlertAccepted`.
class EmitAlertScreen extends ConsumerWidget {
  const EmitAlertScreen({super.key, required this.institutionId});

  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(alertPreparationProvider(institutionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Emitir alerta')),
      body: SafeArea(
        child: switch (state) {
          AsyncData(:final value)
              when value.status == AlertPreparationStatus.ready =>
            _EmitAlertForm(
              institution: value.institution!,
              types: value.emergencyTypes,
              defaultType: value.defaultType,
            ),
          AsyncData(:final value) => _PermissionDenied(
            institution: value.institution,
          ),
          AsyncError(:final error) => _LoadError(
            error: error,
            onRetry: () {
              ref.invalidate(emergencyTypesProvider);
              ref.read(launcherAccessProvider.notifier).reload();
            },
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _PermissionDenied extends StatelessWidget {
  const _PermissionDenied({required this.institution});

  final MyInstitution? institution;

  @override
  Widget build(BuildContext context) {
    final item = institution;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (item != null) ...[
          Text(
            item.institution.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
        ],
        StatusMessage(
          tone: StatusTone.error,
          message: item?.isAdministrator ?? false
              ? '$launcherDeniedMessage\n$administratorIsNotLauncherMessage'
              : launcherDeniedMessage,
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatusMessage(
          tone: StatusTone.error,
          message: describeAlertFailure(error),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}

class _EmitAlertForm extends ConsumerStatefulWidget {
  const _EmitAlertForm({
    required this.institution,
    required this.types,
    required this.defaultType,
  });

  final MyInstitution institution;
  final List<EmergencyType> types;
  final EmergencyType? defaultType;

  @override
  ConsumerState<_EmitAlertForm> createState() => _EmitAlertFormState();
}

class _EmitAlertFormState extends ConsumerState<_EmitAlertForm> {
  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();
  final _otherDescription = TextEditingController();
  late EmergencyType? _type = widget.defaultType;
  bool _showTypeError = false;

  String get _scope => 'emit:${widget.institution.institution.id}';

  @override
  void dispose() {
    _message.dispose();
    _otherDescription.dispose();
    super.dispose();
  }

  EmitAlert _command(EmergencyType type) => EmitAlert(
    institutionId: widget.institution.institution.id,
    type: type.type,
    message: _message.text.trim(),
    otherDescription: type.requiresDescription
        ? _otherDescription.text.trim()
        : null,
  );

  Future<void> _review() async {
    final type = _type;
    setState(() => _showTypeError = type == null);
    if (!_formKey.currentState!.validate() || type == null) return;

    final command = _command(type);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmEmitDialog(
        institutionName: widget.institution.institution.name,
        type: type,
        command: command,
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(alertCommandProvider(_scope).notifier).send(command);
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(alertCommandProvider(_scope));
    final sending = result?.isLoading ?? false;
    final accepted = result?.value;
    final textTheme = Theme.of(context).textTheme;
    final institutionId = widget.institution.institution.id;

    if (accepted != null) {
      return _Accepted(
        institutionId: institutionId,
        institutionName: widget.institution.institution.name,
        accepted: accepted,
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.institution.institution.name,
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const StatusMessage(
            tone: StatusTone.success,
            message:
                'imSafeAPI reporta que tienes permiso de lanzador en esta '
                'institución. La API vuelve a validarlo al emitir la alerta.',
          ),
          const SizedBox(height: 24),
          Text('Tipo de emergencia', style: textTheme.titleMedium),
          if (widget.types.isEmpty)
            const Text('imSafeAPI no devolvió tipos de emergencia.'),
          RadioGroup<String>(
            groupValue: _type?.type,
            onChanged: (value) => setState(() {
              _type = widget.types.firstWhere((t) => t.type == value);
              _showTypeError = false;
            }),
            child: Column(
              children: [
                for (final type in widget.types)
                  RadioListTile<String>(
                    value: type.type,
                    enabled: !sending,
                    title: Text(type.label),
                    subtitle: Text('Duración: ${type.durationMinutes} min'),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          if (_showTypeError)
            Text(
              'Selecciona un tipo de emergencia.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_type?.requiresDescription ?? false) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _otherDescription,
              enabled: !sending,
              maxLength: AlertTextRules.otherDescription.maxLength,
              decoration: const InputDecoration(
                labelText: 'Descripción del evento',
              ),
              validator: (value) =>
                  validateAlertText(value, AlertTextRules.otherDescription),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _message,
            enabled: !sending,
            minLines: 3,
            maxLines: 6,
            maxLength: AlertTextRules.message.maxLength,
            decoration: const InputDecoration(
              labelText: 'Instrucciones breves',
              helperText:
                  'Mensaje que recibirán las personas de la institución.',
              alignLabelWithHint: true,
            ),
            validator: (value) =>
                validateAlertText(value, AlertTextRules.message),
          ),
          if (result case AsyncError(:final error)) ...[
            const SizedBox(height: 16),
            StatusMessage(
              tone: StatusTone.error,
              message: describeAlertFailure(error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: sending ? null : _review,
            child: sending
                ? const ButtonProgress(label: 'Emitiendo alerta…')
                : const Text('Revisar y emitir'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: sending
                ? null
                : () =>
                      context.push(AppRoutes.institutionAlerts(institutionId)),
            child: const Text('Ver alertas activas'),
          ),
        ],
      ),
    );
  }
}

class _ConfirmEmitDialog extends StatelessWidget {
  const _ConfirmEmitDialog({
    required this.institutionName,
    required this.type,
    required this.command,
  });

  final String institutionName;
  final EmergencyType type;
  final EmitAlert command;

  @override
  Widget build(BuildContext context) {
    final bold = Theme.of(context).textTheme.titleSmall;
    return AlertDialog(
      title: const Text('¿Emitir esta alerta?'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Institución', style: bold),
            Text(institutionName),
            const SizedBox(height: 8),
            Text('Tipo', style: bold),
            Text(type.label),
            if (command.otherDescription case final description?) ...[
              const SizedBox(height: 8),
              Text('Descripción', style: bold),
              Text(description),
            ],
            const SizedBox(height: 8),
            Text('Instrucciones', style: bold),
            Text(command.message),
            const SizedBox(height: 8),
            Text('Duración', style: bold),
            Text('${type.durationMinutes} min'),
            const SizedBox(height: 16),
            const Text(
              'imSafeAPI registrará la alerta y solicitará su distribución a '
              'las personas de la institución.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Emitir alerta'),
        ),
      ],
    );
  }
}

class _Accepted extends StatelessWidget {
  const _Accepted({
    required this.institutionId,
    required this.institutionName,
    required this.accepted,
  });

  final String institutionId;
  final String institutionName;
  final AlertAccepted accepted;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(institutionName, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        StatusMessage(
          tone: StatusTone.success,
          message:
              'imSafeAPI aceptó y registró la alerta '
              '(${formatAlertTime(context, accepted.acceptedAt)}).\n'
              'La distribución a las personas está pendiente: la aceptación no '
              'confirma que la alerta se haya entregado.',
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.pushReplacement(
            AppRoutes.alertDetail(institutionId, accepted.alertId),
          ),
          child: const Text('Ver estado de la alerta'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('Volver al inicio'),
        ),
      ],
    );
  }
}
