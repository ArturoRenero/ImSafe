import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imsafe_lanzadores/app/router.dart';
import 'package:imsafe_lanzadores/core/errors/api_failure.dart';
import 'package:imsafe_lanzadores/features/access/data/access_dtos.dart';
import 'package:imsafe_lanzadores/features/access/domain/launcher_access.dart';
import 'package:imsafe_lanzadores/features/auth/data/auth_dtos.dart';
import 'package:imsafe_lanzadores/features/auth/presentation/session_controller.dart';

import '../helpers/fakes.dart';

LauncherAccess _access({required bool launcher}) => LauncherAccess(
  user: User.fromJson(userJson()),
  institutions: [MyInstitution.fromJson(institutionJson(launcher: launcher))],
  accessRequests: const [],
);

String? _redirect(
  String location, {
  AsyncValue<SessionStatus> session = const AsyncData(SessionStatus.signedIn),
  AsyncValue<LauncherAccess?> access = const AsyncLoading(),
}) => resolveRedirect(session: session, access: access, location: location);

void main() {
  const signedOut = AsyncData(SessionStatus.signedOut);
  const networkError = ApiFailure(ApiFailureKind.connection);

  test('restaurando sesión → loading', () {
    expect(
      _redirect('/home', session: const AsyncLoading()),
      AppRoutes.loading,
    );
  });

  test('sin sesión → login; registro permitido', () {
    expect(_redirect(AppRoutes.home, session: signedOut), AppRoutes.login);
    expect(_redirect(AppRoutes.access, session: signedOut), AppRoutes.login);
    expect(_redirect(AppRoutes.register, session: signedOut), isNull);
    expect(_redirect(AppRoutes.login, session: signedOut), isNull);
  });

  test('con sesión, esperando a imSafeAPI → loading', () {
    expect(_redirect(AppRoutes.home), AppRoutes.loading);
  });

  test('fallo de red → pantalla de error, nunca acceso denegado', () {
    final access = AsyncValue<LauncherAccess?>.error(
      networkError,
      StackTrace.empty,
    );
    expect(_redirect(AppRoutes.home, access: access), AppRoutes.error);
    expect(_redirect(AppRoutes.access, access: access), AppRoutes.error);
  });

  test('no autorizado por la API → solo pantalla de acceso', () {
    final access = AsyncData<LauncherAccess?>(_access(launcher: false));
    expect(_redirect(AppRoutes.home, access: access), AppRoutes.access);
    expect(_redirect(AppRoutes.login, access: access), AppRoutes.access);
    expect(_redirect(AppRoutes.access, access: access), isNull);
  });

  test('autorizado por la API → inicio; puede ver sus solicitudes', () {
    final access = AsyncData<LauncherAccess?>(_access(launcher: true));
    expect(_redirect(AppRoutes.loading, access: access), AppRoutes.home);
    expect(_redirect(AppRoutes.login, access: access), AppRoutes.home);
    expect(_redirect(AppRoutes.home, access: access), isNull);
    expect(_redirect(AppRoutes.access, access: access), isNull);
  });

  test('flujo de alertas solo con launcher reportado por la API', () {
    final launcher = AsyncData<LauncherAccess?>(_access(launcher: true));
    final notLauncher = AsyncData<LauncherAccess?>(_access(launcher: false));
    const id = '6ab4876f45cc209961dd09ad';
    final alertRoutes = [
      AppRoutes.alertInstitution,
      AppRoutes.alertEmit(id),
      AppRoutes.institutionAlerts(id),
      AppRoutes.alertDetail(id, '6ab4876f45cc209961dd0a01'),
    ];

    for (final route in alertRoutes) {
      expect(_redirect(route, access: launcher), isNull, reason: route);
      expect(
        _redirect(route, access: notLauncher),
        AppRoutes.access,
        reason: route,
      );
    }
    expect(_redirect('/alerts/newx', access: launcher), AppRoutes.home);
  });
}
