import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/utils/uuid.dart';
import '../data/alert_dtos.dart';
import '../data/alert_repository.dart';
import '../domain/alert_command.dart';

/// Envía comandos críticos de alertas (emitir, actualizar, finalizar,
/// cancelar). El estado es `null` antes del primer envío.
///
/// - Ignora un segundo envío mientras el primero está en curso.
/// - Conserva la `Idempotency-Key` mientras el resultado no esté confirmado
///   o el servidor haya fallado (5xx): repetir **el mismo** comando usa la
///   misma clave y la API no lo duplica. Un comando distinto usa clave nueva.
/// - Nunca reintenta por su cuenta; repetir es una acción del lanzador.
class AlertCommandController extends Notifier<AsyncValue<AlertAccepted>?> {
  AlertCommandController(this.scope);

  /// Pantalla u objeto sobre el que actúa (p. ej. `emit:<institutionId>`).
  final String scope;

  ({AlertCommand command, String key})? _pending;

  @override
  AsyncValue<AlertAccepted>? build() => null;

  bool get isSending => state?.isLoading ?? false;

  /// Devuelve la aceptación de la API, o `null` si falló o ya había un envío
  /// en curso. El error queda en [state].
  Future<AlertAccepted?> send(AlertCommand command) async {
    if (isSending) return null;
    final pending = _pending;
    final key = pending != null && pending.command == command
        ? pending.key
        : uuidV4();
    _pending = (command: command, key: key);
    state = const AsyncLoading();

    try {
      final accepted = await ref
          .read(alertRepositoryProvider)
          .send(command, key);
      _pending = null;
      state = AsyncData(accepted);
      return accepted;
    } catch (error, stackTrace) {
      if (error is ApiFailure && _rejectedByApi(error)) _pending = null;
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  /// La API respondió que no aplicó el comando (4xx): corregir y reenviar
  /// es un comando nuevo con clave nueva.
  static bool _rejectedByApi(ApiFailure error) {
    final status = error.statusCode;
    return error.isConfirmedByServer && status != null && status < 500;
  }
}

final alertCommandProvider = NotifierProvider.autoDispose
    .family<AlertCommandController, AsyncValue<AlertAccepted>?, String>(
      AlertCommandController.new,
    );
