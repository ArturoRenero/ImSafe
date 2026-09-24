import '../../access/data/access_dtos.dart';
import '../data/alert_dtos.dart';

enum AlertPreparationStatus {
  /// imSafeAPI no reporta `capabilities.launcher == true` para la institución.
  permissionDenied,

  /// Permiso de lanzador reportado y catálogo de tipos cargado.
  ready,
}

/// Situación del formulario de emisión en una institución.
///
/// Carga y error se representan con `AsyncValue`, como en el resto de la app.
class AlertPreparation {
  const AlertPreparation.permissionDenied(this.institution)
    : status = AlertPreparationStatus.permissionDenied,
      emergencyTypes = const [];

  const AlertPreparation.ready(
    MyInstitution this.institution,
    this.emergencyTypes,
  ) : status = AlertPreparationStatus.ready;

  final AlertPreparationStatus status;

  /// `null` si imSafeAPI no reporta la institución entre las del usuario.
  final MyInstitution? institution;

  final List<EmergencyType> emergencyTypes;

  /// Sismo si el catálogo lo incluye (AGENTS.md §8.1); si no, ninguno.
  EmergencyType? get defaultType => emergencyTypes
      .where((t) => t.type == EmergencyType.earthquake)
      .firstOrNull;
}
