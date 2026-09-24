import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imsafe_lanzadores/core/api/api_client.dart';
import 'package:imsafe_lanzadores/core/config/app_config.dart';
import 'package:imsafe_lanzadores/core/errors/api_failure.dart';
import 'package:imsafe_lanzadores/core/logging/app_logger.dart';
import 'package:imsafe_lanzadores/core/storage/token_store.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeApi api;
  late FakeSecureStorage storage;
  late TokenStore tokens;
  late ApiClient client;
  late int expiredEvents;

  void setUpClient(Map<String, String> stored) {
    api = FakeApi();
    storage = FakeSecureStorage(stored);
    tokens = TokenStore(storage);
    expiredEvents = 0;
    client = ApiClient(
      createImSafeDio(
        baseUrl: Uri.parse('https://api.example.test/api/v1'),
        tokenStore: tokens,
        logger: AppLogger(AppEnvironment.development, sink: (_, _, _) {}),
        onSessionExpired: () => expiredEvents++,
        adapter: api,
      ),
    );
  }

  String? authHeader(RequestOptions r) => r.headers['Authorization'] as String?;

  /// `/users/me` acepta solo `access-2`.
  void meRequiresRenewedToken() => api.on('GET', '/users/me', (o) async {
    return authHeader(o) == 'Bearer access-2'
        ? jsonBody(userJson(), 200)
        : jsonBody({
            'error': {'code': 'UNAUTHORIZED'},
          }, 401);
  });

  test('envía Bearer solo en operaciones protegidas', () async {
    setUpClient(storedSession());
    api.on('GET', '/users/me', (_) async => jsonBody(userJson(), 200));
    api.on('GET', '/institutions', (_) async => jsonBody(pageJson([]), 200));

    await client.get('/users/me');
    await client.get('/institutions', authenticated: false);

    expect(authHeader(api.requests[0]), 'Bearer access-1');
    expect(authHeader(api.requests[1]), isNull);
  });

  test('ante 401 renueva la sesión y repite una vez', () async {
    setUpClient(storedSession());
    meRequiresRenewedToken();
    api.on('POST', '/auth/refresh', (o) async {
      expect(o.data, {'refreshToken': 'refresh-1'});
      expect(authHeader(o), isNull);
      return jsonBody(tokensJson('2'), 200);
    });

    expect(await client.get('/users/me'), userJson());
    expect(api.count('POST', '/auth/refresh'), 1);
    expect(api.count('GET', '/users/me'), 2);
    final saved = await tokens.read();
    expect(saved?.accessToken, 'access-2');
    expect(saved?.refreshToken, 'refresh-2');
    expect(storage.values['imsafe.session.refreshToken'], 'refresh-2');
  });

  test(
    '401 concurrentes usan una sola renovación (token de uso único)',
    () async {
      setUpClient(storedSession());
      meRequiresRenewedToken();
      final release = Completer<void>();
      api.on('POST', '/auth/refresh', (_) async {
        await release.future;
        return jsonBody(tokensJson('2'), 200);
      });

      final calls = [client.get('/users/me'), client.get('/users/me')];
      await Future<void>.delayed(Duration.zero);
      release.complete();
      await Future.wait(calls);

      expect(api.count('POST', '/auth/refresh'), 1);
    },
  );

  test(
    'renovación rechazada: borra tokens y notifica sesión expirada',
    () async {
      setUpClient(storedSession());
      meRequiresRenewedToken();
      api.on(
        'POST',
        '/auth/refresh',
        (_) async => jsonBody({
          'error': {'code': 'UNAUTHORIZED'},
        }, 401),
      );

      await expectLater(
        client.get('/users/me'),
        throwsA(isA<ApiFailure>().having((f) => f.statusCode, 'status', 401)),
      );
      expect(await tokens.read(), isNull);
      expect(storage.values, isEmpty);
      expect(expiredEvents, 1);
    },
  );

  test(
    'renovación sin red: conserva la sesión y reporta error de red',
    () async {
      setUpClient(storedSession());
      meRequiresRenewedToken();
      api.on('POST', '/auth/refresh', connectionError);

      await expectLater(
        client.get('/users/me'),
        throwsA(
          isA<ApiFailure>().having(
            (f) => f.kind,
            'kind',
            ApiFailureKind.connection,
          ),
        ),
      );
      expect((await tokens.read())?.refreshToken, 'refresh-1');
      expect(expiredEvents, 0);
    },
  );

  test('no entra en bucle si la solicitud repetida vuelve a dar 401', () async {
    setUpClient(storedSession());
    api.on(
      'GET',
      '/users/me',
      (_) async => jsonBody({
        'error': {'code': 'UNAUTHORIZED'},
      }, 401),
    );
    api.on(
      'POST',
      '/auth/refresh',
      (_) async => jsonBody(tokensJson('2'), 200),
    );

    await expectLater(client.get('/users/me'), throwsA(isA<ApiFailure>()));
    expect(api.count('POST', '/auth/refresh'), 1);
    expect(api.count('GET', '/users/me'), 2);
  });

  test('un 401 del login no intenta renovar la sesión', () async {
    setUpClient({});
    api.on(
      'POST',
      '/auth/login',
      (_) async => jsonBody({
        'error': {'code': 'UNAUTHORIZED'},
      }, 401),
    );

    await expectLater(
      client.post('/auth/login', data: {}, authenticated: false),
      throwsA(isA<ApiFailure>()),
    );
    expect(api.count('POST', '/auth/refresh'), 0);
  });
}
