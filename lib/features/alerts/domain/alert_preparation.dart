import '../../access/data/access_dtos.dart';
import 'alert_api_feature.dart';

enum AlertPreparationStatus {
  /// imSafeAPI no reporta `capabilities.launcher == true` para la institución.
  permissionDenied,

  /// El lanzador está autorizado, pero imSafeAPI aún no publica lo necesario
  /// para preparar y enviar la alerta.
  featureUnavailable,
}

/// Situación de la preparación de una alerta en una institución.
///
/// Carga y error se representan con `AsyncValue`, como en el resto de la app.
/// No existe todavía un estado "lista para enviar": requiere el contrato de
/// alertas de imSafeAPI.
class AlertPreparation {
  const AlertPreparation.permissionDenied(this.institution)
    : status = AlertPreparationStatus.permissionDenied,
      missingFeatures = const [];

  const AlertPreparation.featureUnavailable(
    MyInstitution this.institution,
    this.missingFeatures,
  ) : status = AlertPreparationStatus.featureUnavailable;

  final AlertPreparationStatus status;

  /// `null` si imSafeAPI no reporta la institución entre las del usuario.
  final MyInstitution? institution;

  final List<AlertApiFeature> missingFeatures;
}
