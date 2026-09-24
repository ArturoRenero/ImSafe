import 'api_failure.dart';

/// Contexto de la operación, para dar un mensaje preciso a cada status.
enum FailureContext { login, register, general }

/// Mensaje comprensible para la UI. Los fallos de red nunca se presentan
/// como falta de autorización ni como ausencia de datos.
String describeFailure(
  Object error, {
  FailureContext context = FailureContext.general,
}) {
  if (error is! ApiFailure) {
    return 'Ocurrió un error inesperado en la app.';
  }
  final message = switch (error.kind) {
    ApiFailureKind.connection =>
      'No hay conexión con imSafeAPI. Revisa tu conexión a Internet.',
    ApiFailureKind.timeout =>
      'imSafeAPI no respondió a tiempo. No se pudo confirmar el resultado.',
    ApiFailureKind.cancelled => 'La solicitud fue cancelada.',
    ApiFailureKind.invalidResponse =>
      'imSafeAPI envió una respuesta que la app no reconoce.',
    ApiFailureKind.unknown => 'No se pudo completar la solicitud.',
    ApiFailureKind.badResponse => _describeStatus(error.statusCode, context),
  };
  final requestId = error.requestId;
  return requestId == null ? message : '$message\n(Referencia: $requestId)';
}

String _describeStatus(int? status, FailureContext context) =>
    switch ((status, context)) {
      (401, FailureContext.login) => 'Correo o contraseña incorrectos.',
      (401, _) => 'Tu sesión no es válida. Inicia sesión de nuevo.',
      (409, FailureContext.register) => 'Ya existe una cuenta con ese correo.',
      (409, _) => 'La operación no es compatible con el estado actual.',
      (400, _) => 'Los datos enviados no son válidos.',
      (403, _) => 'No tienes autorización para esta operación.',
      (404, _) => 'El recurso no existe.',
      (429, _) => 'Demasiados intentos. Espera un momento y vuelve a intentar.',
      (final code?, _) when code >= 500 =>
        'imSafeAPI tuvo un error interno. Intenta más tarde.',
      _ => 'imSafeAPI rechazó la solicitud (código $status).',
    };
