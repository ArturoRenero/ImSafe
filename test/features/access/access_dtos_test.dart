import 'package:flutter_test/flutter_test.dart';

import 'package:imsafe_lanzadores/core/api/api_client.dart';
import 'package:imsafe_lanzadores/core/errors/api_failure.dart';
import 'package:imsafe_lanzadores/features/access/data/access_dtos.dart';
import 'package:imsafe_lanzadores/features/access/domain/launcher_access.dart';
import 'package:imsafe_lanzadores/features/auth/data/auth_dtos.dart';

import '../../helpers/fakes.dart';

void main() {
  test('User se interpreta según el schema', () {
    final user = User.fromJson(userJson());
    expect(user.name, 'Lanzador Prueba');
    expect(user.createdAt.isUtc, isTrue);
  });

  test('MyInstitution expone capabilities.launcher', () {
    final item = MyInstitution.fromJson(institutionJson(launcher: true));
    expect(item.isLauncher, isTrue);
    expect(item.isAdministrator, isFalse);
    expect(item.institution.id, '6ab4876f45cc209961dd09ad');
  });

  test('Permission acepta exactamente los estados de OpenAPI', () {
    for (final status in ['pending', 'approved', 'rejected', 'revoked']) {
      expect(
        Permission.fromJson(permissionJson(status: status)).status.name,
        status,
      );
    }
    expect(
      () => Permission.fromJson(permissionJson(status: 'suspended')),
      throwsFormatException,
    );
  });

  test('un campo requerido ausente es respuesta inválida', () {
    final broken = userJson()..remove('email');
    expect(
      () => parseJson(broken, User.fromJson),
      throwsA(
        isA<ApiFailure>().having(
          (f) => f.kind,
          'kind',
          ApiFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('Page calcula si hay más páginas', () {
    final page = Page.fromJson({
      'items': [permissionJson()],
      'page': 1,
      'limit': 1,
      'total': 3,
    }, Permission.fromJson);
    expect(page.items, hasLength(1));
    expect(page.hasMore, isTrue);
  });

  group('LauncherAccess', () {
    LauncherAccess access({
      List<bool> launcher = const [],
      List<String> requests = const [],
    }) => LauncherAccess(
      user: User.fromJson(userJson()),
      institutions: [
        for (final (i, value) in launcher.indexed)
          MyInstitution.fromJson(
            institutionJson(id: 'a' * 23 + '$i', launcher: value),
          ),
      ],
      accessRequests: [
        for (final status in requests)
          Permission.fromJson(permissionJson(status: status)),
      ],
    );

    test('autorizado solo si la API reporta launcher en alguna', () {
      expect(access().isAuthorizedLauncher, isFalse);
      expect(access(launcher: [false]).isAuthorizedLauncher, isFalse);
      expect(access(launcher: [false, true]).isAuthorizedLauncher, isTrue);
    });

    test('una solicitud aprobada no autoriza si la API no lo confirma', () {
      expect(access(requests: ['approved']).isAuthorizedLauncher, isFalse);
    });

    test('solicitud abierta = pendiente o aprobada', () {
      const id = '6ab4876f45cc209961dd09ad';
      expect(access(requests: ['pending']).hasOpenRequestFor(id), isTrue);
      expect(access(requests: ['approved']).hasOpenRequestFor(id), isTrue);
      expect(access(requests: ['rejected']).hasOpenRequestFor(id), isFalse);
      expect(access(requests: ['revoked']).hasOpenRequestFor(id), isFalse);
    });
  });
}
