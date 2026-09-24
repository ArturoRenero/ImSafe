import 'package:flutter_test/flutter_test.dart';

import 'package:imsafe_lanzadores/core/config/app_config.dart';

void main() {
  group('AppConfig.parse', () {
    test('reconoce los tres entornos', () {
      for (final env in AppEnvironment.values) {
        final config = AppConfig.parse(environment: env.name, apiBaseUrl: '');
        expect(config.environment, env);
      }
    });

    test('rechaza un entorno desconocido', () {
      expect(
        () => AppConfig.parse(environment: 'prod', apiBaseUrl: ''),
        throwsArgumentError,
      );
    });

    test('URL vacía queda sin configurar', () {
      final config = AppConfig.parse(
        environment: 'development',
        apiBaseUrl: '',
      );
      expect(config.apiBaseUrl, isNull);
    });

    test('development acepta http', () {
      final config = AppConfig.parse(
        environment: 'development',
        apiBaseUrl: 'http://10.0.2.2:3000',
      );
      expect(config.apiBaseUrl, Uri.parse('http://10.0.2.2:3000'));
    });

    test('staging y production exigen https', () {
      for (final env in ['staging', 'production']) {
        expect(
          () => AppConfig.parse(
            environment: env,
            apiBaseUrl: 'http://api.example.test',
          ),
          throwsArgumentError,
        );
        expect(
          AppConfig.parse(
            environment: env,
            apiBaseUrl: 'https://api.example.test',
          ).apiBaseUrl,
          isNotNull,
        );
      }
    });

    test('rechaza URLs no absolutas', () {
      expect(
        () => AppConfig.parse(environment: 'development', apiBaseUrl: 'api'),
        throwsArgumentError,
      );
    });
  });
}
