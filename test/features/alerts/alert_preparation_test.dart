import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imsafe_lanzadores/app/app.dart';
import 'package:imsafe_lanzadores/core/errors/api_failure.dart';
import 'package:imsafe_lanzadores/features/alerts/domain/alert_preparation.dart';
import 'package:imsafe_lanzadores/features/alerts/presentation/alert_preparation_controller.dart';

import '../../helpers/fakes.dart';

const _launcherId = '6ab4876f45cc209961dd0001';
const _adminId = '6ab4876f45cc209961dd0002';

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
      )
      ..on(
        'GET',
        '/emergency-types',
        (_) async => jsonBody(emergencyTypesJson(), 200),
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

  test('launcher == true → catálogo de la API con sismo por defecto', () async {
    final result = await prepare(_launcherId);

    expect(result.status, AlertPreparationStatus.ready);
    expect(result.institution!.institution.name, 'A');
    expect(result.emergencyTypes.map((t) => t.type), [
      'sismo',
      'incendio',
      'otro',
    ]);
    expect(result.defaultType!.type, 'sismo');
    expect(api.requests.where((r) => r.method != 'GET'), isEmpty);
  });

  test('administrator sin launcher → permiso denegado', () async {
    final result = await prepare(_adminId);

    expect(result.status, AlertPreparationStatus.permissionDenied);
    expect(result.institution!.isAdministrator, isTrue);
    expect(result.emergencyTypes, isEmpty);
    expect(api.count('GET', '/emergency-types'), 0);
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
