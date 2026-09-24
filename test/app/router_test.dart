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
}
