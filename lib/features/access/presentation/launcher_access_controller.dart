import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/access_dtos.dart';
import '../data/access_repository.dart';
import '../domain/launcher_access.dart';

/// Carga el perfil, las capacidades por institución y las solicitudes de
/// acceso del lanzador. `null` cuando no hay sesión.
class LauncherAccessController extends AsyncNotifier<LauncherAccess?> {
  @override
  Future<LauncherAccess?> build() async {
    final session = await ref.watch(sessionControllerProvider.future);
    if (session != SessionStatus.signedIn) return null;

    final access = ref.read(accessRepositoryProvider);
    final user = await ref.read(authRepositoryProvider).fetchMe();
    return LauncherAccess(
      user: user,
      institutions: await access.fetchMyInstitutions(),
      accessRequests: await access.fetchMyAccessRequests(),
    );
  }

  /// Vuelve a consultar el estado real en imSafeAPI. Un fallo queda en el
  /// estado del provider (conservando el último valor), no se relanza.
  Future<void> reload() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {}
  }

  /// Envía la solicitud de acceso. Lanza `ApiFailure` si la API no la
  /// confirma; no se reintenta automáticamente.
  Future<Permission> requestAccess(String institutionId) async {
    final permission = await ref
        .read(accessRepositoryProvider)
        .requestLauncherAccess(institutionId);
    ref.invalidateSelf();
    return permission;
  }
}

final launcherAccessProvider =
    AsyncNotifierProvider<LauncherAccessController, LauncherAccess?>(
      LauncherAccessController.new,
    );

/// Institución pública por id (para mostrar el nombre de una solicitud).
final institutionProvider = FutureProvider.autoDispose
    .family<Institution, String>(
      (ref, id) => ref.read(accessRepositoryProvider).fetchInstitution(id),
    );

/// Búsqueda pública de instituciones para solicitar acceso.
final institutionSearchProvider = FutureProvider.autoDispose
    .family<Page<Institution>, String>(
      (ref, query) =>
          ref.read(accessRepositoryProvider).searchInstitutions(query),
    );
