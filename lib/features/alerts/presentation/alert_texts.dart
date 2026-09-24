import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../data/alert_dtos.dart';

/// Límites de `AlertCreate`/`AlertUpdate`/`AlertTransition` en OpenAPI:
/// caracteres tras recortar extremos y bytes UTF-8 del texto escapado en JSON.
typedef AlertTextRule = ({int maxLength, int maxBytes});

abstract final class AlertTextRules {
  static const AlertTextRule message = (maxLength: 1000, maxBytes: 1800);
  static const AlertTextRule otherDescription = (maxLength: 160, maxBytes: 480);
  static const AlertTextRule reason = (maxLength: 500, maxBytes: 1000);
}

/// Validación local previa; la API vuelve a validar (400).
String? validateAlertText(String? value, AlertTextRule rule) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Campo obligatorio.';
  if (text.length > rule.maxLength) {
    return 'Máximo ${rule.maxLength} caracteres.';
  }
  final bytes = utf8.encode(jsonEncode(text)).length - 2;
  if (bytes > rule.maxBytes) return 'El texto es demasiado largo.';
  return null;
}

/// Mensaje para un fallo de un comando o consulta de alertas. Usa los
/// `error.code` que OpenAPI documenta para estas operaciones.
String describeAlertFailure(Object error) {
  if (error is! ApiFailure) return describeFailure(error);
  if (!error.isConfirmedByServer) {
    return '${describeFailure(error)}\nNo se pudo confirmar si imSafeAPI '
        'registró la operación. Consulta el estado de las alertas antes de '
        'continuar; repetir la misma operación no la duplica.';
  }
  final message = switch ((error.statusCode, error.errorCode)) {
    (403, _) =>
      'No tienes autorización para operar alertas en esta institución.',
    (409, 'ACTIVE_ALERT_EXISTS') =>
      'Ya existe una alerta activa de este tipo en la institución.',
    (409, 'REVISION_CONFLICT') =>
      'La alerta cambió desde que la consultaste. Actualiza su estado y vuelve '
          'a intentarlo.',
    (409, 'INVALID_TRANSITION') => 'La alerta ya no está activa.',
    (409, 'ALERT_EXPIRED') => 'La alerta ya expiró.',
    (409, 'IDEMPOTENCY_CONFLICT') =>
      'La solicitud no coincide con un envío anterior. Vuelve a intentarlo.',
    (400, 'NOTIFICATION_TOO_LARGE') =>
      'El texto es demasiado largo para la notificación. Acórtalo.',
    _ => null,
  };
  if (message == null) return describeFailure(error);
  final requestId = error.requestId;
  return requestId == null ? message : '$message\n(Referencia: $requestId)';
}

String alertStateLabel(AlertState state) => switch (state) {
  AlertState.active => 'Activa',
  AlertState.closed => 'Finalizada',
  AlertState.cancelled => 'Cancelada',
  AlertState.expired => 'Expirada',
};

/// Etiqueta del catálogo de la API; el valor crudo si aún no se cargó.
String emergencyTypeLabel(List<EmergencyType>? catalog, String type) =>
    catalog?.where((t) => t.type == type).firstOrNull?.label ?? type;

String formatAlertTime(BuildContext context, DateTime time) {
  final localizations = MaterialLocalizations.of(context);
  final local = time.toLocal();
  return '${localizations.formatShortDate(local)} '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
