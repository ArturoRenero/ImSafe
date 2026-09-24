import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../shared/widgets/button_progress.dart';
import '../../../shared/widgets/status_message.dart';
import '../../auth/presentation/logout_button.dart';
import '../data/access_dtos.dart';
import '../domain/launcher_access.dart';
import 'launcher_access_controller.dart';

/// Estado de las solicitudes de acceso y envío de nuevas solicitudes.
class AccessScreen extends ConsumerWidget {
  const AccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(launcherAccessProvider);
    final access = state.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso como lanzador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar estado',
            onPressed: state.isLoading
                ? null
                : () => ref.read(launcherAccessProvider.notifier).reload(),
          ),
          const LogoutButton(),
        ],
      ),
      body: SafeArea(
        child: access == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(launcherAccessProvider.notifier).reload(),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (state.isLoading) const LinearProgressIndicator(),
                    if (state.hasError) ...[
                      StatusMessage(
                        tone: StatusTone.error,
                        message:
                            'No se pudo actualizar. Se muestra la última '
                            'información recibida.\n${describeFailure(state.error!)}',
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      access.user.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(access.user.email),
                    const SizedBox(height: 16),
                    if (access.isAuthorizedLauncher) ...[
                      const StatusMessage(
                        tone: StatusTone.success,
                        message:
                            'imSafeAPI confirma que estás autorizado como '
                            'lanzador en al menos una institución.',
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => context.go(AppRoutes.home),
                        child: const Text('Ir al inicio del lanzador'),
                      ),
                    ] else
                      const StatusMessage(
                        tone: StatusTone.info,
                        message:
                            'Todavía no tienes autorización como lanzador. '
                            'La aprobación corresponde a la administración de '
                            'cada institución.',
                      ),
                    const SizedBox(height: 24),
                    _SectionTitle('Mis solicitudes'),
                    if (access.accessRequests.isEmpty)
                      const Text(
                        'Aún no has solicitado acceso a ninguna institución.',
                      )
                    else
                      for (final request in access.accessRequests)
                        _AccessRequestTile(request: request),
                    const SizedBox(height: 24),
                    _SectionTitle('Solicitar acceso a una institución'),
                    _InstitutionSearch(access: access),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// Texto visible para cada valor real de `Permission.status`.
String permissionStatusLabel(PermissionStatus status) => switch (status) {
  PermissionStatus.pending => 'Pendiente de aprobación',
  PermissionStatus.approved => 'Aprobada',
  PermissionStatus.rejected => 'Rechazada',
  PermissionStatus.revoked => 'Revocada',
};

class _AccessRequestTile extends ConsumerWidget {
  const _AccessRequestTile({required this.request});

  final Permission request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institution = ref.watch(institutionProvider(request.institutionId));
    final name = switch (institution) {
      AsyncData(:final value) => value.name,
      AsyncError() => 'Institución ${request.institutionId}',
      _ => 'Cargando institución…',
    };
    final localizations = MaterialLocalizations.of(context);
    final requested = request.requestedAt.toLocal();

    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text(
          '${permissionStatusLabel(request.status)}\n'
          'Solicitada: ${localizations.formatShortDate(requested)} '
          '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(requested))}',
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _InstitutionSearch extends ConsumerStatefulWidget {
  const _InstitutionSearch({required this.access});

  final LauncherAccess access;

  @override
  ConsumerState<_InstitutionSearch> createState() => _InstitutionSearchState();
}

class _InstitutionSearchState extends ConsumerState<_InstitutionSearch> {
  final _query = TextEditingController();
  String? _submittedQuery;
  String? _requestingId;
  String? _requestError;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _request(Institution institution) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Solicitar acceso'),
        content: Text(
          '¿Solicitar acceso como lanzador a "${institution.name}"? '
          'La administración de la institución decidirá si la aprueba.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enviar solicitud'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _requestingId = institution.id;
      _requestError = null;
    });
    try {
      await ref
          .read(launcherAccessProvider.notifier)
          .requestAccess(institution.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('imSafeAPI confirmó la solicitud de acceso.'),
          ),
        );
      }
    } catch (e) {
      final unconfirmed = e is ApiFailure && !e.isConfirmedByServer;
      if (mounted) {
        setState(
          () => _requestError = unconfirmed
              ? '${describeFailure(e)}\nActualiza el estado antes de volver a '
                    'intentarlo: la solicitud pudo haberse registrado.'
              : describeFailure(e),
        );
      }
    } finally {
      if (mounted) setState(() => _requestingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _submittedQuery;
    final results = query == null
        ? null
        : ref.watch(institutionSearchProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Nombre de la institución',
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Buscar',
              onPressed: () => setState(() => _submittedQuery = _query.text),
            ),
          ),
          onSubmitted: (value) => setState(() => _submittedQuery = value),
        ),
        const SizedBox(height: 12),
        if (_requestError case final error?) ...[
          StatusMessage(message: error, tone: StatusTone.error),
          const SizedBox(height: 12),
        ],
        switch (results) {
          null => const SizedBox.shrink(),
          AsyncData(:final value) when value.items.isEmpty => const Text(
            'No se encontraron instituciones.',
          ),
          AsyncData(:final value) => Column(
            children: [
              for (final institution in value.items)
                _InstitutionResult(
                  institution: institution,
                  alreadyRequested: widget.access.hasOpenRequestFor(
                    institution.id,
                  ),
                  requesting: _requestingId == institution.id,
                  enabled: _requestingId == null,
                  onRequest: () => _request(institution),
                ),
            ],
          ),
          AsyncError(:final error) => StatusMessage(
            tone: StatusTone.error,
            message: describeFailure(error),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ],
    );
  }
}

class _InstitutionResult extends StatelessWidget {
  const _InstitutionResult({
    required this.institution,
    required this.alreadyRequested,
    required this.requesting,
    required this.enabled,
    required this.onRequest,
  });

  final Institution institution;
  final bool alreadyRequested;
  final bool requesting;
  final bool enabled;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              institution.name,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (institution.address case final address?) Text(address),
            const SizedBox(height: 8),
            if (alreadyRequested)
              const Text('Ya tienes una solicitud pendiente o aprobada aquí.')
            else
              OutlinedButton(
                onPressed: enabled ? onRequest : null,
                child: requesting
                    ? const ButtonProgress(label: 'Enviando solicitud…')
                    : const Text('Solicitar acceso'),
              ),
          ],
        ),
      ),
    );
  }
}
