import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/alert_api_feature.dart';

/// Operaciones de alertas de imSafeAPI.
///
/// imSafeAPI v0.3.0 no publica endpoints de alertas, tipos de emergencia ni
/// áreas afectadas. Cada operación falla con [AlertFeatureUnavailable] sin
/// hacer ninguna solicitud: no se inventan rutas ni cuerpos JSON. Cuando exista
/// el contrato, este repositorio recibirá el `ApiClient` y los DTO derivados de
/// OpenAPI, y los tipos de retorno dejarán de ser `Never`.
class AlertRepository {
  const AlertRepository();

  /// Tipos de emergencia configurados para la institución.
  Future<Never> fetchEmergencyTypes(String institutionId) =>
      _unavailable(AlertApiFeature.emergencyTypes);

  /// Áreas que el lanzador puede seleccionar como afectadas. No son las
  /// `SafeArea` de cartografía (zonas seguras).
  Future<Never> fetchAffectedAreas(String institutionId) =>
      _unavailable(AlertApiFeature.affectedAreas);

  /// Emisión de una alerta. El resto de los datos se definirá con el contrato.
  Future<Never> createAlert({required String institutionId}) =>
      _unavailable(AlertApiFeature.createAlert);

  Future<Never> updateAlert({required String alertId}) =>
      _unavailable(AlertApiFeature.updateAlert);

  Future<Never> finishAlert({required String alertId}) =>
      _unavailable(AlertApiFeature.finishAlert);

  static Future<Never> _unavailable(AlertApiFeature feature) =>
      Future.error(AlertFeatureUnavailable(feature));
}

final alertRepositoryProvider = Provider<AlertRepository>(
  (ref) => const AlertRepository(),
);
