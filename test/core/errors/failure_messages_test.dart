import 'package:flutter_test/flutter_test.dart';

import 'package:imsafe_lanzadores/core/errors/api_failure.dart';
import 'package:imsafe_lanzadores/core/errors/failure_messages.dart';

void main() {
  test('los fallos de red no se describen como falta de autorización', () {
    for (final kind in [ApiFailureKind.connection, ApiFailureKind.timeout]) {
      final message = describeFailure(ApiFailure(kind));
      expect(message, isNot(contains('autoriz')));
      expect(message, contains('imSafeAPI'));
    }
  });

  test('timeout se reporta como resultado no confirmado', () {
    expect(
      describeFailure(const ApiFailure(ApiFailureKind.timeout)),
      contains('No se pudo confirmar'),
    );
  });

  test('401 depende del contexto', () {
    const failure = ApiFailure(ApiFailureKind.badResponse, statusCode: 401);
    expect(
      describeFailure(failure, context: FailureContext.login),
      'Correo o contraseña incorrectos.',
    );
    expect(describeFailure(failure), contains('sesión'));
  });

  test('incluye el requestId del servidor como referencia', () {
    const failure = ApiFailure(
      ApiFailureKind.badResponse,
      statusCode: 500,
      requestId: 'req-123',
    );
    expect(describeFailure(failure), contains('req-123'));
  });
}
