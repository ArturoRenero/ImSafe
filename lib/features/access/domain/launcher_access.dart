import '../../auth/data/auth_dtos.dart';
import '../data/access_dtos.dart';

/// Situación de acceso del lanzador tal como la reporta imSafeAPI.
class LauncherAccess {
  const LauncherAccess({
    required this.user,
    required this.institutions,
    required this.accessRequests,
  });

  final User user;
  final List<MyInstitution> institutions;
  final List<Permission> accessRequests;

  /// Instituciones donde la API reporta `capabilities.launcher == true`.
  List<MyInstitution> get launcherInstitutions =>
      institutions.where((i) => i.isLauncher).toList();

  bool get isAuthorizedLauncher => launcherInstitutions.isNotEmpty;

  /// Institución del usuario con ese id, o `null` si la API no la reporta.
  MyInstitution? institutionById(String institutionId) =>
      institutions.where((i) => i.institution.id == institutionId).firstOrNull;

  /// Solicitudes que impiden crear otra para la misma institución según
  /// OpenAPI: una pendiente o un permiso aprobado.
  bool hasOpenRequestFor(String institutionId) => accessRequests.any(
    (r) =>
        r.institutionId == institutionId &&
        (r.status == PermissionStatus.pending ||
            r.status == PermissionStatus.approved),
  );
}
