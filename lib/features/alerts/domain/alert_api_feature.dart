/// Operaciones de alertas que necesita esta app y que imSafeAPI todavía no
/// publica (v0.3.0). Ver `docs/API_CONTRACT_LANZADORES.md`, sección de
/// pendientes en backend.
enum AlertApiFeature {
  emergencyTypes,
  affectedAreas,
  createAlert,
  updateAlert,
  finishAlert,
}

/// imSafeAPI no ofrece [feature]. Se lanza sin hacer ninguna solicitud HTTP:
/// no existe una ruta real a la que llamar.
class AlertFeatureUnavailable implements Exception {
  const AlertFeatureUnavailable(this.feature);

  final AlertApiFeature feature;

  @override
  String toString() => 'AlertFeatureUnavailable(${feature.name})';
}
