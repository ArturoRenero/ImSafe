import 'package:flutter_test/flutter_test.dart';

import 'package:imsafe_lanzadores/core/config/app_config.dart';
import 'package:imsafe_lanzadores/core/logging/app_logger.dart';

void main() {
  List<LogLevel> emittedLevels(AppEnvironment environment) {
    final emitted = <LogLevel>[];
    final logger = AppLogger(
      environment,
      sink: (level, message, error) => emitted.add(level),
    );
    logger
      ..debug('d')
      ..info('i')
      ..warning('w')
      ..error('e');
    return emitted;
  }

  test('development registra todos los niveles', () {
    expect(emittedLevels(AppEnvironment.development), LogLevel.values);
  });

  test('staging omite debug', () {
    expect(emittedLevels(AppEnvironment.staging), [
      LogLevel.info,
      LogLevel.warning,
      LogLevel.error,
    ]);
  });

  test('production solo registra warning y error', () {
    expect(emittedLevels(AppEnvironment.production), [
      LogLevel.warning,
      LogLevel.error,
    ]);
  });
}
