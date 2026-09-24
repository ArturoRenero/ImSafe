# Contrato imSafeAPI usado por la app de Lanzadores

> Resumen de apoyo. **La fuente de verdad es `openapi.json`** de imSafeAPI.
> Revisado contra imSafeAPI **v0.2.0** (OpenAPI 3.0.3) el 2026-09-23.

- Base URL (production): `https://api.imsafe.tlajomulco.tecnm.mx/api/v1` (se pasa con `IMSAFE_API_BASE_URL`, nunca en el código).
- OpenAPI: `https://api.imsafe.tlajomulco.tecnm.mx/openapi.json` (`servers: [{ url: "/" }]`).
- Readiness: `GET /health/ready` → `200 {"status":"ok"}` / `503`.

## Autenticación (`securitySchemes.bearerAuth`)

- `Authorization: Bearer <accessToken>` (JWT HS256; el cliente no interpreta sus claims).
- `accessToken` dura `expiresIn` segundos (900 observado).
- `refreshToken` opaco (43 caracteres `[A-Za-z0-9_-]`), **de uso único**. Reutilizar uno ya consumido revoca toda la sesión, incluso con renovaciones concurrentes: **el cliente debe serializar la renovación**. La expiración absoluta de la sesión no se extiende.
- Los permisos se evalúan por institución en cada operación.

## Formato de error (todas las operaciones)

```json
{ "error": { "code": "string", "message": "string", "requestId": "string" } }
```

Status documentados en todas las operaciones: `400` entrada inválida · `401` autenticación, credenciales, renovación o sesión inválidas · `403` no autorizado en esta institución · `404` inexistente o de otra institución · `409` duplicado o transición incompatible · `413` cuerpo > 32 KiB · `415` codificación no admitida · `429` límite de autenticación excedido · `500` error interno.

`error.code` **no está enumerado en OpenAPI** (observados: `VALIDATION_ERROR`, `UNAUTHORIZED`, `FORBIDDEN`, `CONFLICT`). La app decide por status HTTP.

## Paginación

Query `page` (≥1, por defecto 1) y `limit` (1–100, por defecto 20). Respuesta `{ items, page, limit, total }`.

## Operaciones

| Operación | Método y ruta | Auth | Request | Response | Errores relevantes |
|---|---|---|---|---|---|
| Registro | `POST /auth/register` | No | `Register` `{name(1–120), email(≤254), password(15–128)}` | `201 User` | 400, 409 (correo ya registrado), 429 |
| Login | `POST /auth/login` | No | `Login` `{email, password(15–128)}` | `200 Tokens` | 400, 401 (credenciales), 429 |
| Renovar sesión | `POST /auth/refresh` | No | `Refresh` `{refreshToken}` | `200 Tokens` | 400, 401 (renovación/sesión inválida) |
| Logout | `POST /auth/logout` | Bearer | — | `204` | 401 |
| Perfil propio | `GET /users/me` | Bearer | — | `200 User` | 401 |
| Mis instituciones y capacidades | `GET /users/me/institutions` | Bearer | `page`, `limit` | `200 MyInstitutionPage` | 401 |
| Mis solicitudes de acceso | `GET /users/me/access-requests` | Bearer | `page`, `limit`, `status?` | `200 PermissionPage` | 401 |
| Buscar instituciones públicas | `GET /institutions` | No | `page`, `limit`, `search?` (1–100, literal) | `200 InstitutionPage` | 400 |
| Consultar institución | `GET /institutions/{institutionId}` | No | `institutionId` (24 hex) | `200 Institution` | 404 |
| Solicitar acceso como lanzador | `POST /institutions/{institutionId}/access-requests` | Bearer | `Empty` `{}` (cuerpo obligatorio) | `201 Permission` | 401, 404, 409 (ya existe solicitud pendiente o permiso aprobado) |

### Schemas

- `User`: `id`, `name`, `email`, `createdAt` (date-time).
- `Tokens`: `accessToken`, `refreshToken`, `tokenType` (`"Bearer"`), `expiresIn` (int).
- `Institution`: `_id`, `name`, `location` (`Point`), `createdAt`, `updatedAt`; opcionales `description`, `address`.
- `MyInstitution`: `Institution` + `capabilities { administrator: bool, launcher: bool }`.
- `Permission`: `_id`, `institutionId`, `userId`, `role` (`"launcher"`), `status` (`pending` | `approved` | `rejected` | `revoked`), `requestedAt`, `createdAt`, `updatedAt`; opcionales `decidedBy`, `decidedAt`, `revokedBy`, `revokedAt`, `__v`.
- `Point`: `{ type: "Point", coordinates: [longitud, latitud] }`.

## Cómo decide la app la autorización

- **Lanzador autorizado en una institución** ⇔ `MyInstitution.capabilities.launcher == true` (dato calculado por la API).
- El estado de cada solicitud se muestra con `Permission.status` tal como llega.
- La API vuelve a validar el permiso en cada operación; la app no concede ni simula autorización.

## Fuera del contrato actual (bloquea features de Lanzadores)

imSafeAPI v0.2.0 declara: *"No incluye alertas ni geolocalización."* No existen endpoints de:

- `EmergencyAlert` (crear, consultar, actualizar, finalizar).
- `IncidentReport` (consultar).
- `EmergencyType`, `Area`, instrucciones validadas.
- Idempotency keys para operaciones críticas.

Las operaciones administrativas (crear/editar institución, listar/decidir solicitudes, listar/revocar permisos) existen pero **no son de esta app**.
