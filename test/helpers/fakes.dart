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

Never timeoutError(RequestOptions options) => throw DioException(
  requestOptions: options,
  type: DioExceptionType.receiveTimeout,
);

ResponseBody apiError(int status, String code) => jsonBody({
  'error': {'code': code, 'message': code, 'requestId': 'req-1'},
}, status);

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
  String id = 'dddddddddddddddddddd09ad',
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
  String institutionId = 'dddddddddddddddddddd09ad',
}) => {
  '_id': 'dddddddddddddddddddd0a00',
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

/// Ejemplo de `EmergencyTypes` publicado en OpenAPI.
Map<String, Object?> emergencyTypesJson() => {
  'schemaVersion': 1,
  'items': [
    {
      'type': 'sismo',
      'label': 'Sismo',
      'durationMinutes': 30,
      'requiresDescription': false,
    },
    {
      'type': 'incendio',
      'label': 'Incendio',
      'durationMinutes': 120,
      'requiresDescription': false,
    },
    {
      'type': 'otro',
      'label': 'Otro',
      'durationMinutes': 60,
      'requiresDescription': true,
    },
  ],
};

Map<String, Object?> alertJson({
  String id = 'dddddddddddddddddddd0a01',
  String institutionId = 'dddddddddddddddddddd09ad',
  String type = 'sismo',
  String state = 'active',
  int revision = 1,
  String message = 'Sigan las indicaciones del personal.',
}) => {
  'id': id,
  'institutionId': institutionId,
  'type': type,
  'otherDescription': null,
  'message': message,
  'state': state,
  'revision': revision,
  'createdAt': '2026-09-24T12:00:00.000Z',
  'updatedAt': '2026-09-24T12:00:00.000Z',
  'expiresAt': '2026-09-24T12:30:00.000Z',
  'endedAt': null,
  'lastEventId': 'dddddddddddddddddddd0b01',
};

Map<String, Object?> alertPageJson(List<Object?> items) => {
  ...pageJson(items),
  'serverTime': '2026-09-24T12:05:00.000Z',
};

Map<String, Object?> acceptedJson({
  String alertId = 'dddddddddddddddddddd0a01',
  int revision = 1,
}) => {
  'alertId': alertId,
  'eventId': 'dddddddddddddddddddd0b02',
  'acceptedRevision': revision,
  'acceptedAt': '2026-09-24T12:00:00.000Z',
};

Map<String, Object?> deliveryJson() => {
  'alertId': 'dddddddddddddddddddd0a01',
  'eventId': 'dddddddddddddddddddd0b01',
  'revision': 1,
  'outboxState': 'pending',
  'fanoutComplete': false,
  'counts': {
    'pending': 0,
    'accepted': 0,
    'failed': 0,
    'skipped': 0,
    'received': 0,
    'opened': 0,
  },
};
