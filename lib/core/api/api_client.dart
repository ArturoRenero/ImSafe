import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../errors/api_failure.dart';
import '../logging/app_logger.dart';
import '../storage/token_store.dart';
import 'auth_interceptor.dart';

typedef Json = Map<String, Object?>;

/// Único punto de acceso HTTP a imSafeAPI.
///
/// Los repositorios de cada feature dependen de [ApiClient]; ninguna feature
/// crea su propia instancia de Dio y la UI no hace llamadas HTTP.
///
/// `authenticated: false` corresponde a operaciones con `security: []` en
/// OpenAPI. `headers` se usa para cabeceras de contrato como `Idempotency-Key`. No incluye reintentos automáticos (salvo repetir una vez una
/// solicitud rechazada con 401 tras renovar la sesión, ver [AuthInterceptor]).
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<Object?> get(
    String path, {
    Map<String, Object?>? queryParameters,
    bool authenticated = true,
  }) => _send(
    () => _dio.get<Object?>(
      path,
      queryParameters: queryParameters,
      options: _options(authenticated),
    ),
  );

  Future<Object?> post(
    String path, {
    Object? data,
    bool authenticated = true,
    Map<String, Object?>? headers,
  }) => _send(
    () => _dio.post<Object?>(
      path,
      data: data,
      options: _options(authenticated, headers),
    ),
  );

  Future<Object?> put(String path, {Object? data, bool authenticated = true}) =>
      _send(
        () => _dio.put<Object?>(
          path,
          data: data,
          options: _options(authenticated),
        ),
      );

  Future<Object?> patch(
    String path, {
    Object? data,
    bool authenticated = true,
    Map<String, Object?>? headers,
  }) => _send(
    () => _dio.patch<Object?>(
      path,
      data: data,
      options: _options(authenticated, headers),
    ),
  );

  Future<Object?> delete(
    String path, {
    Object? data,
    bool authenticated = true,
  }) => _send(
    () => _dio.delete<Object?>(
      path,
      data: data,
      options: _options(authenticated),
    ),
  );

  Options _options(bool authenticated, [Map<String, Object?>? headers]) =>
      Options(extra: {AuthExtra.skipAuth: !authenticated}, headers: headers);

  Future<Object?> _send(Future<Response<Object?>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      throw ApiFailure.fromDioException(e);
    }
  }
}

/// Convierte una respuesta JSON en un DTO. Cualquier discrepancia con el
/// schema de OpenAPI se reporta como [ApiFailureKind.invalidResponse].
T parseJson<T>(Object? data, T Function(Json json) fromJson) {
  try {
    if (data is! Map<String, Object?>) {
      throw const FormatException('Se esperaba un objeto JSON');
    }
    return fromJson(data);
  } on FormatException {
    throw const ApiFailure(ApiFailureKind.invalidResponse);
  } on TypeError {
    throw const ApiFailure(ApiFailureKind.invalidResponse);
  }
}

/// Registra método, ruta, resultado y duración. Nunca headers, query ni
/// cuerpos, porque pueden contener tokens o datos personales.
class ApiLogInterceptor extends Interceptor {
  ApiLogInterceptor(this._logger);

  final AppLogger _logger;
  final _startTimes = <RequestOptions, Stopwatch>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _startTimes[options] = Stopwatch()..start();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logResult(response.requestOptions, '${response.statusCode}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logResult(
      err.requestOptions,
      err.response?.statusCode?.toString() ?? err.type.name,
    );
    handler.next(err);
  }

  void _logResult(RequestOptions options, String result) {
    final elapsed = _startTimes.remove(options)?.elapsedMilliseconds;
    _logger.debug(
      'HTTP ${options.method} ${options.uri.path} -> $result (${elapsed}ms)',
    );
  }
}

/// Emite un evento cuando imSafeAPI rechaza la renovación de la sesión.
final sessionExpiredEventsProvider = Provider<StreamController<void>>((ref) {
  final controller = StreamController<void>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});

/// Construye el Dio de imSafeAPI con su configuración e interceptores.
/// [adapter] solo se usa en pruebas para evitar la red.
Dio createImSafeDio({
  required Uri baseUrl,
  required TokenStore tokenStore,
  required AppLogger logger,
  required void Function() onSessionExpired,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl.toString(),
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      contentType: Headers.jsonContentType,
      headers: {Headers.acceptHeader: Headers.jsonContentType},
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  dio.interceptors.addAll([
    AuthInterceptor(
      dio: dio,
      tokenStore: tokenStore,
      onSessionExpired: onSessionExpired,
    ),
    ApiLogInterceptor(logger),
  ]);
  return dio;
}

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final baseUrl = config.apiBaseUrl;
  if (baseUrl == null) {
    throw StateError(
      'IMSAFE_API_BASE_URL no está configurada para ${config.environment.name}',
    );
  }
  final sessionExpired = ref.watch(sessionExpiredEventsProvider);
  final dio = createImSafeDio(
    baseUrl: baseUrl,
    tokenStore: ref.watch(tokenStoreProvider),
    logger: ref.watch(appLoggerProvider),
    onSessionExpired: () => sessionExpired.add(null),
  );
  ref.onDispose(dio.close);
  return dio;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(dioProvider)),
);
