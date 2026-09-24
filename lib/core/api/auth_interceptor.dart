import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_store.dart';

/// Claves de `RequestOptions.extra` usadas por [AuthInterceptor].
abstract final class AuthExtra {
  /// La operación es pública en OpenAPI (`security: []`): no se envía token.
  static const skipAuth = 'imsafe.skipAuth';

  static const _retried = 'imsafe.authRetried';
}

/// Integra Dio con `bearerAuth` de imSafeAPI.
///
/// - Añade `Authorization: Bearer <accessToken>` a las operaciones protegidas.
/// - Ante un `401`, renueva la sesión con `POST /auth/refresh` y repite UNA
///   vez la solicitud. Un 401 significa que la API rechazó la solicitud antes
///   de procesarla, por lo que repetirla no duplica ninguna operación.
/// - La renovación está serializada: el refresh token es de uso único y
///   reutilizarlo revoca toda la sesión.
/// - Si la renovación es rechazada, borra los tokens y llama a
///   [onSessionExpired]. Si falla por red, conserva los tokens y propaga el
///   error de red (no se interpreta como sesión inválida).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._dio,
    required this._tokenStore,
    required this._onSessionExpired,
  });

  final Dio _dio;
  final TokenStore _tokenStore;
  final void Function() _onSessionExpired;
  Future<_RefreshResult>? _refreshInFlight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[AuthExtra.skipAuth] != true) {
      final tokens = await _tokenStore.read();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final usedHeader = options.headers['Authorization'];
    if (err.response?.statusCode != 401 ||
        options.extra[AuthExtra.skipAuth] == true ||
        options.extra[AuthExtra._retried] == true ||
        usedHeader is! String) {
      return handler.next(err);
    }

    final result = await _refresh(usedHeader.substring('Bearer '.length));
    switch (result) {
      case _Refreshed(:final tokens):
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
        options.extra[AuthExtra._retried] = true;
        try {
          handler.resolve(await _dio.fetch<Object?>(options));
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      case _Rejected():
        handler.next(err);
      case _NotConfirmed(:final error):
        handler.next(error);
    }
  }

  Future<_RefreshResult> _refresh(String failedAccessToken) {
    return _refreshInFlight ??= _doRefresh(failedAccessToken)
        .whenComplete(() => _refreshInFlight = null);
  }

  Future<_RefreshResult> _doRefresh(String failedAccessToken) async {
    final current = await _tokenStore.read();
    if (current == null) return const _Rejected();
    // Otra solicitud ya renovó la sesión: no reutilizar el refresh token.
    if (current.accessToken != failedAccessToken) return _Refreshed(current);

    try {
      final response = await _dio.post<Object?>(
        '/auth/refresh',
        data: {'refreshToken': current.refreshToken},
        options: Options(extra: {AuthExtra.skipAuth: true}),
      );
      final tokens = parseTokens(response.data);
      await _tokenStore.save(tokens);
      return _Refreshed(tokens);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse) {
        await _tokenStore.clear();
        _onSessionExpired();
        return const _Rejected();
      }
      return _NotConfirmed(e);
    } on FormatException catch (e) {
      return _NotConfirmed(
        DioException(requestOptions: RequestOptions(), error: e),
      );
    }
  }
}

/// Interpreta el schema `Tokens` de OpenAPI.
SessionTokens parseTokens(Object? data) {
  if (data is Map &&
      data['accessToken'] is String &&
      data['refreshToken'] is String &&
      data['tokenType'] == 'Bearer') {
    return SessionTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }
  throw const FormatException('Respuesta Tokens inválida');
}

sealed class _RefreshResult {
  const _RefreshResult();
}

class _Refreshed extends _RefreshResult {
  const _Refreshed(this.tokens);
  final SessionTokens tokens;
}

class _Rejected extends _RefreshResult {
  const _Rejected();
}

class _NotConfirmed extends _RefreshResult {
  const _NotConfirmed(this.error);
  final DioException error;
}
