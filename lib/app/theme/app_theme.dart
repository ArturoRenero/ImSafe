import 'package:flutter/material.dart';

/// Tema central de la app.
///
/// La familia visual acordada es rojo, café, beige y neutros, pero sus valores
/// exactos aún no están definidos (AGENTS.md §20). Mientras tanto se usa el
/// tema Material por defecto; los tokens se definirán aquí, nunca por pantalla.
abstract final class AppTheme {
  static ThemeData light() => ThemeData(useMaterial3: true);
}
