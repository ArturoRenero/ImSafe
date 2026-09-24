import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'secure_storage.dart';

/// Tokens de la sesión emitidos por imSafeAPI (`Tokens` en OpenAPI).
class SessionTokens {
  const SessionTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;

  /// Opaco y de uso único: reutilizarlo revoca la sesión completa.
  final String refreshToken;
}

/// Persiste los tokens de sesión exclusivamente en [SecureStorage].
///
/// Mantiene una copia en memoria para no leer el almacén seguro en cada
/// solicitud HTTP.
class TokenStore {
  TokenStore(this._storage);

  static const _accessKey = 'imsafe.session.accessToken';
  static const _refreshKey = 'imsafe.session.refreshToken';

  final SecureStorage _storage;
  SessionTokens? _cache;
  bool _loaded = false;

  Future<SessionTokens?> read() async {
    if (_loaded) return _cache;
    final access = await _storage.read(_accessKey);
    final refresh = await _storage.read(_refreshKey);
    _cache = access != null && refresh != null
        ? SessionTokens(accessToken: access, refreshToken: refresh)
        : null;
    _loaded = true;
    return _cache;
  }

  Future<void> save(SessionTokens tokens) async {
    await _storage.write(_accessKey, tokens.accessToken);
    await _storage.write(_refreshKey, tokens.refreshToken);
    _cache = tokens;
    _loaded = true;
  }

  Future<void> clear() async {
    _cache = null;
    _loaded = true;
    await _storage.delete(_accessKey);
    await _storage.delete(_refreshKey);
  }
}

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(ref.watch(secureStorageProvider)),
);
