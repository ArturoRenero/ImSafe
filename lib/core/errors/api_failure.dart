import 'package:dio/dio.dart';

enum ApiFailureKind {
  /// No se pudo establecer la conexión con imSafeAPI.
  connection,

  /// Se agotó el tiempo de espera; la solicitud pudo o no haberse procesado.
  timeout,

  /// La solicitud fue cancelada desde la app.
  cancelled,

  /// imSafeAPI respondió con un código HTTP de error.
  badResponse,

  /// La respuesta no pudo interpretarse.
  invalidResponse,

  unknown,
}

/// Error de comunicación con imSafeAPI traducido a un tipo propio de la app.
///
/// El formato de error de imSafeAPI es
/// `{ "error": { "code", "message", "requestId" } }`. `code` no está
/// enumerado en OpenAPI, así que la app decide por [statusCode]; [errorCode]
/// y [requestId] se conservan solo para diagnóstico.
class ApiFailure implements Exception {
  const ApiFailure(
    this.kind, {
    this.statusCode,
    this.errorCode,
    this.requestId,
  });

  factory ApiFailure.fromDioException(DioException exception) {
    return switch (exception.type) {
      DioExceptionType.connectionError || DioExceptionType.badCertificate =>
        const ApiFailure(ApiFailureKind.connection),
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const ApiFailure(
        ApiFailureKind.timeout,
      ),
      DioExceptionType.cancel => const ApiFailure(ApiFailureKind.cancelled),
      DioExceptionType.transformTimeout => const ApiFailure(
        ApiFailureKind.invalidResponse,
      ),
      DioExceptionType.badResponse => _fromResponse(exception.response),
      DioExceptionType.unknown =>
        exception.error is FormatException
            ? const ApiFailure(ApiFailureKind.invalidResponse)
            : const ApiFailure(ApiFailureKind.unknown),
    };
  }

  static ApiFailure _fromResponse(Response<dynamic>? response) {
    final body = response?.data;
    final error = body is Map ? body['error'] : null;
    return ApiFailure(
      ApiFailureKind.badResponse,
      statusCode: response?.statusCode,
      errorCode: error is Map && error['code'] is String
          ? error['code'] as String
          : null,
      requestId: error is Map && error['requestId'] is String
          ? error['requestId'] as String
          : null,
    );
  }

  final ApiFailureKind kind;
  final int? statusCode;
  final String? errorCode;
  final String? requestId;

  /// `true` solo cuando imSafeAPI respondió explícitamente con un error.
  ///
  /// En cualquier otro caso el resultado de una operación crítica (emitir,
  /// actualizar o finalizar una alerta) es DESCONOCIDO: pudo haberse aplicado
  /// en el backend. No debe mostrarse como fallo definitivo ni reintentarse
  /// automáticamente sin una estrategia de idempotencia aprobada.
  bool get isConfirmedByServer => kind == ApiFailureKind.badResponse;

  /// Fallo de red o de tiempo: nunca debe interpretarse como falta de
  /// autorización ni como ausencia de datos.
  bool get isConnectivityProblem =>
      kind == ApiFailureKind.connection || kind == ApiFailureKind.timeout;

  @override
  String toString() =>
      'ApiFailure(${kind.name}${statusCode == null ? '' : ', $statusCode'}'
      '${errorCode == null ? '' : ', $errorCode'})';
}
