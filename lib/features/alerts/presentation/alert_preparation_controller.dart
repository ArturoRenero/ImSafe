import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/presentation/launcher_access_controller.dart';
import '../data/alert_repository.dart';
import '../domain/alert_api_feature.dart';
import '../domain/alert_preparation.dart';

/// Comprueba el permiso de lanzador en la institución con los datos recién
/// consultados a imSafeAPI y carga lo necesario para preparar la alerta.
///
/// La app no concede autorización: si la API no reporta
/// `capabilities.launcher == true`, el flujo se bloquea. La API vuelve a
/// validar el permiso al emitir.
final alertPreparationProvider = FutureProvider.autoDispose
    .family<AlertPreparation, String>((ref, institutionId) async {
      final access = await ref.watch(launcherAccessProvider.future);
      final institution = access?.institutionById(institutionId);
      if (institution == null || !institution.isLauncher) {
        return AlertPreparation.permissionDenied(institution);
      }

      final alerts = ref.read(alertRepositoryProvider);
      final missing = <AlertApiFeature>[];
      for (final load in [
        alerts.fetchEmergencyTypes,
        alerts.fetchAffectedAreas,
      ]) {
        final feature = await _missingFeature(load(institutionId));
        if (feature != null) missing.add(feature);
      }
      return AlertPreparation.featureUnavailable(institution, missing);
    });

/// Traduce [AlertFeatureUnavailable] a un dato del estado; cualquier otro
/// error (red, API) se propaga como error del provider.
Future<AlertApiFeature?> _missingFeature(Future<Never> operation) async {
  try {
    await operation;
  } on AlertFeatureUnavailable catch (e) {
    return e.feature;
  }
}
