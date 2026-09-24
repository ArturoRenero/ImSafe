import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/json_read.dart';
import '../domain/alert_command.dart';
import 'alert_dtos.dart';

/// Operaciones de alertas de imSafeAPI usadas por Lanzadores.
///
/// Los comandos (emitir, actualizar, finalizar o cancelar) exigen
/// `Idempotency-Key`. Este repositorio no reintenta: repetir un comando con
/// la misma clave es una decisión explícita del controlador.
class AlertRepository {
  AlertRepository(this._api);

  final ApiClient _api;

  /// `GET /emergency-types`.
  Future<List<EmergencyType>> fetchEmergencyTypes() async {
    final data = await _api.get('/emergency-types');
    return parseJson(data, parseEmergencyTypes);
  }

  /// `GET /institutions/{id}/alerts?state=active`. Solo puede haber una
  /// alerta activa por tipo, así que una página de 100 basta.
  Future<List<InstitutionAlert>> fetchActiveAlerts(String institutionId) async {
    final data = await _api.get(
      '/institutions/$institutionId/alerts',
      queryParameters: {'state': 'active', 'page': 1, 'limit': 100},
    );
    return parseJson(
      data,
      (json) => [
        for (final item in json.requireList('items'))
          if (item is Json)
            InstitutionAlert.fromJson(item)
          else
            throw const FormatException('Alerta inválida en la página'),
      ],
    );
  }

  /// `GET /institutions/{id}/alerts/{alertId}`.
  Future<InstitutionAlert> fetchAlert(
    String institutionId,
    String alertId,
  ) async {
    final data = await _api.get('/institutions/$institutionId/alerts/$alertId');
    return parseJson(data, InstitutionAlert.fromJson);
  }

  /// `GET /institutions/{id}/alerts/{alertId}/delivery-status`.
  Future<AlertDeliveryStatus> fetchDeliveryStatus(
    String institutionId,
    String alertId,
  ) async {
    final data = await _api.get(
      '/institutions/$institutionId/alerts/$alertId/delivery-status',
    );
    return parseJson(data, AlertDeliveryStatus.fromJson);
  }

  /// Envía [command] con [idempotencyKey]. `202 AlertAccepted` significa que
  /// la API aceptó y persistió el comando; la distribución sigue pendiente.
  Future<AlertAccepted> send(
    AlertCommand command,
    String idempotencyKey,
  ) async {
    final headers = {'Idempotency-Key': idempotencyKey};
    final base = '/institutions/${command.institutionId}/alerts';
    final data = switch (command) {
      EmitAlert() => await _api.post(
        base,
        headers: headers,
        data: {
          'type': command.type,
          'message': command.message,
          'otherDescription': ?command.otherDescription,
        },
      ),
      UpdateAlertMessage() => await _api.patch(
        '$base/${command.alertId}',
        headers: headers,
        data: {
          'expectedRevision': command.expectedRevision,
          'message': command.message,
        },
      ),
      TransitionAlert() => await _api.post(
        '$base/${command.alertId}/transitions',
        headers: headers,
        data: {
          'expectedRevision': command.expectedRevision,
          'state': command.target.name,
          'reason': command.reason,
        },
      ),
    };
    return parseJson(data, AlertAccepted.fromJson);
  }
}

final alertRepositoryProvider = Provider<AlertRepository>(
  (ref) => AlertRepository(ref.watch(apiClientProvider)),
);
