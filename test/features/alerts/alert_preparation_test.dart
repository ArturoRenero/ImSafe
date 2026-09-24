import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imsafe_lanzadores/app/app.dart';
import 'package:imsafe_lanzadores/core/errors/api_failure.dart';
import 'package:imsafe_lanzadores/features/alerts/domain/alert_api_feature.dart';
import 'package:imsafe_lanzadores/features/alerts/domain/alert_preparation.dart';
import 'package:imsafe_lanzadores/features/alerts/presentation/alert_preparation_controller.dart';

import '../../helpers/fakes.dart';

const _launcherId = '6ab4876f45cc209961dd0001';
const _adminId = '6ab4876f45cc209961dd0002';

/// Solo las rutas que existen en imSafeAPI v0.3.0 y usa esta feature.
const _knownPaths = {
  '/users/me',
  '/users/me/institutions',
  '/users/me/access-requests',
};

void main() {
  late FakeApi api;
  late ProviderContainer container;

  setUp(() {
    api = FakeApi()
      ..on('GET', '/users/me', (_) async => jsonBody(userJson(), 200))
      ..on(
        'GET',
        '/users/me/institutions',
        (_) async => jsonBody(
          pageJson([
            institutionJson(id: _launcherId, name: 'A', launcher: true),
            institutionJson(
              id: _adminId,
              name: 'B',
              launcher: false,
              administrator: true,
            ),
          ]),
          200,
        ),
      )
      ..on(
        'GET',
        '/users/me/access-requests',
        (_) async => jsonBody(pageJson([]), 200),
      );
    container = ProviderContainer(
      retry: noAutomaticRetry,
      overrides: fakeBackendOverrides(
        api: api,
        storage: FakeSecureStorage(storedSession()),
      ),
    );
    addTearDown(container.dispose);
  });

  Future<AlertPreparation> prepare(String institutionId) {
    final provider = alertPreparationProvider(institutionId);
    container.listen(provider, (_, _) {});
    return container.read(provider.future);
  }

  test('launcher == true → faltan tipos y áreas en la API', () async {
    final result = await prepare(_launcherId);

    expect(result.status, AlertPreparationStatus.featureUnavailable);
    expect(result.institution!.institution.name, 'A');
    expect(result.missingFeatures, [
      AlertApiFeature.emergencyTypes,
      AlertApiFeature.affectedAreas,
    ]);
    expect(
      api.requests.map((r) => r.path),
      everyElement(isIn(_knownPaths)),
      reason: 'no se llama a rutas de alertas inexistentes',
    );
  });

  test('administrator sin launcher → permiso denegado', () async {
    final result = await prepare(_adminId);

    expect(result.status, AlertPreparationStatus.permissionDenied);
    expect(result.institution!.isAdministrator, isTrue);
    expect(result.missingFeatures, isEmpty);
  });

  test('institución que la API no reporta → permiso denegado', () async {
    final result = await prepare('6ab4876f45cc209961dd9999');

    expect(result.status, AlertPreparationStatus.permissionDenied);
    expect(result.institution, isNull);
  });

  test('sin red → error, nunca permiso denegado', () async {
    api.on('GET', '/users/me', connectionError);

    await expectLater(
      prepare(_launcherId),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.connection,
        ),
      ),
    );
  });
}
