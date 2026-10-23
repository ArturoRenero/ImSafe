import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imsafe_lanzadores/app/app.dart';
import 'package:imsafe_lanzadores/core/errors/api_failure.dart';
import 'package:imsafe_lanzadores/features/alerts/domain/alert_command.dart';
import 'package:imsafe_lanzadores/features/alerts/presentation/alert_command_controller.dart';

import '../../helpers/fakes.dart';

const _institution = 'dddddddddddddddddddd09ad';
const _alertsPath = '/institutions/$_institution/alerts';
const _alertId = 'dddddddddddddddddddd0a01';

void main() {
  late FakeApi api;
  late FakeSecureStorage storage;
  late ProviderContainer container;

  /// Contenedor nuevo sobre el mismo almacenamiento: equivale a cerrar y
  /// volver a abrir la pantalla o la app.
  ProviderContainer newContainer() {
    final created = ProviderContainer(
      retry: noAutomaticRetry,
      overrides: fakeBackendOverrides(api: api, storage: storage),
    );
    addTearDown(created.dispose);
    return created;
  }

  setUp(() {
    api = FakeApi();
    storage = FakeSecureStorage(storedSession());
    container = newContainer();
  });

  bool hasPendingKey() =>
      storage.values.keys.any((k) => k.startsWith('imsafe.alerts.pending.'));

  AlertCommandController controller() {
    final provider = alertCommandProvider('test');
    container.listen(provider, (_, _) {});
    return container.read(provider.notifier);
  }

  Iterable<RequestOptions> commands() =>
      api.requests.where((r) => r.method != 'GET');

  const sismo = EmitAlert(
    institutionId: _institution,
    type: 'sismo',
    message: 'Sigan las indicaciones.',
  );

  test('emite con Idempotency-Key UUID, Bearer y cuerpo AlertCreate', () async {
    api.on('POST', _alertsPath, (_) async => jsonBody(acceptedJson(), 202));

    final accepted = await controller().send(sismo);

    expect(accepted!.alertId, _alertId);
    final request = commands().single;
    expect(
      request.headers['Idempotency-Key'],
      matches(RegExp(r'^[0-9a-f-]{36}$')),
    );
    expect(request.headers['Authorization'], 'Bearer access-1');
    expect(request.data, {
      'type': 'sismo',
      'message': 'Sigan las indicaciones.',
    });
  });

  test('"otro" envía otherDescription; los demás tipos no', () async {
    api.on('POST', _alertsPath, (_) async => jsonBody(acceptedJson(), 202));

    await controller().send(
      const EmitAlert(
        institutionId: _institution,
        type: 'otro',
        message: 'Eviten el edificio B.',
        otherDescription: 'Fuga de agua',
      ),
    );

    expect(commands().single.data, {
      'type': 'otro',
      'message': 'Eviten el edificio B.',
      'otherDescription': 'Fuga de agua',
    });
  });

  test('doble envío: el segundo se ignora mientras el primero sigue', () async {
    final response = Completer<void>();
    api.on('POST', _alertsPath, (_) async {
      await response.future;
      return jsonBody(acceptedJson(), 202);
    });
    final notifier = controller();

    final first = notifier.send(sismo);
    final second = await notifier.send(sismo);
    response.complete();

    expect(second, isNull);
    expect(await first, isNotNull);
    expect(commands(), hasLength(1));
  });

  test('sin confirmación (timeout): repetir usa la MISMA clave', () async {
    var calls = 0;
    api.on('POST', _alertsPath, (options) async {
      if (++calls == 1) timeoutError(options);
      return jsonBody(acceptedJson(), 202);
    });
    final notifier = controller();

    expect(await notifier.send(sismo), isNull);
    expect(
      container.read(alertCommandProvider('test'))!.error,
      isA<ApiFailure>().having(
        (f) => f.isConfirmedByServer,
        'confirmed',
        false,
      ),
    );
    expect(await notifier.send(sismo), isNotNull);

    final keys = commands().map((r) => r.headers['Idempotency-Key']).toList();
    expect(keys, hasLength(2));
    expect(keys.first, keys.last);
  });

  test('rechazo 409 de la API: el siguiente envío usa clave nueva', () async {
    var calls = 0;
    api.on(
      'POST',
      _alertsPath,
      (_) async => ++calls == 1
          ? apiError(409, 'ACTIVE_ALERT_EXISTS')
          : jsonBody(acceptedJson(), 202),
    );
    final notifier = controller();

    expect(await notifier.send(sismo), isNull);
    expect(
      container.read(alertCommandProvider('test'))!.error,
      isA<ApiFailure>().having(
        (f) => f.errorCode,
        'code',
        'ACTIVE_ALERT_EXISTS',
      ),
    );
    await notifier.send(sismo);

    final keys = commands().map((r) => r.headers['Idempotency-Key']).toSet();
    expect(keys, hasLength(2));
  });

  test(
    'comando distinto tras un fallo sin confirmar usa clave nueva',
    () async {
      api.on('POST', _alertsPath, (options) async => timeoutError(options));
      final notifier = controller();

      await notifier.send(sismo);
      await notifier.send(
        const EmitAlert(
          institutionId: _institution,
          type: 'sismo',
          message: 'Otro texto.',
        ),
      );

      final keys = commands().map((r) => r.headers['Idempotency-Key']).toSet();
      expect(keys, hasLength(2));
    },
  );

  test('actualizar y finalizar envían expectedRevision', () async {
    api
      ..on(
        'PATCH',
        '$_alertsPath/$_alertId',
        (_) async => jsonBody(acceptedJson(revision: 2), 202),
      )
      ..on(
        'POST',
        '$_alertsPath/$_alertId/transitions',
        (_) async => jsonBody(acceptedJson(revision: 3), 202),
      );
    final notifier = controller();

    await notifier.send(
      const UpdateAlertMessage(
        institutionId: _institution,
        alertId: _alertId,
        expectedRevision: 1,
        message: 'Nuevo mensaje.',
      ),
    );
    await notifier.send(
      const TransitionAlert(
        institutionId: _institution,
        alertId: _alertId,
        expectedRevision: 2,
        target: AlertTransitionTarget.closed,
        reason: 'Terminó la emergencia.',
      ),
    );

    expect(commands().map((r) => r.data), [
      {'expectedRevision': 1, 'message': 'Nuevo mensaje.'},
      {
        'expectedRevision': 2,
        'state': 'closed',
        'reason': 'Terminó la emergencia.',
      },
    ]);
  });

  test('la clave se guarda antes de enviar y sobrevive al cierre', () async {
    api.on('POST', _alertsPath, (options) async {
      expect(hasPendingKey(), isTrue, reason: 'persistida antes del envío');
      timeoutError(options);
    });
    await controller().send(sismo);
    expect(hasPendingKey(), isTrue);
    container.dispose();

    // Pantalla/app reabierta: repetir el mismo comando reutiliza la clave.
    container = newContainer();
    api.on('POST', _alertsPath, (_) async => jsonBody(acceptedJson(), 202));
    final restored = container.read(pendingAlertCommandProvider('test').future);
    expect(await restored, sismo);
    expect(await controller().send(sismo), isNotNull);

    final keys = commands().map((r) => r.headers['Idempotency-Key']).toList();
    expect(keys, hasLength(2));
    expect(keys.first, keys.last);
    expect(hasPendingKey(), isFalse, reason: 'se borra al aceptarse');
  });

  test('rechazo 4xx borra la clave guardada', () async {
    api.on('POST', _alertsPath, (_) async => apiError(403, 'FORBIDDEN'));

    await controller().send(sismo);

    expect(hasPendingKey(), isFalse);
  });
}
