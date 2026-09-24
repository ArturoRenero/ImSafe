import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/utils/uuid.dart';
import '../data/alert_dtos.dart';
import '../data/alert_repository.dart';
import '../data/pending_command_store.dart';
import '../domain/alert_command.dart';

/// Envía comandos críticos de alertas (emitir, actualizar, finalizar,
/// cancelar). El estado es `null` antes del primer envío.
///
/// - Ignora un segundo envío mientras el primero está en curso.
/// - Guarda la `Idempotency-Key` en el teléfono antes de enviar y la conserva
///   mientras el resultado no esté confirmado o el servidor haya fallado
///   (5xx), aunque se cierre la pantalla o la app: repetir **el mismo**
///   comando usa la misma clave y la API no lo duplica. Un comando distinto
///   usa clave nueva (AGENTS.md §14).
/// - Nunca reintenta por su cuenta; repetir es una acción del lanzador.
class AlertCommandController extends Notifier<AsyncValue<AlertAccepted>?> {
  AlertCommandController(this.scope);

  /// Pantalla u objeto sobre el que actúa (p. ej. `emit:<institutionId>`).
  final String scope;

  bool _sending = false;

  @override
  AsyncValue<AlertAccepted>? build() => null;

  bool get isSending => _sending;

  /// Devuelve la aceptación de la API, o `null` si falló o ya había un envío
  /// en curso. El error queda en [state].
  Future<AlertAccepted?> send(AlertCommand command) async {
    if (_sending) return null;
    _sending = true;
    state = const AsyncLoading();
    final store = ref.read(pendingCommandStoreProvider);

    try {
      final pending = await store.read(scope);
      final key = pending != null && pending.command == command
          ? pending.key
          : uuidV4();
      await store.write(scope, (command: command, key: key));

      try {
        final accepted = await ref
            .read(alertRepositoryProvider)
            .send(command, key);
        await store.delete(scope);
        state = AsyncData(accepted);
        return accepted;
      } on ApiFailure catch (error) {
        if (_rejectedByApi(error)) await store.delete(scope);
        rethrow;
      }
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    } finally {
      _sending = false;
    }
  }

  /// La API respondió que no aplicó el comando (4xx): corregir y reenviar
  /// es un comando nuevo con clave nueva.
  static bool _rejectedByApi(ApiFailure error) {
    final status = error.statusCode;
    return error.isConfirmedByServer && status != null && status < 500;
  }
}

/// Comando pendiente de confirmar guardado para [scope], si existe.
final pendingAlertCommandProvider = FutureProvider.autoDispose
    .family<AlertCommand?, String>(
      (ref, scope) async =>
          (await ref.read(pendingCommandStoreProvider).read(scope))?.command,
    );

final alertCommandProvider = NotifierProvider.autoDispose
    .family<AlertCommandController, AsyncValue<AlertAccepted>?, String>(
      AlertCommandController.new,
    );
