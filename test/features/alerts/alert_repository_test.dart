import 'package:flutter_test/flutter_test.dart';

import 'package:imsafe_lanzadores/features/alerts/data/alert_repository.dart';
import 'package:imsafe_lanzadores/features/alerts/domain/alert_api_feature.dart';

Matcher _unavailable(AlertApiFeature feature) => throwsA(
  isA<AlertFeatureUnavailable>().having((e) => e.feature, 'feature', feature),
);

void main() {
  const repository = AlertRepository();
  const institutionId = '6ab4876f45cc209961dd09ad';

  test('cada operación de alertas reporta que falta en imSafeAPI', () async {
    await expectLater(
      repository.fetchEmergencyTypes(institutionId),
      _unavailable(AlertApiFeature.emergencyTypes),
    );
    await expectLater(
      repository.fetchAffectedAreas(institutionId),
      _unavailable(AlertApiFeature.affectedAreas),
    );
    await expectLater(
      repository.createAlert(institutionId: institutionId),
      _unavailable(AlertApiFeature.createAlert),
    );
    await expectLater(
      repository.updateAlert(alertId: 'a'),
      _unavailable(AlertApiFeature.updateAlert),
    );
    await expectLater(
      repository.finishAlert(alertId: 'a'),
      _unavailable(AlertApiFeature.finishAlert),
    );
  });
}
