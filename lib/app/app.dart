import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';

/// Desactiva el reintento automático de providers de Riverpod 3: todo
/// reintento hacia imSafeAPI debe ser explícito (acción del usuario).
Duration? noAutomaticRetry(int retryCount, Object error) => null;

/// Raíz de la aplicación imSafe para lanzadores de alertas.
///
/// Debe ejecutarse dentro de un `ProviderScope` (ver `main.dart`).
class ImSafeApp extends ConsumerWidget {
  const ImSafeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'imSafe',
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
