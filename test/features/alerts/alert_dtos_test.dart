import 'package:flutter_test/flutter_test.dart';

import 'package:imsafe_lanzadores/core/api/api_client.dart';
import 'package:imsafe_lanzadores/core/errors/api_failure.dart';
import 'package:imsafe_lanzadores/core/utils/uuid.dart';
import 'package:imsafe_lanzadores/features/alerts/data/alert_dtos.dart';
import 'package:imsafe_lanzadores/features/alerts/presentation/alert_texts.dart';

import '../../helpers/fakes.dart';

void main() {
  test('EmergencyTypes se interpreta según el schema', () {
    final types = parseEmergencyTypes(emergencyTypesJson());
    expect(types.map((t) => t.type), ['sismo', 'incendio', 'otro']);
    expect(types.first.durationMinutes, 30);
    expect(types.last.requiresDescription, isTrue);
  });

  test('EmergencyTypes con otra schemaVersion es respuesta inválida', () {
    expect(
      () => parseJson({
        ...emergencyTypesJson(),
        'schemaVersion': 2,
      }, parseEmergencyTypes),
      throwsA(
        isA<ApiFailure>().having(
          (f) => f.kind,
          'kind',
          ApiFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('InstitutionAlert acepta los estados de OpenAPI y campos nulos', () {
    for (final state in ['active', 'closed', 'cancelled', 'expired']) {
      final alert = InstitutionAlert.fromJson(alertJson(state: state));
      expect(alert.state.name, state);
      expect(alert.otherDescription, isNull);
      expect(alert.endedAt, isNull);
    }
    expect(
      () => InstitutionAlert.fromJson(alertJson(state: 'paused')),
      throwsFormatException,
    );
  });

  test('AlertAccepted y AlertDeliveryStatus', () {
    final accepted = AlertAccepted.fromJson(acceptedJson(revision: 3));
    expect(accepted.acceptedRevision, 3);
    expect(accepted.acceptedAt.isUtc, isTrue);

    final delivery = AlertDeliveryStatus.fromJson(deliveryJson());
    expect(delivery.outboxState, 'pending');
    expect(delivery.fanoutComplete, isFalse);
    expect(delivery.opened, 0);
  });

  test('validación local según los límites del schema', () {
    const rule = AlertTextRules.otherDescription;
    expect(validateAlertText('   ', rule), 'Campo obligatorio.');
    expect(validateAlertText('Fuga de agua', rule), isNull);
    expect(validateAlertText('a' * 161, rule), 'Máximo 160 caracteres.');
    // Cada carácter de control se escapa como \u0001 (6 bytes): 482 > 480.
    expect(
      validateAlertText('x${'\u0001' * 80}x', rule),
      'El texto es demasiado largo.',
    );
    expect(validateAlertText('"' * 150, AlertTextRules.reason), isNull);
  });

  test('uuidV4 genera claves de idempotencia válidas y distintas', () {
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final keys = {for (var i = 0; i < 100; i++) uuidV4()};
    expect(keys, hasLength(100));
    expect(keys, everyElement(matches(pattern)));
  });
}
