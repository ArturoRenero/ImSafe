# Contrato imSafeAPI usado por la app de Lanzadores

> Resumen de apoyo. **La fuente de verdad es `openapi.json`** de imSafeAPI.
> Versión vigente: imSafeAPI **0.4.0** según el equipo de backend (2026-09-24). `openapi.json` todavía
> declara `info.version: "0.3.0"` y una descripción que dice "No incluye alertas", pero **ya publica
> las operaciones de alertas** documentadas abajo. Backend debe actualizar `info`.
>
> Etiquetas usadas en este documento:
> - **IMPLEMENTADO EN API**: existe en `openapi.json` y se probó contra la API real.
> - **PENDIENTE EN BACKEND**: la app lo necesita y la API todavía no lo ofrece.
> - **PROPUESTA / POR DEFINIR**: preguntas abiertas; nada de esto es un contrato.

- Base URL (production): `https://api.imsafe.tlajomulco.tecnm.mx/api/v1` (se pasa con `IMSAFE_API_BASE_URL`, nunca en el código).
- OpenAPI: `https://api.imsafe.tlajomulco.tecnm.mx/openapi.json` (`servers: [{ url: "/" }]`).
- Administración web: `https://imsafe.tlajomulco.tecnm.mx`.
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

## Operaciones — IMPLEMENTADO EN API

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

## Autorización: `administrator` vs `launcher` — IMPLEMENTADO EN API

- `MyInstitution.capabilities` trae dos banderas independientes calculadas por la API:
  - `administrator`: administra la institución (operaciones de la administración web, no de esta app).
  - `launcher`: la API autoriza al usuario como lanzador en esa institución.
- **`launcher == true` es obligatorio para intentar crear una alerta.** `administrator == true` **no**
  implica `launcher`; la API no lo documenta y la app no lo asume.
- La app solo refleja lo que reporta la API (`GET /users/me/institutions`, consultado de nuevo al entrar
  al flujo); no concede ni simula permisos. Al emitir, la API volverá a validar el permiso (403 si no).
- El estado de cada solicitud se muestra con `Permission.status` tal como llega.

## Cartografía — IMPLEMENTADO EN API (no la usa esta app)

| Operación | Método y ruta | Auth |
|---|---|---|
| Manifiesto de zonas seguras | `GET /api/v2/institutions/{institutionId}/cartography/published` | No |
| Publicación de zonas seguras | `GET /api/v2/institutions/{institutionId}/cartography/publications/{version}` | No |

- **v2 es la versión vigente** (perímetro + `SafeArea`: `id`, `name`, `type` ∈ {cancha, estacionamiento,
  patio, otro}, `geometry`; coordenadas `[longitud, latitud]`).
- Existen también rutas v1 (`/api/v1/.../cartography/...`, solo perímetro). **Backend debe confirmar**
  si las apps deben ignorarlas; esta app no usa ninguna de las dos.
- **Las `SafeArea` son zonas seguras, no áreas afectadas de una alerta.** La API indica que *"no expresa
  aprobación para tipos de emergencia"*.
- Mapas, zonas seguras y su caché pertenecen a la app de usuarios finales; Lanzadores no los implementa.
- Las operaciones administrativas (crear/editar institución, decidir solicitudes, revocar permisos,
  editar/publicar cartografía) existen pero **no son de esta app**.

## Alertas — IMPLEMENTADO EN API (0.4.0)

| Operación | Método y ruta | Auth | Request | Response |
|---|---|---|---|---|
| Catálogo de tipos | `GET /emergency-types` | Bearer | — | `200 EmergencyTypes` |
| Emitir alerta | `POST /institutions/{institutionId}/alerts` | Bearer + `Idempotency-Key` | `AlertCreate` | `202 AlertAccepted` |
| Alertas vigentes / historial | `GET /institutions/{institutionId}/alerts?state=&page=&limit=` | Bearer | `state` ∈ {active, closed, cancelled, expired} | `200 InstitutionAlertPage` (+ `serverTime`) |
| Estado actual | `GET /institutions/{institutionId}/alerts/{alertId}` | Bearer | — | `200 InstitutionAlert` |
| Actualizar mensaje | `PATCH /institutions/{institutionId}/alerts/{alertId}` | Bearer + `Idempotency-Key` | `AlertUpdate` `{expectedRevision, message}` | `202 AlertAccepted` |
| Finalizar o cancelar | `POST /institutions/{institutionId}/alerts/{alertId}/transitions` | Bearer + `Idempotency-Key` | `AlertTransition` `{expectedRevision, state: closed\|cancelled, reason}` | `202 AlertAccepted` |
| Distribución del último evento | `GET /institutions/{institutionId}/alerts/{alertId}/delivery-status` | Bearer | — | `200 AlertDeliveryStatus` |

Existe también `GET .../alerts/{alertId}/events` (auditoría privada); esta app todavía no la usa.

### Schemas relevantes

- `EmergencyTypes`: `{schemaVersion: 1, items: [{type, label, durationMinutes ∈ {30,60,120,240}, requiresDescription}]}`.
  Catálogo **global y controlado por la API** (hoy: sismo, incendio, inundacion, fuga_gas, otro). La app
  preselecciona `sismo` si el catálogo lo incluye (AGENTS.md §8.1) y no fija otros tipos en código.
- `AlertCreate`: `{type, message(1–1000, ≤1800 bytes)}`; si el tipo tiene `requiresDescription` (hoy `otro`)
  además `otherDescription(1–160, ≤480 bytes)`. **No existe campo de áreas afectadas.**
- `AlertAccepted`: `{alertId, eventId, acceptedRevision, acceptedAt}` — aceptada y persistida;
  **distribución pendiente**.
- `InstitutionAlert`: `id, institutionId, type, otherDescription?, message, state, revision, createdAt,
  updatedAt, expiresAt, endedAt?, lastEventId`.
- `AlertDeliveryStatus`: `outboxState ∈ {pending, done, superseded, expired}`, `fanoutComplete`,
  `counts {pending, accepted, failed, skipped, received, opened}`. `accepted` = aceptación del proveedor,
  no entrega; `received/opened` son acuses autodeclarados.

### Reglas del backend que la app respeta

- Solo un `launcher` aprobado puede emitir; un administrador sin `launcher` no puede (403).
- **Una alerta activa por institución y tipo** (`409 ACTIVE_ALERT_EXISTS`).
- `Idempotency-Key` (UUID) obligatoria en comandos: repetir la **misma** operación/cuerpo/clave no la
  duplica; otra carga con la misma clave → `409 IDEMPOTENCY_CONFLICT`.
- `expectedRevision` en actualizar/finalizar/cancelar (`409 REVISION_CONFLICT`); estados terminales no se
  reactivan (`409 INVALID_TRANSITION`, `ALERT_EXPIRED`).
- `400 NOTIFICATION_TOO_LARGE` si el payload de notificación supera 4096 bytes.

### Cómo lo usa la app

- La clave de idempotencia se genera por comando y se **guarda en el almacenamiento seguro del teléfono
  antes de enviarlo** (AGENTS.md §14). Si el resultado no se confirmó (timeout, red) o el servidor falló
  (5xx), la clave sobrevive al cierre de la pantalla o de la app; al reabrir la emisión se recupera el
  mismo contenido y repetirlo reutiliza la clave. Se borra con `202` o un rechazo 4xx; un comando
  distinto usa clave nueva. **Nunca hay reintento automático.**
- Doble envío bloqueado: el botón se deshabilita y un segundo envío en curso se ignora.
- Una operación solo se muestra como aceptada con `202 AlertAccepted`; la pantalla indica que la
  distribución sigue pendiente. Tras cada comando se vuelve a consultar el estado real.
- Lanzadores **no** envía FCM ni contiene credenciales de Firebase: el backend distribuye.

## Dispositivos receptores — NO ES DE ESTA APP

`/devices/...` (registro anónimo, credencial `dev_...`, suscripciones, acuses) pertenece a la app de
usuarios finales. Lanzadores no registra dispositivos ni usa `installationBearer`.

## PENDIENTE EN BACKEND / POR DEFINIR

- **Institución de pruebas**: al trasladar la API (2026-10-22) se eliminaron las instituciones y cuentas
  anteriores. La institución de pruebas vigente es «imSafe — Pruebas» (`6adaaa308e45f34e56961ec6`).
  Las alertas quedan registradas y visibles por HTTP aunque FCM esté deshabilitado, y no existe `dryRun`:
  emitir solo en instituciones de pruebas o presentaciones, nunca en instituciones reales.
- **Distribución en el servidor nuevo**: `POST /devices` responde `503 DEVICES_NOT_CONFIGURED` (falta
  `PUSH_TOKEN_ENCRYPTION_KEY`) y el outbox de las alertas permanece `pending` (el trabajador de
  notificaciones no procesa eventos). Las alertas se registran, pero no llegan a ningún teléfono.
- `info.version`/`info.description` de OpenAPI desactualizados (dicen 0.3.0 y "No incluye alertas").
- Áreas afectadas: **omitidas por ahora por decisión del usuario** (AGENTS.md §8.3); retomarlas requiere
  contrato del backend.
- Cartografía v1 vs v2: confirmar si las apps deben ignorar v1.
