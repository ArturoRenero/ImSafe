import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imsafe_lanzadores/core/api/api_client.dart';
import 'package:imsafe_lanzadores/core/config/app_config.dart';
import 'package:imsafe_lanzadores/core/errors/api_failure.dart';

/// Adaptador HTTP falso: no hace red, devuelve lo que indique [handler].
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, int status) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

(ApiClient, _FakeAdapter) _client(
  Future<ResponseBody> Function(RequestOptions) handler,
) {
  final adapter = _FakeAdapter(handler);
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
    ..httpClientAdapter = adapter;
  return (ApiClient(dio), adapter);
}

Matcher _failure(ApiFailureKind kind, {int? statusCode}) => isA<ApiFailure>()
    .having((f) => f.kind, 'kind', kind)
    .having((f) => f.statusCode, 'statusCode', statusCode);

void main() {
  group('ApiClient', () {
    test('devuelve el JSON decodificado en una respuesta exitosa', () async {
      final (client, _) = _client((_) async => _json('{"ok": true}', 200));

      expect(await client.get('/cualquier-ruta'), {'ok': true});
    });

    test('traduce un código HTTP de error a badResponse', () async {
      final (client, _) = _client((_) async => _json('{}', 503));

      await expectLater(
        client.post('/x'),
        throwsA(_failure(ApiFailureKind.badResponse, statusCode: 503)),
      );
    });

    test('conserva error.code y requestId del formato de imSafeAPI', () async {
      final (client, _) = _client(
        (_) async => _json(
          '{"error":{"code":"CONFLICT","message":"x","requestId":"r-1"}}',
          409,
        ),
      );

      await expectLater(
        client.post('/x'),
        throwsA(
          isA<ApiFailure>()
              .having((f) => f.errorCode, 'errorCode', 'CONFLICT')
              .having((f) => f.requestId, 'requestId', 'r-1'),
        ),
      );
    });

    test('traduce errores de conexión y timeouts', () async {
      for (final (type, kind) in [
        (DioExceptionType.connectionError, ApiFailureKind.connection),
        (DioExceptionType.connectionTimeout, ApiFailureKind.timeout),
        (DioExceptionType.receiveTimeout, ApiFailureKind.timeout),
      ]) {
        final (client, _) = _client(
          (options) async =>
              throw DioException(requestOptions: options, type: type),
        );
        await expectLater(client.get('/x'), throwsA(_failure(kind)));
      }
    });

    test('traduce una respuesta que no es JSON válido', () async {
      final (client, _) = _client((_) async => _json('no-json', 200));

      await expectLater(
        client.get('/x'),
        throwsA(_failure(ApiFailureKind.invalidResponse)),
      );
    });

    test('no reintenta automáticamente una operación fallida', () async {
      final (client, adapter) = _client(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
      );

      await expectLater(client.post('/x'), throwsA(isA<ApiFailure>()));
      expect(adapter.calls, 1);
    });
  });

  group('ApiFailure.isConfirmedByServer', () {
    test('solo una respuesta explícita del servidor es confirmación', () {
      for (final kind in ApiFailureKind.values) {
        expect(
          ApiFailure(kind).isConfirmedByServer,
          kind == ApiFailureKind.badResponse,
          reason: kind.name,
        );
      }
    });
  });

  group('providers', () {
    test('dioProvider falla de forma explícita sin URL configurada', () {
      final container = ProviderContainer.test(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.development,
              apiBaseUrl: null,
            ),
          ),
        ],
      );

      expect(() => container.read(dioProvider), throwsA(anything));
    });

    test('dioProvider usa la URL y timeouts centralizados', () {
      final container = ProviderContainer.test(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig(
              environment: AppEnvironment.staging,
              apiBaseUrl: Uri.parse('https://api.example.test'),
            ),
          ),
        ],
      );

      final options = container.read(dioProvider).options;
      expect(options.baseUrl, 'https://api.example.test');
      expect(options.connectTimeout, isNotNull);
      expect(options.receiveTimeout, isNotNull);
      expect(container.read(apiClientProvider), isA<ApiClient>());
    });
  });
}
