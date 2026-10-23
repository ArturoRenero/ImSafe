import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imsafe_lanzadores/app/app.dart';
import 'package:imsafe_lanzadores/features/access/presentation/access_screen.dart';
import 'package:imsafe_lanzadores/features/access/presentation/institution_capability_tile.dart';
import 'package:imsafe_lanzadores/features/alerts/presentation/active_alerts_screen.dart';
import 'package:imsafe_lanzadores/features/alerts/presentation/alert_detail_screen.dart';
import 'package:imsafe_lanzadores/features/alerts/presentation/alert_institution_screen.dart';
import 'package:imsafe_lanzadores/features/alerts/presentation/emit_alert_screen.dart';

import '../../helpers/fakes.dart';

const _institution = 'dddddddddddddddddddd09ad';
const _alertsPath = '/institutions/$_institution/alerts';
const _alertId = 'dddddddddddddddddddd0a01';

void main() {
  late FakeApi api;

  setUp(() => api = FakeApi());

  Future<void> pumpApp(
    WidgetTester tester, {
    Map<String, String> extraStorage = const {},
  }) async {
    // Pantalla alta: los formularios caben sin desplazar la lista.
    tester.view
      ..physicalSize = const Size(800, 2000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: fakeBackendOverrides(
          api: api,
          storage: FakeSecureStorage({...storedSession(), ...extraStorage}),
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
      )
      ..on(
        'GET',
        '/emergency-types',
        (_) async => jsonBody(emergencyTypesJson(), 200),
      );
  }

  Iterable<String> commands() => api.requests
      .where((r) => r.method != 'GET')
      .map((r) => '${r.method} ${r.path}');

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openEmitForm(WidgetTester tester) async {
    stubInstitutions([institutionJson(launcher: true)]);
    await pumpApp(tester);
    await tap(tester, find.text('Generar alerta'));
    expect(find.byType(EmitAlertScreen), findsOneWidget);
  }

  Future<void> fillAndConfirm(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Instrucciones breves'),
      'Sigan las indicaciones.',
    );
    await tap(tester, find.text('Revisar y emitir'));
    expect(find.text('¿Emitir esta alerta?'), findsOneWidget);
    await tap(tester, find.widgetWithText(FilledButton, 'Emitir alerta'));
  }

  testWidgets('emisión: sismo por defecto, validación y confirmación', (
    tester,
  ) async {
    api.on('POST', _alertsPath, (_) async => jsonBody(acceptedJson(), 202));
    await openEmitForm(tester);

    final sismo = tester.widget<RadioGroup<String>>(
      find.byType(RadioGroup<String>),
    );
    expect(sismo.groupValue, 'sismo');
    expect(find.text('Incendio'), findsOneWidget);

    // Sin mensaje no se abre la confirmación.
    await tap(tester, find.text('Revisar y emitir'));
    expect(find.text('Campo obligatorio.'), findsOneWidget);
    expect(find.text('¿Emitir esta alerta?'), findsNothing);

    // Cancelar la confirmación no envía nada.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Instrucciones breves'),
      'Sigan las indicaciones.',
    );
    await tap(tester, find.text('Revisar y emitir'));
    await tap(tester, find.text('Cancelar'));
    expect(commands(), isEmpty);

    await tap(tester, find.text('Revisar y emitir'));
    await tap(tester, find.widgetWithText(FilledButton, 'Emitir alerta'));

    expect(commands(), ['POST $_alertsPath']);
    expect(find.textContaining('imSafeAPI aceptó y registró'), findsOneWidget);
    expect(
      find.textContaining('distribución a las personas está pendiente'),
      findsOneWidget,
    );
    expect(find.text('Revisar y emitir'), findsNothing, reason: 'sin reenvío');
  });

  testWidgets('"otro" exige descripción', (tester) async {
    await openEmitForm(tester);

    await tap(tester, find.text('Otro'));
    expect(
      find.widgetWithText(TextFormField, 'Descripción del evento'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Instrucciones breves'),
      'Eviten el edificio B.',
    );
    await tap(tester, find.text('Revisar y emitir'));

    expect(find.text('Campo obligatorio.'), findsOneWidget);
    expect(find.text('¿Emitir esta alerta?'), findsNothing);
  });

  testWidgets('403 de la API: sin autorización, nada se da por emitido', (
    tester,
  ) async {
    api.on('POST', _alertsPath, (_) async => apiError(403, 'FORBIDDEN'));
    await openEmitForm(tester);

    await fillAndConfirm(tester);

    expect(
      find.textContaining('No tienes autorización para operar alertas'),
      findsOneWidget,
    );
    expect(find.textContaining('aceptó y registró'), findsNothing);
  });

  testWidgets('409 ACTIVE_ALERT_EXISTS muestra su significado', (tester) async {
    api.on(
      'POST',
      _alertsPath,
      (_) async => apiError(409, 'ACTIVE_ALERT_EXISTS'),
    );
    await openEmitForm(tester);

    await fillAndConfirm(tester);

    expect(
      find.textContaining('Ya existe una alerta activa de este tipo'),
      findsOneWidget,
    );
  });

  testWidgets('sin confirmación de la API no se afirma el resultado', (
    tester,
  ) async {
    api.on('POST', _alertsPath, (options) async => timeoutError(options));
    await openEmitForm(tester);

    await fillAndConfirm(tester);

    expect(
      find.textContaining('No se pudo confirmar si imSafeAPI registró'),
      findsOneWidget,
    );
    expect(find.textContaining('aceptó y registró'), findsNothing);
  });

  testWidgets('varias instituciones: solo las de launcher permiten emitir', (
    tester,
  ) async {
    stubInstitutions([
      institutionJson(
        id: 'dddddddddddddddddddd0001',
        name: 'A',
        launcher: true,
      ),
      institutionJson(
        id: 'dddddddddddddddddddd0002',
        name: 'B',
        launcher: true,
      ),
      institutionJson(
        id: 'dddddddddddddddddddd0003',
        name: 'C',
        launcher: false,
        administrator: true,
      ),
    ]);
    await pumpApp(tester);

    await tap(tester, find.text('Generar alerta'));
    expect(find.byType(AlertInstitutionScreen), findsOneWidget);
    expect(find.byType(InstitutionCapabilityTile), findsNWidgets(3));
    expect(
      find.textContaining(administratorIsNotLauncherMessage),
      findsOneWidget,
    );

    await tap(tester, find.text('C'));
    expect(find.byType(AlertInstitutionScreen), findsOneWidget);

    await tap(tester, find.text('B'));
    expect(find.byType(EmitAlertScreen), findsOneWidget);
  });

  testWidgets('administrator sin launcher: sin flujo de alertas', (
    tester,
  ) async {
    stubInstitutions([institutionJson(launcher: false, administrator: true)]);
    await pumpApp(tester);

    expect(find.byType(AccessScreen), findsOneWidget);
    expect(find.textContaining(launcherDeniedMessage), findsOneWidget);
    expect(find.text('Generar alerta'), findsNothing);
  });

  testWidgets('alertas activas → detalle → finalizar con revisión esperada', (
    tester,
  ) async {
    stubInstitutions([institutionJson(launcher: true)]);
    var state = 'active';
    var revision = 1;
    api
      ..on(
        'GET',
        _alertsPath,
        (_) async => jsonBody(alertPageJson([alertJson()]), 200),
      )
      ..on(
        'GET',
        '$_alertsPath/$_alertId',
        (_) async => jsonBody(alertJson(state: state, revision: revision), 200),
      )
      ..on(
        'GET',
        '$_alertsPath/$_alertId/delivery-status',
        (_) async => jsonBody(deliveryJson(), 200),
      )
      ..on('POST', '$_alertsPath/$_alertId/transitions', (options) async {
        state = 'closed';
        revision = 2;
        return jsonBody(acceptedJson(revision: 2), 202);
      });
    await pumpApp(tester);

    await tap(tester, find.text('Institución Prueba'));
    expect(find.byType(ActiveAlertsScreen), findsOneWidget);
    await tap(tester, find.text('Sismo'));
    expect(find.byType(AlertDetailScreen), findsOneWidget);
    expect(find.text('Estado: Activa'), findsOneWidget);
    expect(find.textContaining('Estado de envío: pendiente'), findsOneWidget);

    await tap(tester, find.text('Finalizar alerta'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motivo'),
      'Terminó la emergencia.',
    );
    await tap(tester, find.widgetWithText(FilledButton, 'Finalizar'));

    final transition = api.requests.singleWhere((r) => r.method == 'POST');
    expect(transition.data, {
      'expectedRevision': 1,
      'state': 'closed',
      'reason': 'Terminó la emergencia.',
    });
    expect(find.text('Estado: Finalizada'), findsOneWidget);
    expect(find.text('Finalizar alerta'), findsNothing);
  });

  testWidgets('emisión sin confirmar guardada en el teléfono se recupera', (
    tester,
  ) async {
    stubInstitutions([institutionJson(launcher: true)]);
    await pumpApp(
      tester,
      extraStorage: {
        'imsafe.alerts.pending.emit:$_institution': jsonEncode({
          'key': '0b6f6a0e-7c43-4f0e-9d3a-1c2b3a4d5e6f',
          'command': {
            'kind': 'emit',
            'institutionId': _institution,
            'type': 'incendio',
            'message': 'Salgan por la escalera norte.',
            'otherDescription': null,
          },
        }),
      },
    );

    await tap(tester, find.text('Generar alerta'));

    expect(
      find.textContaining('hay una emisión cuyo resultado no se confirmó'),
      findsOneWidget,
    );
    expect(find.text('Salgan por la escalera norte.'), findsOneWidget);
    final group = tester.widget<RadioGroup<String>>(
      find.byType(RadioGroup<String>),
    );
    expect(group.groupValue, 'incendio');
  });
}
