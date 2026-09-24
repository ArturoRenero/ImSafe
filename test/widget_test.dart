import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imsafe_lanzadores/app/app.dart';
import 'package:imsafe_lanzadores/features/access/presentation/access_screen.dart';
import 'package:imsafe_lanzadores/features/access/presentation/launcher_home_screen.dart';
import 'package:imsafe_lanzadores/features/auth/presentation/login_screen.dart';

import 'helpers/fakes.dart';

void main() {
  late FakeApi api;

  setUp(() => api = FakeApi());

  Future<void> pumpApp(WidgetTester tester, FakeSecureStorage storage) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: fakeBackendOverrides(api: api, storage: storage),
        child: const ImSafeApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  void stubAccess({required bool launcher, List<Object?> requests = const []}) {
    api
      ..on('GET', '/users/me', (_) async => jsonBody(userJson(), 200))
      ..on(
        'GET',
        '/users/me/institutions',
        (_) async =>
            jsonBody(pageJson([institutionJson(launcher: launcher)]), 200),
      )
      ..on(
        'GET',
        '/users/me/access-requests',
        (_) async => jsonBody(pageJson(requests), 200),
      )
      ..on(
        'GET',
        '/institutions/6ab4876f45cc209961dd09ad',
        (_) async => jsonBody(institutionJson(), 200),
      );
  }

  testWidgets('sin sesión guardada arranca en login', (tester) async {
    await pumpApp(tester, FakeSecureStorage());

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(api.requests, isEmpty);
  });

  testWidgets('login incorrecto muestra el error y no navega', (tester) async {
    api.on(
      'POST',
      '/auth/login',
      (_) async => jsonBody({
        'error': {'code': 'UNAUTHORIZED'},
      }, 401),
    );
    await pumpApp(tester, FakeSecureStorage());

    await tester.enterText(find.byType(TextFormField).at(0), 'a@example.test');
    await tester.enterText(find.byType(TextFormField).at(1), 'x' * 20);
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('login correcto guarda tokens y muestra el estado real', (
    tester,
  ) async {
    final storage = FakeSecureStorage();
    api.on('POST', '/auth/login', (_) async => jsonBody(tokensJson('1'), 200));
    stubAccess(launcher: false, requests: [permissionJson()]);
    await pumpApp(tester, storage);

    await tester.enterText(find.byType(TextFormField).at(0), 'a@example.test');
    await tester.enterText(find.byType(TextFormField).at(1), 'x' * 20);
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(storage.values, storedSession(access: 'access-1'));
    expect(find.byType(AccessScreen), findsOneWidget);
    expect(find.textContaining('Pendiente de aprobación'), findsOneWidget);
    expect(find.text('Institución Prueba'), findsOneWidget);
  });

  testWidgets('sesión restaurada y autorizada por la API → inicio', (
    tester,
  ) async {
    stubAccess(launcher: true);
    await pumpApp(tester, FakeSecureStorage(storedSession()));

    expect(find.byType(LauncherHomeScreen), findsOneWidget);
    expect(find.text('Institución Prueba'), findsOneWidget);
  });

  testWidgets('solicitud aprobada sin capability no da acceso de lanzador', (
    tester,
  ) async {
    stubAccess(launcher: false, requests: [permissionJson(status: 'approved')]);
    await pumpApp(tester, FakeSecureStorage(storedSession()));

    expect(find.byType(AccessScreen), findsOneWidget);
    expect(find.byType(LauncherHomeScreen), findsNothing);
  });

  testWidgets('sin red muestra error de conexión, no "sin autorización"', (
    tester,
  ) async {
    final storage = FakeSecureStorage(storedSession());
    api.on('GET', '/users/me', connectionError);
    await pumpApp(tester, storage);

    expect(
      find.textContaining('No hay conexión con imSafeAPI'),
      findsOneWidget,
    );
    expect(find.byType(AccessScreen), findsNothing);
    expect(storage.values, isNotEmpty, reason: 'la sesión se conserva');

    // Reconexión: reintento explícito del usuario.
    stubAccess(launcher: true);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byType(LauncherHomeScreen), findsOneWidget);
  });

  testWidgets('actualizar sin red conserva la última información', (
    tester,
  ) async {
    stubAccess(launcher: true);
    await pumpApp(tester, FakeSecureStorage(storedSession()));

    api.on('GET', '/users/me', connectionError);
    await tester.tap(find.byTooltip('Actualizar estado'));
    await tester.pumpAndSettle();

    expect(find.byType(LauncherHomeScreen), findsOneWidget);
    expect(find.textContaining('No se pudo actualizar'), findsOneWidget);
    expect(
      find.textContaining('No hay conexión con imSafeAPI'),
      findsOneWidget,
    );
  });

  testWidgets('sesión revocada en el servidor → vuelve a login', (
    tester,
  ) async {
    final storage = FakeSecureStorage(storedSession());
    api
      ..on(
        'GET',
        '/users/me',
        (_) async => jsonBody({
          'error': {'code': 'UNAUTHORIZED'},
        }, 401),
      )
      ..on(
        'POST',
        '/auth/refresh',
        (_) async => jsonBody({
          'error': {'code': 'UNAUTHORIZED'},
        }, 401),
      );
    await pumpApp(tester, storage);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(storage.values, isEmpty);
  });

  testWidgets('logout borra la sesión aunque la API no responda', (
    tester,
  ) async {
    final storage = FakeSecureStorage(storedSession());
    stubAccess(launcher: true);
    api.on('POST', '/auth/logout', connectionError);
    await pumpApp(tester, storage);

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(storage.values, isEmpty);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('no confirmó la revocación'), findsOneWidget);
  });
}
