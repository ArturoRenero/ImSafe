# Contrato imSafeAPI usado por la app de Lanzadores

> Resumen de apoyo. **La fuente de verdad es `openapi.json`** de imSafeAPI.
> Versión real vigente: imSafeAPI **v0.3.0** (OpenAPI 3.0.3), verificada el 2026-09-24.
>
> Etiquetas usadas en este documento:
> - **IMPLEMENTADO EN API**: existe en `openapi.json` y se probó contra la API real.
> - **PENDIENTE EN BACKEND**: la app lo necesita y la API todavía no lo ofrece.
> - **PROPUESTA / POR DEFINIR**: preguntas abiertas; nada de esto es un contrato.

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

## Alertas — PENDIENTE EN BACKEND

imSafeAPI v0.3.0 declara: *"No incluye alertas ni geolocalización."* Revisión completa de `openapi.json`
(paths y `components.schemas`): no existe ninguna de estas operaciones.

| Operación que necesita Lanzadores | Estado |
|---|---|
| Consultar tipos de emergencia disponibles para una institución | PENDIENTE EN BACKEND |
| Consultar áreas afectadas / alcance de difusión seleccionables | PENDIENTE EN BACKEND |
| Crear (emitir) una alerta | PENDIENTE EN BACKEND |
| Consultar el estado vigente de una alerta | PENDIENTE EN BACKEND |
| Actualizar una alerta | PENDIENTE EN BACKEND |
| Finalizar una alerta | PENDIENTE EN BACKEND |
| Idempotencia / `dryRun` / institución de pruebas | PENDIENTE EN BACKEND |

Flujo acordado (sin FCM en Lanzadores):

1. Lanzadores **solicita** la creación de la alerta a imSafeAPI con su JWT (HTTPS).
2. imSafeAPI **valida el permiso** (`launcher`) y **registra** la alerta.
3. imSafeAPI **distribuye** las notificaciones a usuarios finales (FCM u otro mecanismo del backend).

La app de Lanzadores **no** envía FCM, **no** contiene Firebase Admin SDK ni credenciales de Firebase.
Una alerta registrada por la API, una notificación enviada a FCM y una alerta recibida por un dispositivo
son estados distintos; la app solo puede afirmar lo que la API confirme.

Estado en la app: el flujo *Generar alerta* existe (selección de institución, validación de `launcher`,
pantalla de preparación), pero `AlertRepository` falla con `AlertFeatureUnavailable` **sin hacer
solicitudes HTTP** y la pantalla no permite enviar nada.

## Contrato que debe definir backend — PROPUESTA / POR DEFINIR

Nada de lo siguiente es un contrato; son las preguntas que cada operación debe responder en OpenAPI.

**Tipos de emergencia**
- ¿Catálogo global o por institución? Ruta, paginación, campos de cada tipo.
- Cómo se identifica *sismo* para ofrecerlo como opción predeterminada (AGENTS.md §8.1).
- Qué tipos exigen áreas afectadas y cuáles cubren toda la institución.

**Áreas afectadas / alcance de difusión**
- De dónde salen (no son `SafeArea`), cómo se relacionan con el perímetro y con áreas contiguas
  (AGENTS.md §8.3). Si el lanzador elige áreas o solo el tipo (el diagrama del backend solo menciona
  institución y tipo).

**Crear alerta**
- Método, ruta, cuerpo (institución, tipo, áreas, instrucciones breves) y respuesta (id, estado,
  hora de emisión, emisor).
- Instrucciones breves (AGENTS.md §8.2): ¿las elige el lanzador de un catálogo validado o las resuelve la API?
- Estados posibles de una alerta y sus transiciones.
- Significado de `403` (sin `launcher`), `409` (¿alerta activa duplicada?) y demás códigos.
- Idempotencia: cabecera/clave o decisión explícita de no reintentar.
- Si la respuesta distingue "registrada" de "distribución solicitada".

**Consultar / actualizar / finalizar alerta**
- Rutas, campos modificables, estados permitidos para cada transición, auditoría.

**Pruebas**
- Institución de pruebas, `dryRun` o destinatarios controlados para probar el POST real sin notificar a
  usuarios reales. Hoy no existe: "Tecnologico de Morelia" (propuesta como institución de prueba) tiene
  nombre de institución real y no hay instituciones que coincidan con "prueba"/"test".
