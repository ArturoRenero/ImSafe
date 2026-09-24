/// Lectura estricta de campos JSON. Un campo requerido ausente o de otro tipo
/// lanza [FormatException] (traducida a `ApiFailureKind.invalidResponse`).
extension JsonRead on Map<String, Object?> {
  String requireString(String key) => _require<String>(key);

  String? optionalString(String key) => _optional<String>(key);

  bool requireBool(String key) => _require<bool>(key);

  int requireInt(String key) => _require<int>(key);

  DateTime requireDateTime(String key) => _parseDate(key, requireString(key));

  DateTime? optionalDateTime(String key) {
    final value = optionalString(key);
    return value == null ? null : _parseDate(key, value);
  }

  Map<String, Object?> requireObject(String key) =>
      _require<Map<String, Object?>>(key);

  List<Object?> requireList(String key) => _require<List<Object?>>(key);

  T _require<T>(String key) {
    final value = this[key];
    if (value is T) return value;
    throw FormatException('Campo "$key" ausente o inválido');
  }

  T? _optional<T>(String key) {
    final value = this[key];
    if (value == null || value is T) return value as T?;
    throw FormatException('Campo "$key" inválido');
  }

  DateTime _parseDate(String key, String value) =>
      DateTime.tryParse(value) ??
      (throw FormatException('Campo "$key" no es date-time'));
}
