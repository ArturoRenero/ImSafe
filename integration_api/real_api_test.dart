// Pruebas contra imSafeAPI REAL. Fuera de `test/` para que `flutter test`
// nunca dependa de producción. Solo usan operaciones sin efectos críticos
// (login, lecturas propias, refresh, logout). NUNCA crean alertas ni
// solicitudes de acceso.
//
// Ejecutar (las credenciales no se guardan en el repositorio):
//   flutter test integration_api \
//     --dart-define=IMSAFE_API_BASE_URL=https://api.imsafe.tlajomulco.tecnm.mx/api/v1 \
//     --dart-define=IMSAFE_TEST_EMAIL=... --dart-define=IMSAFE_TEST_PASSWORD=...
@Tags(['real-api'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imsafe_lanzadores/core/api/api_client.dart';
import 'package:imsafe_lanzadores/core/config/app_config.dart';
import 'package:imsafe_lanzadores/core/errors/api_failure.dart';
import 'package:imsafe_lanzadores/core/logging/app_logger.dart';
import 'package:imsafe_lanzadores/core/storage/token_store.dart';
import 'package:imsafe_lanzadores/features/access/data/access_repository.dart';
import 'package:imsafe_lanzadores/features/auth/data/auth_repository.dart';

import '../test/helpers/fakes.dart';

const _baseUrl = String.fromEnvironment('IMSAFE_API_BASE_URL');
const _email = String.fromEnvironment('IMSAFE_TEST_EMAIL');
const _password = String.fromEnvironment('IMSAFE_TEST_PASSWORD');

void main() {
  final skip = _baseUrl.isEmpty || _email.isEmpty || _password.isEmpty
      ? 'Faltan IMSAFE_API_BASE_URL / IMSAFE_TEST_EMAIL / IMSAFE_TEST_PASSWORD'
      : null;

  late FakeSecureStorage storage;
  late AuthRepository auth;
  late AccessRepository access;
  var expired = 0;

  setUp(() {
    storage = FakeSecureStorage();
    final tokens = TokenStore(storage);
    final api = ApiClient(
      createImSafeDio(
        baseUrl: AppConfig.parse(
          environment: 'production',
          apiBaseUrl: _baseUrl,
        ).apiBaseUrl!,
        tokenStore: tokens,
        logger: AppLogger(AppEnvironment.production, sink: (_, _, _) {}),
        onSessionExpired: () => expired++,
      ),
    );
    auth = AuthRepository(api, tokens);
    access = AccessRepository(api);
  });

  test('login incorrecto → 401', () async {
    await expectLater(
      auth.login(email: _email, password: 'contraseña-incorrecta-123'),
      throwsA(isA<ApiFailure>().having((f) => f.statusCode, 'status', 401)),
    );
  }, skip: skip);

  test('login, estado real del lanzador y logout', () async {
    await auth.login(email: _email, password: _password);
    expect(storage.values, hasLength(2));

    final me = await auth.fetchMe();
    expect(me.email, _email);
    await access.fetchMyInstitutions();
    await access.fetchMyAccessRequests();
    final search = await access.searchInstitutions('');
    expect(search.total, greaterThanOrEqualTo(0));

    await auth.logout();
    expect(storage.values, isEmpty);
    expect(expired, 0);
  }, skip: skip);
}
