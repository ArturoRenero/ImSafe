import '../../../core/utils/json_read.dart';

/// Schema `User` de imSafeAPI.
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, Object?> json) => User(
    id: json.requireString('id'),
    name: json.requireString('name'),
    email: json.requireString('email'),
    createdAt: json.requireDateTime('createdAt'),
  );

  final String id;
  final String name;
  final String email;
  final DateTime createdAt;
}

/// Límites del schema `Register`/`Login` de imSafeAPI, usados para validar
/// el formulario antes de enviarlo. La API vuelve a validarlos.
abstract final class CredentialRules {
  static const nameMaxLength = 120;
  static const emailMaxLength = 254;
  static const passwordMinLength = 15;
  static const passwordMaxLength = 128;
}
