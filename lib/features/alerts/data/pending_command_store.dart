import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage.dart';
import '../domain/alert_command.dart';

typedef PendingCommand = ({AlertCommand command, String key});

/// Guarda en el teléfono el comando crítico pendiente de confirmar y su
/// `Idempotency-Key` (AGENTS.md §14): se escribe antes de enviarlo y se
/// borra cuando la API lo acepta o lo rechaza. Así, repetir el mismo comando
/// tras cerrar la pantalla o la app reutiliza la clave y no lo duplica.
class PendingCommandStore {
  PendingCommandStore(this._storage);

  final SecureStorage _storage;

  static String _storageKey(String scope) => 'imsafe.alerts.pending.$scope';

  /// `null` si no hay comando pendiente o el guardado no se reconoce.
  Future<PendingCommand?> read(String scope) async {
    final raw = await _storage.read(_storageKey(scope));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      return (
        command: _decode(json['command']! as Map<String, Object?>),
        key: json['key']! as String,
      );
    } on Object {
      await _storage.delete(_storageKey(scope));
      return null;
    }
  }

  Future<void> write(String scope, PendingCommand pending) => _storage.write(
    _storageKey(scope),
    jsonEncode({'key': pending.key, 'command': _encode(pending.command)}),
  );

  Future<void> delete(String scope) => _storage.delete(_storageKey(scope));

  static Map<String, Object?> _encode(AlertCommand command) =>
      switch (command) {
        EmitAlert() => {
          'kind': 'emit',
          'institutionId': command.institutionId,
          'type': command.type,
          'message': command.message,
          'otherDescription': command.otherDescription,
        },
        UpdateAlertMessage() => {
          'kind': 'update',
          'institutionId': command.institutionId,
          'alertId': command.alertId,
          'expectedRevision': command.expectedRevision,
          'message': command.message,
        },
        TransitionAlert() => {
          'kind': 'transition',
          'institutionId': command.institutionId,
          'alertId': command.alertId,
          'expectedRevision': command.expectedRevision,
          'target': command.target.name,
          'reason': command.reason,
        },
      };

  static AlertCommand _decode(Map<String, Object?> json) =>
      switch (json['kind']) {
        'emit' => EmitAlert(
          institutionId: json['institutionId']! as String,
          type: json['type']! as String,
          message: json['message']! as String,
          otherDescription: json['otherDescription'] as String?,
        ),
        'update' => UpdateAlertMessage(
          institutionId: json['institutionId']! as String,
          alertId: json['alertId']! as String,
          expectedRevision: json['expectedRevision']! as int,
          message: json['message']! as String,
        ),
        'transition' => TransitionAlert(
          institutionId: json['institutionId']! as String,
          alertId: json['alertId']! as String,
          expectedRevision: json['expectedRevision']! as int,
          target: AlertTransitionTarget.values.byName(
            json['target']! as String,
          ),
          reason: json['reason']! as String,
        ),
        _ => throw const FormatException('Comando pendiente desconocido'),
      };
}

final pendingCommandStoreProvider = Provider<PendingCommandStore>(
  (ref) => PendingCommandStore(ref.watch(secureStorageProvider)),
);
