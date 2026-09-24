import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/presentation/launcher_access_controller.dart';
import '../data/alert_dtos.dart';
import '../data/alert_repository.dart';
import '../domain/alert_preparation.dart';

/// Catálogo controlado de tipos de emergencia (`GET /emergency-types`).
final emergencyTypesProvider = FutureProvider.autoDispose<List<EmergencyType>>(
  (ref) => ref.read(alertRepositoryProvider).fetchEmergencyTypes(),
);

/// Comprueba el permiso de lanzador en la institución con los datos recién
/// consultados a imSafeAPI y carga el catálogo de tipos de emergencia.
///
/// La app no concede autorización: si la API no reporta
/// `capabilities.launcher == true`, el flujo se bloquea. La API vuelve a
/// validar el permiso al emitir (403).
final alertPreparationProvider = FutureProvider.autoDispose
    .family<AlertPreparation, String>((ref, institutionId) async {
      final access = await ref.watch(launcherAccessProvider.future);
      final institution = access?.institutionById(institutionId);
      if (institution == null || !institution.isLauncher) {
        return AlertPreparation.permissionDenied(institution);
      }
      final types = await ref.watch(emergencyTypesProvider.future);
      return AlertPreparation.ready(institution, types);
    });

/// Alertas activas de una institución.
final activeAlertsProvider = FutureProvider.autoDispose
    .family<List<InstitutionAlert>, String>(
      (ref, institutionId) =>
          ref.read(alertRepositoryProvider).fetchActiveAlerts(institutionId),
    );

typedef AlertRef = ({String institutionId, String alertId});

/// Estado actual de una alerta según la API.
final alertProvider = FutureProvider.autoDispose
    .family<InstitutionAlert, AlertRef>(
      (ref, id) => ref
          .read(alertRepositoryProvider)
          .fetchAlert(id.institutionId, id.alertId),
    );

/// Distribución del último evento de una alerta.
final alertDeliveryProvider = FutureProvider.autoDispose
    .family<AlertDeliveryStatus, AlertRef>(
      (ref, id) => ref
          .read(alertRepositoryProvider)
          .fetchDeliveryStatus(id.institutionId, id.alertId),
    );
