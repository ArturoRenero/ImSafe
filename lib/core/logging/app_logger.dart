import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

enum LogLevel { debug, info, warning, error }

typedef LogSink = void Function(LogLevel level, String message, Object? error);

/// Logger dependiente del entorno.
///
/// - development: todos los niveles.
/// - staging: info en adelante.
/// - production: solo warning y error.
///
/// Nunca pasar a este logger contraseñas, tokens, secretos, datos personales
/// innecesarios ni el contenido de reportes de incidentes.
class AppLogger {
  AppLogger(this.environment, {LogSink? sink}) : _sink = sink ?? _developerLog;

  final AppEnvironment environment;
  final LogSink _sink;

  LogLevel get minimumLevel => switch (environment) {
    AppEnvironment.development => LogLevel.debug,
    AppEnvironment.staging => LogLevel.info,
    AppEnvironment.production => LogLevel.warning,
  };

  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warning(String message) => _log(LogLevel.warning, message);
  void error(String message, [Object? error]) =>
      _log(LogLevel.error, message, error);

  void _log(LogLevel level, String message, [Object? error]) {
    if (level.index < minimumLevel.index) return;
    _sink(level, message, error);
  }

  static void _developerLog(LogLevel level, String message, Object? error) {
    developer.log(
      message,
      name: 'imSafe',
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
      error: error,
    );
  }
}

final appLoggerProvider = Provider<AppLogger>(
  (ref) => AppLogger(ref.watch(appConfigProvider).environment),
);
