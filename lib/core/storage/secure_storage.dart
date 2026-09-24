import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento seguro del sistema operativo (Keychain / Keystore).
///
/// Es el único lugar donde deben persistirse credenciales o tokens de sesión.
/// Qué se guarda y con qué claves depende del contrato de sesión de imSafeAPI,
/// todavía pendiente (AGENTS.md §20). Los datos sensibles nunca van en
/// `shared_preferences`.
class SecureStorage {
  SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);
}

final secureStorageProvider = Provider<SecureStorage>(
  (ref) => SecureStorage(const FlutterSecureStorage()),
);
