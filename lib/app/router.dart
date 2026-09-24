import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/access/domain/launcher_access.dart';
import '../features/access/presentation/access_screen.dart';
import '../features/access/presentation/launcher_access_controller.dart';
import '../features/access/presentation/launcher_home_screen.dart';
import '../features/alerts/presentation/active_alerts_screen.dart';
import '../features/alerts/presentation/alert_detail_screen.dart';
import '../features/alerts/presentation/alert_institution_screen.dart';
import '../features/alerts/presentation/emit_alert_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/session_controller.dart';
import 'status_screens.dart';

/// Rutas de la app de Lanzadores.
abstract final class AppRoutes {
  /// Restaurando sesión o consultando el estado en imSafeAPI.
  static const loading = '/loading';

  /// No se pudo consultar la sesión o el estado (red, servidor, respuesta).
  static const error = '/error';

  static const login = '/login';
  static const register = '/register';

  /// Estado de las solicitudes y solicitud de acceso a una institución.
  static const access = '/access';

  /// Inicio del lanzador autorizado (`capabilities.launcher` en la API).
  static const home = '/home';

  /// Selección de institución para emitir una alerta.
  static const alertInstitution = '/alerts/new';

  /// Emisión de una alerta en una institución concreta.
  static String alertEmit(String institutionId) =>
      '$alertInstitution/$institutionId';

  /// Prefijo de las rutas de alertas por institución.
  static const institutions = '/institutions';

  /// Alertas activas de una institución.
  static String institutionAlerts(String institutionId) =>
      '$institutions/$institutionId/alerts';

  /// Estado actual de una alerta.
  static String alertDetail(String institutionId, String alertId) =>
      '${institutionAlerts(institutionId)}/$alertId';
}

const _publicRoutes = {AppRoutes.login, AppRoutes.register};

/// Decide la pantalla a partir de la sesión y del estado que reporta
/// imSafeAPI. No concede autorización: solo refleja la respuesta de la API.
String? resolveRedirect({
  required AsyncValue<SessionStatus> session,
  required AsyncValue<LauncherAccess?> access,
  required String location,
}) {
  String? goTo(String route) => location == route ? null : route;

  if (session.hasError) return goTo(AppRoutes.error);
  final status = session.value;
  if (status == null) return goTo(AppRoutes.loading);

  if (status == SessionStatus.signedOut) {
    return _publicRoutes.contains(location) ? null : AppRoutes.login;
  }

  // Sesión presente: el estado real debe venir de imSafeAPI.
  final launcherAccess = access.value;
  if (launcherAccess == null) {
    if (access.hasError) return goTo(AppRoutes.error);
    return goTo(AppRoutes.loading);
  }

  if (launcherAccess.isAuthorizedLauncher) {
    final allowed =
        location == AppRoutes.home ||
        location == AppRoutes.access ||
        location == AppRoutes.alertInstitution ||
        location.startsWith('${AppRoutes.alertInstitution}/') ||
        location.startsWith('${AppRoutes.institutions}/');
    return allowed ? null : AppRoutes.home;
  }
  return goTo(AppRoutes.access);
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  void notify(Object? _, Object? _) => refresh.value++;
  ref.listen(sessionControllerProvider, notify);
  ref.listen(launcherAccessProvider, notify);

  final router = GoRouter(
    initialLocation: AppRoutes.loading,
    refreshListenable: refresh,
    redirect: (context, state) => resolveRedirect(
      session: ref.read(sessionControllerProvider),
      access: ref.read(launcherAccessProvider),
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.loading,
        builder: (context, state) => const LoadingScreen(),
      ),
      GoRoute(
        path: AppRoutes.error,
        builder: (context, state) => const StatusErrorScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.access,
        builder: (context, state) => const AccessScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const LauncherHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.alertInstitution,
        builder: (context, state) => const AlertInstitutionScreen(),
        routes: [
          GoRoute(
            path: ':institutionId',
            builder: (context, state) => EmitAlertScreen(
              institutionId: state.pathParameters['institutionId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '${AppRoutes.institutions}/:institutionId/alerts',
        builder: (context, state) => ActiveAlertsScreen(
          institutionId: state.pathParameters['institutionId']!,
        ),
        routes: [
          GoRoute(
            path: ':alertId',
            builder: (context, state) => AlertDetailScreen(
              institutionId: state.pathParameters['institutionId']!,
              alertId: state.pathParameters['alertId']!,
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
