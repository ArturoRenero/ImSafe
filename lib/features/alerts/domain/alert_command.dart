/// Comando crítico sobre alertas. Cada envío lleva una `Idempotency-Key`;
/// solo se reutiliza para repetir exactamente el mismo comando (misma
/// operación y mismo cuerpo), como exige imSafeAPI.
sealed class AlertCommand {
  const AlertCommand(this.institutionId);

  final String institutionId;

  Object get _fields;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is AlertCommand &&
      other._fields == _fields;

  @override
  int get hashCode => Object.hash(runtimeType, _fields);
}

/// `POST /institutions/{institutionId}/alerts` (`AlertCreate`).
class EmitAlert extends AlertCommand {
  const EmitAlert({
    required String institutionId,
    required this.type,
    required this.message,
    this.otherDescription,
  }) : super(institutionId);

  final String type;
  final String message;

  /// Solo para tipos con `requiresDescription`.
  final String? otherDescription;

  @override
  Object get _fields => (institutionId, type, message, otherDescription);
}

/// `PATCH /institutions/{institutionId}/alerts/{alertId}` (`AlertUpdate`).
class UpdateAlertMessage extends AlertCommand {
  const UpdateAlertMessage({
    required String institutionId,
    required this.alertId,
    required this.expectedRevision,
    required this.message,
  }) : super(institutionId);

  final String alertId;
  final int expectedRevision;
  final String message;

  @override
  Object get _fields => (institutionId, alertId, expectedRevision, message);
}

/// Estados terminales que acepta `AlertTransition.state`.
enum AlertTransitionTarget { closed, cancelled }

/// `POST /institutions/{institutionId}/alerts/{alertId}/transitions`.
class TransitionAlert extends AlertCommand {
  const TransitionAlert({
    required String institutionId,
    required this.alertId,
    required this.expectedRevision,
    required this.target,
    required this.reason,
  }) : super(institutionId);

  final String alertId;
  final int expectedRevision;
  final AlertTransitionTarget target;
  final String reason;

  @override
  Object get _fields =>
      (institutionId, alertId, expectedRevision, target, reason);
}
