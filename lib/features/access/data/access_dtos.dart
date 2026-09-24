import '../../../core/utils/json_read.dart';

/// Schema `Institution` de imSafeAPI (solo los campos que usa esta app).
class Institution {
  const Institution({
    required this.id,
    required this.name,
    this.description,
    this.address,
  });

  factory Institution.fromJson(Map<String, Object?> json) => Institution(
    id: json.requireString('_id'),
    name: json.requireString('name'),
    description: json.optionalString('description'),
    address: json.optionalString('address'),
  );

  final String id;
  final String name;
  final String? description;
  final String? address;
}

/// Schema `MyInstitution`: institución con las capacidades del usuario.
class MyInstitution {
  const MyInstitution({
    required this.institution,
    required this.isAdministrator,
    required this.isLauncher,
  });

  factory MyInstitution.fromJson(Map<String, Object?> json) {
    final capabilities = json.requireObject('capabilities');
    return MyInstitution(
      institution: Institution.fromJson(json),
      isAdministrator: capabilities.requireBool('administrator'),
      isLauncher: capabilities.requireBool('launcher'),
    );
  }

  final Institution institution;

  /// `capabilities.administrator`.
  final bool isAdministrator;

  /// `capabilities.launcher`: la API autoriza a este usuario como lanzador.
  final bool isLauncher;
}

/// Enum `Permission.status` de imSafeAPI.
enum PermissionStatus {
  pending,
  approved,
  rejected,
  revoked;

  static PermissionStatus parse(String value) =>
      PermissionStatus.values.asNameMap()[value] ??
      (throw FormatException('Permission.status desconocido: $value'));
}

/// Schema `Permission`: solicitud de acceso como lanzador y su historial.
class Permission {
  const Permission({
    required this.id,
    required this.institutionId,
    required this.status,
    required this.requestedAt,
    this.decidedAt,
    this.revokedAt,
  });

  factory Permission.fromJson(Map<String, Object?> json) {
    final role = json.requireString('role');
    if (role != 'launcher') {
      throw FormatException('Permission.role desconocido: $role');
    }
    return Permission(
      id: json.requireString('_id'),
      institutionId: json.requireString('institutionId'),
      status: PermissionStatus.parse(json.requireString('status')),
      requestedAt: json.requireDateTime('requestedAt'),
      decidedAt: json.optionalDateTime('decidedAt'),
      revokedAt: json.optionalDateTime('revokedAt'),
    );
  }

  final String id;
  final String institutionId;
  final PermissionStatus status;
  final DateTime requestedAt;
  final DateTime? decidedAt;
  final DateTime? revokedAt;
}

/// Envoltura paginada `{ items, page, limit, total }` de imSafeAPI.
class Page<T> {
  const Page({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  factory Page.fromJson(
    Map<String, Object?> json,
    T Function(Map<String, Object?> json) fromItem,
  ) => Page(
    items: [
      for (final item in json.requireList('items'))
        if (item is Map<String, Object?>)
          fromItem(item)
        else
          throw const FormatException('Elemento de página inválido'),
    ],
    page: json.requireInt('page'),
    limit: json.requireInt('limit'),
    total: json.requireInt('total'),
  );

  final List<T> items;
  final int page;
  final int limit;
  final int total;

  bool get hasMore => page * limit < total;
}
