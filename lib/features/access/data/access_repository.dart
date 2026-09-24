import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import 'access_dtos.dart';

/// Instituciones, capacidades y solicitudes de acceso del lanzador.
class AccessRepository {
  AccessRepository(this._api);

  static const _pageLimit = 100;

  final ApiClient _api;

  /// `GET /users/me/institutions` (todas las páginas).
  Future<List<MyInstitution>> fetchMyInstitutions() =>
      _fetchAll('/users/me/institutions', MyInstitution.fromJson);

  /// `GET /users/me/access-requests` (todas las páginas).
  Future<List<Permission>> fetchMyAccessRequests() =>
      _fetchAll('/users/me/access-requests', Permission.fromJson);

  /// `GET /institutions?search=` (pública).
  Future<Page<Institution>> searchInstitutions(String search) async {
    final data = await _api.get(
      '/institutions',
      queryParameters: {
        'limit': 20,
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
      authenticated: false,
    );
    return parseJson(data, (json) => Page.fromJson(json, Institution.fromJson));
  }

  /// `GET /institutions/{id}` (pública).
  Future<Institution> fetchInstitution(String institutionId) async {
    final data = await _api.get(
      '/institutions/$institutionId',
      authenticated: false,
    );
    return parseJson(data, Institution.fromJson);
  }

  /// `POST /institutions/{id}/access-requests` con cuerpo `{}` → `201`.
  Future<Permission> requestLauncherAccess(String institutionId) async {
    final data = await _api.post(
      '/institutions/$institutionId/access-requests',
      data: const <String, Object?>{},
    );
    return parseJson(data, Permission.fromJson);
  }

  Future<List<T>> _fetchAll<T>(
    String path,
    T Function(Map<String, Object?> json) fromItem,
  ) async {
    final items = <T>[];
    for (var page = 1; ; page++) {
      final data = await _api.get(
        path,
        queryParameters: {'page': page, 'limit': _pageLimit},
      );
      final result = parseJson(data, (json) => Page.fromJson(json, fromItem));
      items.addAll(result.items);
      if (!result.hasMore || result.items.isEmpty) return items;
    }
  }
}

final accessRepositoryProvider = Provider<AccessRepository>(
  (ref) => AccessRepository(ref.watch(apiClientProvider)),
);
