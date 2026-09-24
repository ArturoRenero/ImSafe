import '../../../core/utils/json_read.dart';

/// Elemento del schema `EmergencyTypes` (`GET /emergency-types`).
///
/// [type] se conserva como texto: el catálogo lo controla imSafeAPI.
class EmergencyType {
  const EmergencyType({
    required this.type,
    required this.label,
    required this.durationMinutes,
    required this.requiresDescription,
  });

  factory EmergencyType.fromJson(Map<String, Object?> json) => EmergencyType(
    type: json.requireString('type'),
    label: json.requireString('label'),
    durationMinutes: json.requireInt('durationMinutes'),
    requiresDescription: json.requireBool('requiresDescription'),
  );

  /// Valor del catálogo que AGENTS.md §8.1 pide ofrecer como predeterminado.
  static const earthquake = 'sismo';

  final String type;
  final String label;

  /// Duración que la API asigna a la alerta (y renueva al actualizarla).
  final int durationMinutes;

  /// Si es `true`, la emisión exige `otherDescription`.
  final bool requiresDescription;
}

/// Schema `EmergencyTypes`.
List<EmergencyType> parseEmergencyTypes(Map<String, Object?> json) {
  final version = json.requireInt('schemaVersion');
  if (version != 1) {
    throw FormatException('EmergencyTypes.schemaVersion desconocido: $version');
  }
  return [
    for (final item in json.requireList('items'))
      if (item is Map<String, Object?>)
        EmergencyType.fromJson(item)
      else
        throw const FormatException('Tipo de emergencia inválido'),
  ];
}

/// Enum `InstitutionAlert.state` de imSafeAPI.
enum AlertState {
  active,
  closed,
  cancelled,
  expired;

  static AlertState parse(String value) =>
      AlertState.values.asNameMap()[value] ??
      (throw FormatException('InstitutionAlert.state desconocido: $value'));
}

/// Schema `InstitutionAlert`: estado actual de una alerta según la API.
class InstitutionAlert {
  const InstitutionAlert({
    required this.id,
    required this.institutionId,
    required this.type,
    required this.otherDescription,
    required this.message,
    required this.state,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    required this.endedAt,
    required this.lastEventId,
  });

  factory InstitutionAlert.fromJson(Map<String, Object?> json) =>
      InstitutionAlert(
        id: json.requireString('id'),
        institutionId: json.requireString('institutionId'),
        type: json.requireString('type'),
        otherDescription: json.optionalString('otherDescription'),
        message: json.requireString('message'),
        state: AlertState.parse(json.requireString('state')),
        revision: json.requireInt('revision'),
        createdAt: json.requireDateTime('createdAt'),
        updatedAt: json.requireDateTime('updatedAt'),
        expiresAt: json.requireDateTime('expiresAt'),
        endedAt: json.optionalDateTime('endedAt'),
        lastEventId: json.requireString('lastEventId'),
      );

  final String id;
  final String institutionId;
  final String type;
  final String? otherDescription;
  final String message;
  final AlertState state;

  /// Se envía como `expectedRevision` al actualizar, finalizar o cancelar.
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final DateTime? endedAt;
  final String lastEventId;
}

/// Schema `AlertAccepted` (respuesta `202`): la API aceptó y persistió el
/// comando; la distribución a los usuarios sigue pendiente.
class AlertAccepted {
  const AlertAccepted({
    required this.alertId,
    required this.eventId,
    required this.acceptedRevision,
    required this.acceptedAt,
  });

  factory AlertAccepted.fromJson(Map<String, Object?> json) => AlertAccepted(
    alertId: json.requireString('alertId'),
    eventId: json.requireString('eventId'),
    acceptedRevision: json.requireInt('acceptedRevision'),
    acceptedAt: json.requireDateTime('acceptedAt'),
  );

  final String alertId;
  final String eventId;
  final int acceptedRevision;
  final DateTime acceptedAt;
}

/// Schema `AlertDeliveryStatus`: distribución del último evento.
///
/// `accepted` es aceptación del proveedor, no entrega; `received`/`opened`
/// son acuses autodeclarados por los dispositivos.
class AlertDeliveryStatus {
  const AlertDeliveryStatus({
    required this.eventId,
    required this.revision,
    required this.outboxState,
    required this.fanoutComplete,
    required this.pending,
    required this.accepted,
    required this.failed,
    required this.skipped,
    required this.received,
    required this.opened,
  });

  factory AlertDeliveryStatus.fromJson(Map<String, Object?> json) {
    final counts = json.requireObject('counts');
    return AlertDeliveryStatus(
      eventId: json.requireString('eventId'),
      revision: json.requireInt('revision'),
      outboxState: json.requireString('outboxState'),
      fanoutComplete: json.requireBool('fanoutComplete'),
      pending: counts.requireInt('pending'),
      accepted: counts.requireInt('accepted'),
      failed: counts.requireInt('failed'),
      skipped: counts.requireInt('skipped'),
      received: counts.requireInt('received'),
      opened: counts.requireInt('opened'),
    );
  }

  final String eventId;
  final int revision;

  /// `pending` | `done` | `superseded` | `expired`.
  final String outboxState;
  final bool fanoutComplete;
  final int pending;
  final int accepted;
  final int failed;
  final int skipped;
  final int received;
  final int opened;
}
