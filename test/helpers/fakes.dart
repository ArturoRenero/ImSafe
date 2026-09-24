import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/misc.dart';

import 'package:imsafe_lanzadores/core/api/api_client.dart';
import 'package:imsafe_lanzadores/core/config/app_config.dart';
import 'package:imsafe_lanzadores/core/logging/app_logger.dart';
import 'package:imsafe_lanzadores/core/storage/secure_storage.dart';
import 'package:imsafe_lanzadores/core/storage/token_store.dart';

/// Almacenamiento seguro en memoria.
class FakeSecureStorage implements SecureStorage {
  FakeSecureStorage([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

Map<String, String> storedSession({
  String access = 'access-1',
  String refresh = 'refresh-1',
}) => {
  'imsafe.session.accessToken': access,
  'imsafe.session.refreshToken': refresh,
};

typedef FakeHandler = Future<ResponseBody> Function(RequestOptions options);

/// Backend simulado: responde según "MÉTODO /ruta". Nunca hace red.
class FakeApi implements HttpClientAdapter {
  final Map<String, FakeHandler> routes = {};
  final List<RequestOptions> requests = [];

  void on(String method, String path, FakeHandler handler) =>
      routes['$method $path'] = handler;

  int count(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    final handler = routes['${options.method} ${options.path}'];
    if (handler == null) {
      return Future.value(
        jsonBody({
          'error': {'code': 'NOT_FOUND'},
        }, 404),
      );
    }
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object? body, int status) => ResponseBody.fromString(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Never connectionError(RequestOptions options) => throw DioException(
  requestOptions: options,
  type: DioExceptionType.connectionError,
);

Map<String, Object?> tokensJson(String n) => {
  'accessToken': 'access-$n',
  'refreshToken': 'refresh-$n',
  'tokenType': 'Bearer',
  'expiresIn': 900,
};

Map<String, Object?> userJson() => {
  'id': '507f1f77bcf86cd799439011',
  'name': 'Lanzador Prueba',
  'email': 'lanzador@example.test',
  'createdAt': '2026-09-23T10:00:00.000Z',
};

Map<String, Object?> institutionJson({
  String id = '6ab4876f45cc209961dd09ad',
  String name = 'Institución Prueba',
  bool? launcher,
  bool administrator = false,
}) => {
  '_id': id,
  'name': name,
  'location': {
    'type': 'Point',
    'coordinates': [-103.4, 20.5],
  },
  'createdAt': '2026-09-01T10:00:00.000Z',
  'updatedAt': '2026-09-01T10:00:00.000Z',
  if (launcher != null)
    'capabilities': {'administrator': administrator, 'launcher': launcher},
};

Map<String, Object?> permissionJson({
  String status = 'pending',
  String institutionId = '6ab4876f45cc209961dd09ad',
}) => {
  '_id': '6ab4876f45cc209961dd0a00',
  'institutionId': institutionId,
  'userId': '507f1f77bcf86cd799439011',
  'role': 'launcher',
  'status': status,
  'requestedAt': '2026-09-22T10:00:00.000Z',
  'createdAt': '2026-09-22T10:00:00.000Z',
  'updatedAt': '2026-09-22T10:00:00.000Z',
};

Map<String, Object?> pageJson(List<Object?> items) => {
  'items': items,
  'page': 1,
  'limit': 100,
  'total': items.length,
};

final testConfig = AppConfig(
  environment: AppEnvironment.development,
  apiBaseUrl: Uri.parse('https://api.example.test/api/v1'),
);

/// Overrides que conectan la app con [api] y [storage] sin red real.
List<Override> fakeBackendOverrides({
  required FakeApi api,
  required FakeSecureStorage storage,
}) => [
  appConfigProvider.overrideWithValue(testConfig),
  secureStorageProvider.overrideWithValue(storage),
  dioProvider.overrideWith((ref) {
    final expired = ref.watch(sessionExpiredEventsProvider);
    return createImSafeDio(
      baseUrl: testConfig.apiBaseUrl!,
      tokenStore: ref.watch(tokenStoreProvider),
      logger: AppLogger(AppEnvironment.development, sink: (_, _, _) {}),
      onSessionExpired: () => expired.add(null),
      adapter: api,
    );
  }),
];

TokenStore tokenStoreFor(FakeSecureStorage storage) => TokenStore(storage);
