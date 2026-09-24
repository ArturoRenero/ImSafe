import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imsafe_lanzadores/app/app.dart';
import 'package:imsafe_lanzadores/features/access/presentation/access_screen.dart';
import 'package:imsafe_lanzadores/features/access/presentation/institution_capability_tile.dart';
import 'package:imsafe_lanzadores/features/alerts/presentation/alert_institution_screen.dart';
import 'package:imsafe_lanzadores/features/alerts/presentation/alert_preparation_screen.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeApi api;

  setUp(() => api = FakeApi());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: fakeBackendOverrides(
          api: api,
          storage: FakeSecureStorage(storedSession()),
        ),
        child: const ImSafeApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  void stubInstitutions(List<Map<String, Object?>> institutions) {
    api
      ..on('GET', '/users/me', (_) async => jsonBody(userJson(), 200))
      ..on(
        'GET',
        '/users/me/institutions',
        (_) async => jsonBody(pageJson(institutions), 200),
      )
      ..on(
        'GET',
        '/users/me/access-requests',
        (_) async => jsonBody(pageJson([]), 200),
      );
  }

  Future<void> tapGenerateAlert(WidgetTester tester) async {
    await tester.tap(find.text('Generar alerta'));
    await tester.pumpAndSettle();
  }

  void expectBlockedByBackend(WidgetTester tester) {
    expect(find.byType(AlertPreparationScreen), findsOneWidget);
    expect(
      find.text(
        'Los tipos de emergencia todavía no están disponibles en la API.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Las áreas afectadas todavía no están disponibles en la API.'),
      findsOneWidget,
    );
    expect(
      find.text('La creación de alertas todavía no está disponible en la API.'),
      findsOneWidget,
    );
    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Revisar alerta'),
    );
    expect(submit.onPressed, isNull, reason: 'no se puede enviar nada');
  }

  testWidgets('una institución autorizada → se selecciona sola', (
    tester,
  ) async {
    stubInstitutions([institutionJson(launcher: true)]);
    await pumpApp(tester);

    await tapGenerateAlert(tester);

    expect(find.byType(AlertInstitutionScreen), findsNothing);
    expect(find.text('Institución Prueba'), findsOneWidget);
    expectBlockedByBackend(tester);
    expect(
      api.requests.where((r) => r.method != 'GET'),
      isEmpty,
      reason: 'ninguna escritura contra la API',
    );
  });

  testWidgets('varias instituciones → selección; sin launcher no avanza', (
    tester,
  ) async {
    stubInstitutions([
      institutionJson(
        id: '6ab4876f45cc209961dd0001',
        name: 'A',
        launcher: true,
      ),
      institutionJson(
        id: '6ab4876f45cc209961dd0002',
        name: 'B',
        launcher: true,
      ),
      institutionJson(
        id: '6ab4876f45cc209961dd0003',
        name: 'C',
        launcher: false,
        administrator: true,
      ),
    ]);
    await pumpApp(tester);

    await tapGenerateAlert(tester);
    expect(find.byType(AlertInstitutionScreen), findsOneWidget);
    expect(find.byType(InstitutionCapabilityTile), findsNWidgets(3));
    expect(
      find.textContaining(launcherDeniedMessage),
      findsOneWidget,
      reason: 'C es administradora, no lanzadora',
    );
    expect(
      find.textContaining(administratorIsNotLauncherMessage),
      findsOneWidget,
    );

    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertInstitutionScreen), findsOneWidget);

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expectBlockedByBackend(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AlertInstitutionScreen), findsOneWidget);
  });

  testWidgets('administrator sin launcher: sin flujo de alertas', (
    tester,
  ) async {
    stubInstitutions([institutionJson(launcher: false, administrator: true)]);
    await pumpApp(tester);

    expect(find.byType(AccessScreen), findsOneWidget);
    expect(find.text('Mis instituciones'), findsOneWidget);
    expect(find.textContaining(launcherDeniedMessage), findsOneWidget);
    expect(find.text('Generar alerta'), findsNothing);
  });
}
