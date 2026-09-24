import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/auth_repository.dart';

enum SessionStatus { signedOut, signedIn }

/// Estado de la sesión local.
///
/// `signedIn` solo indica que hay tokens guardados; su validez la confirma
/// imSafeAPI en la primera solicitud protegida. Si la API rechaza la
/// renovación, el estado pasa a `signedOut`.
class SessionController extends AsyncNotifier<SessionStatus> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<SessionStatus> build() async {
    final subscription = ref
        .watch(sessionExpiredEventsProvider)
        .stream
        .listen((_) => state = const AsyncData(SessionStatus.signedOut));
    ref.onDispose(subscription.cancel);

    return await _repository.hasStoredSession()
        ? SessionStatus.signedIn
        : SessionStatus.signedOut;
  }

  /// Lanza `ApiFailure` si la API no confirma el inicio de sesión.
  Future<void> login({required String email, required String password}) async {
    await _repository.login(email: email, password: password);
    state = const AsyncData(SessionStatus.signedIn);
  }

  /// Registra la cuenta y, si la API la crea, inicia sesión con ella.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _repository.register(name: name, email: email, password: password);
    await login(email: email, password: password);
  }

  /// Cierra la sesión localmente siempre; relanza el error si la API no
  /// confirmó la revocación.
  Future<void> logout() async {
    try {
      await _repository.logout();
    } finally {
      state = const AsyncData(SessionStatus.signedOut);
    }
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionStatus>(
      SessionController.new,
    );
