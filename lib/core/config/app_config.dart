import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Entornos aprobados para las apps móviles de imSafe.
enum AppEnvironment { development, staging, production }

/// Configuración pública de la app, única fuente para la URL de imSafeAPI.
///
/// Se lee en compilación mediante `--dart-define`:
/// - `IMSAFE_ENV`: `development` (por defecto), `staging` o `production`.
/// - `IMSAFE_API_BASE_URL`: URL base de imSafeAPI.
///
/// Aquí solo va configuración pública. Nunca secretos.
class AppConfig {
  const AppConfig({required this.environment, required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() => AppConfig.parse(
    environment: const String.fromEnvironment(
      'IMSAFE_ENV',
      defaultValue: 'development',
    ),
    apiBaseUrl: const String.fromEnvironment('IMSAFE_API_BASE_URL'),
  );

  /// Valida los valores recibidos. Falla de forma explícita ante una
  /// configuración inválida en lugar de arrancar con valores dudosos.
  factory AppConfig.parse({
    required String environment,
    required String apiBaseUrl,
  }) {
    final env = AppEnvironment.values.asNameMap()[environment];
    if (env == null) {
      throw ArgumentError.value(
        environment,
        'IMSAFE_ENV',
        'Debe ser development, staging o production',
      );
    }

    if (apiBaseUrl.isEmpty) {
      return AppConfig(environment: env, apiBaseUrl: null);
    }

    final uri = Uri.tryParse(apiBaseUrl);
    final allowedSchemes = env == AppEnvironment.development
        ? const {'http', 'https'}
        : const {'https'};
    if (uri == null ||
        !uri.hasAuthority ||
        !allowedSchemes.contains(uri.scheme)) {
      throw ArgumentError.value(
        apiBaseUrl,
        'IMSAFE_API_BASE_URL',
        'Debe ser una URL absoluta (${allowedSchemes.join('/')}) '
            'para ${env.name}',
      );
    }
    return AppConfig(environment: env, apiBaseUrl: uri);
  }

  final AppEnvironment environment;

  /// `null` mientras no se haya configurado la URL de imSafeAPI.
  final Uri? apiBaseUrl;
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
