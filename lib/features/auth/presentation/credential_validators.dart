import '../data/auth_dtos.dart';

/// Validaciones previas al envío basadas en los schemas `Register`/`Login`.
/// imSafeAPI vuelve a validar todo.
String? validateName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Escribe tu nombre.';
  if (name.length > CredentialRules.nameMaxLength) {
    return 'Máximo ${CredentialRules.nameMaxLength} caracteres.';
  }
  return null;
}

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty || !email.contains('@')) return 'Escribe un correo válido.';
  if (email.length > CredentialRules.emailMaxLength) {
    return 'El correo es demasiado largo.';
  }
  return null;
}

String? validatePassword(String? value) {
  final length = value?.length ?? 0;
  if (length < CredentialRules.passwordMinLength) {
    return 'Debe tener al menos ${CredentialRules.passwordMinLength} caracteres.';
  }
  if (length > CredentialRules.passwordMaxLength) {
    return 'Máximo ${CredentialRules.passwordMaxLength} caracteres.';
  }
  return null;
}
