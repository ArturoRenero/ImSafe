import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/auth_interceptor.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/storage/token_store.dart';
import 'auth_dtos.dart';

/// Operaciones `auth` y `users/me` de imSafeAPI.
class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  Future<bool> hasStoredSession() async => await _tokens.read() != null;

  /// `POST /auth/register` → `201 User`. No inicia sesión por sí mismo.
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _api.post(
      '/auth/register',
      data: {'name': name, 'email': email, 'password': password},
      authenticated: false,
    );
    return parseJson(data, User.fromJson);
  }

  /// `POST /auth/login` → `200 Tokens`, guardados en almacenamiento seguro.
  Future<void> login({required String email, required String password}) async {
    final data = await _api.post(
      '/auth/login',
      data: {'email': email, 'password': password},
      authenticated: false,
    );
    final SessionTokens tokens;
    try {
      tokens = parseTokens(data);
    } on FormatException {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    await _tokens.save(tokens);
  }

  /// `GET /users/me` → `200 User`.
  Future<User> fetchMe() async =>
      parseJson(await _api.get('/users/me'), User.fromJson);

  /// `POST /auth/logout` → `204`. Los tokens locales se borran siempre, aunque
  /// la API no confirme la revocación; en ese caso se relanza el error para
  /// que la UI pueda informarlo.
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } finally {
      await _tokens.clear();
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  ),
);
