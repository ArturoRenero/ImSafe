# AGENTS.md — imSafe | App móvil para lanzadores de alertas

## 1. Propósito de este archivo

Este archivo define el contexto, alcance, reglas funcionales, restricciones y decisiones técnicas confirmadas para desarrollar la **aplicación móvil de imSafe destinada a lanzadores de alertas**.

Debe ser utilizado como referencia compartida por **ChatGPT**, **Claude Code** y cualquier otro agente que participe en el desarrollo.

El objetivo es evitar que distintos agentes inventen requisitos, cambien el alcance o tomen decisiones críticas sin aprobación del usuario.

---

## 2. Fuente de verdad y jerarquía de decisiones

La fuente funcional principal del proyecto es el documento de alcance de **imSafe — Sistema de alertas y orientación ante emergencias** proporcionado por el usuario.

Para esta etapa, el usuario ha añadido y confirmado estas decisiones:

- Se desarrollará específicamente la **aplicación móvil para lanzadores de alertas**.
- La interfaz móvil se desarrollará con **Flutter**.
- La aplicación deberá ser **multiplataforma: Android e iOS**.
- La aplicación consumirá una API central llamada **imSafeAPI**.
- La API se desarrollará con **Node.js + Express**.
- La persistencia principal utilizará **MongoDB**.
- La aplicación debe buscar una experiencia **amigable, clara e intuitiva**.
- ChatGPT y Claude Code trabajarán de forma coordinada sobre el mismo alcance.

### Orden de prioridad

Cuando exista una contradicción, los agentes deberán aplicar este orden:

1. Instrucciones explícitas más recientes del usuario.
2. Documento funcional de imSafe proporcionado por el usuario.
3. Este archivo `AGENTS.md`.
4. Convenciones técnicas del proyecto ya aprobadas.
5. Sugerencias técnicas de los agentes.

Las sugerencias técnicas nunca pueden modificar automáticamente los niveles 1 a 4.

---

## 3. Regla principal para los agentes

**No inventar funcionalidades, requisitos, actores, permisos, reglas de negocio, estados, endpoints, campos de base de datos, automatizaciones ni integraciones que no estén aprobadas.**

Si un agente considera conveniente realizar un cambio importante o incorporar algo no especificado, deberá detener la implementación de ese cambio y presentar al usuario:

1. **Qué se propone cambiar o agregar.**
2. **Por qué se propone.**
3. **Para qué serviría.**
4. **Qué funcionalidad aportaría.**
5. **Qué impacto tendría en Flutter, API, base de datos, seguridad o experiencia de usuario.**
6. **Qué alternativas existen**, cuando sean relevantes.

El cambio solo podrá incorporarse después de que el usuario lo acepte.

No se debe convertir una recomendación técnica en un requisito aprobado sin autorización.

---

## 4. Contexto general de imSafe

imSafe es una plataforma de apoyo a la gestión de emergencias dentro de instituciones como centros educativos, edificios administrativos y otros recintos.

Su función es complementar los mecanismos oficiales de alertamiento y los protocolos institucionales de protección civil.

**imSafe no sustituye:**

- Alertas gubernamentales.
- Señalización física.
- Simulacros.
- Indicaciones de protección civil.
- Instrucciones de servicios de emergencia.

El MVP completo de imSafe contempla cuatro componentes:

1. Administración web.
2. Aplicación móvil para lanzadores de alertas.
3. Aplicación móvil para usuarios finales.
4. API central `imSafeAPI`.

### Alcance actual de desarrollo

En esta etapa, el trabajo se concentra en:

- **App móvil para lanzadores de alertas.**
- Integración de esta app con **imSafeAPI**.
- Definición de los contratos de API necesarios para soportar las funciones de esta app, siempre respetando el alcance funcional existente.

El hecho de que la API atienda en el futuro a las demás interfaces no autoriza a desarrollar funciones adicionales de esas aplicaciones durante esta etapa, salvo que sean estrictamente necesarias para soportar el flujo aprobado de la app de lanzadores.

---

## 5. Stack tecnológico confirmado

### Aplicación móvil

- Framework: **Flutter**.
- Lenguaje principal: **Dart**.
- Plataformas objetivo: **Android e iOS**.

### Backend

- Runtime: **Node.js**.
- Framework HTTP: **Express**.
- API: **imSafeAPI**.

### Base de datos

- **MongoDB**.

### Regla de acceso a datos

La aplicación Flutter **no debe conectarse directamente a MongoDB**.

El flujo esperado es:

`Flutter App -> imSafeAPI (Node.js + Express) -> MongoDB`

La API es responsable de validar autenticación, autorización, reglas de negocio y operaciones críticas antes de acceder o modificar datos.

---

## 5.1 Estándar técnico compartido entre las apps móviles de imSafe

Esta sección formaliza el estándar aprobado para mantener coherencia técnica entre la app móvil de **lanzadores de alertas** y la app móvil de **usuarios finales**, sin fusionar sus responsabilidades ni sus flujos funcionales.

### Regla de separación

Ambas aplicaciones deben compartir convenciones técnicas, nomenclatura conceptual y criterios de calidad, pero cada repositorio conserva su propio alcance y su propio `AGENTS.md`.

No se deben copiar automáticamente entre aplicaciones:

- flujos de autenticación;
- permisos o roles;
- pantallas específicas del actor;
- endpoints o DTOs definitivos;
- reglas de negocio exclusivas;
- configuración de notificaciones push específica de una app.

La app de lanzadores **crea, actualiza y finaliza alertas**, consulta reportes y requiere autenticación/autorización para operaciones críticas. La app de usuarios finales **consulta/recibe alertas y crea reportes**, y no requiere cuenta en su MVP.

### Arquitectura Flutter común

Se adopta una arquitectura **feature-first** con separación ligera por capas, evitando una Clean Architecture rígida o abstracciones sin uso real.

Estructura de referencia:

```text
lib/
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme/
├── core/
│   ├── api/
│   ├── config/
│   ├── errors/
│   ├── logging/
│   ├── storage/
│   └── utils/
├── features/
│   └── <feature>/
│       ├── data/
│       ├── domain/
│       └── presentation/
└── shared/
    ├── models/
    └── widgets/
```

Principios obligatorios:

- La UI no realiza llamadas HTTP directamente.
- La UI no accede directamente a almacenamiento, permisos, GPS ni servicios externos.
- Los DTO de API no se mezclan con widgets ni con lógica visual.
- Las abstracciones deben existir porque resuelven una necesidad real, no para completar capas vacías.
- La estructura puede crecer por feature sin duplicar infraestructura transversal.

### Estado e inyección de dependencias

El estándar común utiliza **Riverpod (`flutter_riverpod`)** como estrategia principal de manejo de estado e inyección de dependencias.

Cadena de dependencias esperada:

`Dio -> ApiClient -> Repositories -> Controllers/Notifiers -> UI`

No introducir una segunda librería general de DI ni otra estrategia principal de estado sin una decisión explícita del equipo.

### Cliente HTTP

El estándar común utiliza **Dio** para centralizar:

- URL base;
- headers;
- timeouts;
- serialización;
- interceptores;
- autenticación cuando aplique;
- traducción consistente de errores.

No crear instancias de Dio dispersas por features ni llamadas HTTP dentro de widgets.

### Navegación

El estándar común utiliza **`go_router`**.

La herramienta es compartida, pero el grafo de navegación es específico de cada app. En este repositorio debe respetar los flujos de sesión, solicitud de acceso, autorización y operación del lanzador. No copiar el grafo de navegación de usuarios finales.

### Configuración y entornos

Ambas apps deben contemplar los entornos:

- `development`;
- `staging`;
- `production`.

La configuración pública debe estar centralizada y no duplicarse entre features. Los secretos no deben incluirse en el repositorio ni compilarse como si fueran configuración pública.

### Autenticación y almacenamiento

Para la app de lanzadores, las credenciales o tokens de sesión que deban persistirse en el dispositivo deben almacenarse mediante almacenamiento seguro del sistema operativo, usando una solución como **`flutter_secure_storage`**.

Esto no define todavía:

- formato del JWT;
- claims;
- expiración;
- refresh token;
- rotación;
- política concreta de sesión.

Esos detalles siguen pendientes de contrato con imSafeAPI. `shared_preferences` puede utilizarse únicamente para preferencias o datos locales no sensibles.

### imSafeAPI como fuente de verdad

Se mantiene como flujo obligatorio:

`Flutter App -> imSafeAPI (Node.js + Express) -> MongoDB`

Los DTO deben derivarse del contrato real de imSafeAPI/OpenAPI cuando exista. No deben derivarse del esquema interno de MongoDB ni inventarse para completar pantallas.

No inventar como definitivos:

- endpoints;
- payloads;
- campos JSON;
- códigos HTTP;
- estados;
- claims de autenticación.

### Nomenclatura y modelos conceptuales compartidos

Cuando un mismo concepto exista en ambas aplicaciones, debe utilizarse la misma terminología conceptual. Como base compartida:

- `Institution`;
- `Area`;
- `EmergencyType`;
- `EmergencyAlert`;
- `IncidentReport`.

Compartir el concepto no significa compartir exactamente el mismo DTO o todas sus operaciones. `EmergencyAlert` e `IncidentReport` se consumen de manera distinta según el actor.

En lanzadores:

- `EmergencyAlert`: crear, consultar, actualizar y finalizar según autorización.
- `IncidentReport`: consultar y evaluar; nunca convertir automáticamente en alerta.

### Errores y estados remotos

Toda feature que dependa de datos remotos debe representar de forma comprensible los estados relevantes, por ejemplo: inicial, carga, éxito, vacío cuando aplique y error.

Un error de red no debe interpretarse como ausencia de datos. Las operaciones críticas no pueden mostrarse como exitosas hasta que imSafeAPI las confirme.

### Operaciones críticas, reintentos y offline

No implementar silenciosamente colas offline, reintentos automáticos de operaciones críticas ni duplicación de solicitudes. Para emisión, actualización o finalización de alertas, cualquier estrategia de reintento debe coordinarse con una estrategia de idempotencia aprobada en backend.

### Logging

El logging debe variar por entorno. Nunca registrar en producción:

- contraseñas;
- JWT completos;
- refresh tokens;
- secretos;
- datos personales innecesarios;
- información sensible de reportes sin necesidad.

### Pruebas y validación

Ambos repositorios deben mantener el mismo criterio mínimo de calidad:

- pruebas unitarias para lógica y parsing relevante;
- widget tests para estados principales;
- pruebas de integración para flujos críticos cuando sea viable;
- `dart format .`;
- `flutter analyze`;
- `flutter test`.

Una tarea no está terminada si solo compila pero rompe el contrato funcional, omite estados de error relevantes o deja pruebas relacionadas fallando.

### Responsive, accesibilidad y sistema visual

La UI compartirá principios de diseño y componentes reutilizables donde tenga sentido:

- claridad y jerarquía visual;
- `SafeArea`;
- layouts adaptables con `LayoutBuilder`, `MediaQuery`, `Expanded`, `Flexible` y constraints cuando corresponda;
- texto escalable;
- áreas táctiles cómodas;
- contraste suficiente;
- no depender únicamente del color;
- tokens/tema centralizado para evitar estilos dispersos.

La identidad compartida puede trabajar con la familia visual ya acordada de rojo, café, beige y neutros, pero los valores exactos de color, tipografía y componentes finales deberán mantenerse centralizados y no inventarse por pantalla.

### Push

La existencia de push en la app de usuarios finales no autoriza a copiar automáticamente Firebase/FCM a la app de lanzadores. El servicio y comportamiento de notificaciones push para lanzadores continúa pendiente hasta que exista una necesidad funcional y una decisión explícita.

### Regla de evolución del estándar

Si una decisión técnica compartida cambia, debe actualizarse el estándar en **ambos** `AGENTS.md` para evitar divergencias. Si el cambio afecta solo a uno de los actores, debe documentarse únicamente en el repositorio correspondiente y no presentarse como estándar común.

---

## 6. Actor principal de esta aplicación

El actor principal es el **lanzador de alertas**.

Una persona lanzadora deberá poder:

- Crear una cuenta.
- Solicitar acceso a una institución.
- Esperar la aprobación correspondiente.
- Operar como lanzador únicamente después de haber sido autorizada.
- Emitir alertas.
- Consultar información relacionada con las alertas que deba manejar.
- Consultar reportes de incidentes enviados por usuarios finales.
- Evaluar esos reportes conforme a los protocolos institucionales.
- Actualizar una alerta cuando el flujo aprobado lo requiera.
- Finalizar una alerta.

La aprobación o revocación de permisos corresponde al componente de administración de la institución, no a la propia app del lanzador.

---

## 7. Control de acceso

Las operaciones críticas deberán exigir autenticación y autorización.

Un usuario sin autorización vigente **no debe poder emitir, modificar ni finalizar alertas**.

La aplicación deberá reflejar correctamente la situación de acceso del usuario, pero los nombres exactos de estados, códigos, claims, roles o permisos todavía no están definidos y no deben inventarse sin aprobación.

La autorización efectiva deberá validarse en la API; no debe depender únicamente de restricciones visibles en la interfaz Flutter.

---

## 8. Gestión de alertas

### 8.1 Creación de alertas

Un lanzador autorizado podrá iniciar una alerta.

La interfaz deberá ofrecer **sismo como opción predeterminada**.

Para otros incidentes, deberá permitir seleccionar:

- Tipo de emergencia.
- Áreas afectadas cuando aplique.

Ejemplos contemplados por el documento funcional:

- Incendio.
- Inundación.
- Fuga de gas.
- Otro evento configurado por la institución.

No se debe convertir esta lista de ejemplos en una enumeración cerrada dentro del código si la institución puede configurar otros tipos de evento.

### 8.2 Información mínima de una alerta

Cada alerta deberá contener, como mínimo:

- Institución.
- Tipo de emergencia.
- Áreas afectadas: **omitidas por ahora** (ver §8.3).
- Instrucciones breves.
- Hora de emisión.
- Estado.
- Persona emisora.

Los identificadores internos, nombres exactos de propiedades JSON y estructura final de MongoDB aún deben definirse durante el diseño de la API.

### 8.3 Alcance de difusión

El lanzador podrá seleccionar el tipo de emergencia y, cuando corresponda, las áreas afectadas y el alcance de difusión permitido por la configuración institucional.

La configuración general de imSafe puede permitir que una alerta abarque:

- Áreas seleccionadas.
- Áreas contiguas como margen de seguridad.
- La institución completa.

La app del lanzador no debe inventar reglas geográficas propias. Deberá respetar las reglas y configuraciones entregadas por imSafeAPI.

**Decisión del usuario (2026-09-24):** imSafeAPI 0.4.0 no contempla áreas afectadas ni alcance de difusión en la alerta (`AlertCreate` solo admite tipo, mensaje y, cuando el tipo lo exige, descripción). Por ahora la app de lanzadores **omite la selección de áreas afectadas**. Retomarla requiere que el backend publique ese contrato y una nueva aprobación del usuario. Las `SafeArea` de cartografía son zonas seguras y nunca se usan como áreas afectadas.

### 8.4 Actualización y finalización

Los lanzadores autorizados podrán actualizar o finalizar una alerta conforme al flujo establecido por la institución y la API.

No se debe tratar una alerta como finalizada únicamente porque el usuario cierre la aplicación, cambie de pantalla o pierda conexión.

El estado real deberá provenir del backend.

---

## 9. Reportes de incidentes

Los usuarios finales pueden enviar reportes de incidentes a los lanzadores autorizados.

El reporte puede incluir:

- Institución.
- Área o ubicación aproximada seleccionada.
- Tipo de incidente.
- Descripción breve.
- Hora de envío.

Ejemplos de tipos de incidentes mencionados en el alcance:

- Incendio.
- Olor a gas.
- Inundación.
- Persona lesionada.
- Otro.

### Regla crítica

**Un reporte no debe activar automáticamente una alerta general.**

El flujo correcto es:

1. El usuario final envía el reporte.
2. El reporte llega a los lanzadores autorizados.
3. Un lanzador lo consulta y evalúa.
4. De acuerdo con los protocolos institucionales, el lanzador decide si corresponde emitir una alerta.
5. Si procede, la alerta se crea mediante el flujo autorizado de emisión.

No implementar automatizaciones que conviertan reportes directamente en alertas sin una futura decisión expresa del usuario y una revisión de seguridad.

---

## 10. Auditoría y trazabilidad

El sistema deberá registrar las acciones relacionadas con alertas.

Como mínimo, la arquitectura debe permitir trazabilidad de:

- Emisión de alertas.
- Modificación de alertas.
- Finalización de alertas.

También deberá conservar marcas de tiempo y estados relevantes para alertas y reportes.

La estructura exacta del registro de auditoría aún no está aprobada. No definir silenciosamente campos, retención, formato o almacenamiento separado sin discutirlo cuando dicha decisión afecte la arquitectura.

---

## 11. Geolocalización y áreas

La ubicación móvil en imSafe es **orientativa** y no debe tratarse como una medición precisa de posición interior.

El sistema general distingue entre:

- Área reportada por el usuario.
- Ubicación aproximada del dispositivo.
- Área afectada por una emergencia.

La app de lanzadores utilizará las áreas y configuraciones proporcionadas por la API para determinar qué puede seleccionar el lanzador al crear una alerta.

No se deben implementar en este MVP:

- Detección exacta de salón mediante GPS.
- Detección exacta de planta mediante GPS.
- Posicionamiento interior preciso mediante infraestructura especializada.
- Cálculo automático de rutas de evacuación en tiempo real.

---

## 12. Instrucciones y zonas seguras

Las instrucciones y zonas seguras dependen del tipo y lugar del incidente.

Una zona considerada segura para un tipo de emergencia puede no ser adecuada para otro.

La aplicación del lanzador no debe generar por IA, deducir ni improvisar instrucciones de emergencia o zonas seguras.

Debe utilizar información institucional previamente configurada y validada, o la información que el flujo aprobado permita seleccionar/consultar desde la API.

No afirmar que una ruta o ubicación es segura si esa información no ha sido validada institucionalmente.

---

## 13. Reglas de interfaz para una aplicación de emergencia

La UI debe priorizar:

- Claridad.
- Legibilidad.
- Confirmación del estado real de las operaciones.
- Reducción de acciones ambiguas.
- Acceso rápido a las funciones principales de alertamiento y consulta de reportes.

Una acción crítica no debe mostrarse como exitosa antes de recibir confirmación válida de la API.

No se deben introducir interacciones visuales que puedan hacer creer al lanzador que una alerta fue emitida, actualizada o finalizada si el backend no confirmó la operación.

Los detalles concretos de diseño visual, navegación, colores, componentes y sistema de diseño deberán definirse durante la implementación sin alterar las reglas funcionales de este documento.

---

## 14. Conectividad y manejo de fallos

El proyecto deberá contemplar escenarios de conectividad intermitente y operaciones no completadas.

Para acciones críticas, la aplicación deberá distinguir al menos conceptualmente entre:

- Solicitud en proceso.
- Operación confirmada por la API.
- Error o falta de confirmación.

No se deberá implementar silenciosamente una cola offline que emita una alerta más tarde, reintentos automáticos peligrosos o duplicación de operaciones críticas sin aprobar primero su comportamiento exacto.

**Idempotencia y reintentos (aprobado 2026-09-24):**

- imSafeAPI exige `Idempotency-Key` (UUID) en emitir, actualizar y finalizar/cancelar, y `expectedRevision` en actualizar y finalizar/cancelar.
- La app genera una clave por comando y la **guarda en el almacenamiento seguro del teléfono antes de enviarlo**. Si el resultado no se confirmó (red, timeout) o el servidor falló (5xx), la clave se conserva aunque se cierre la pantalla o la app; repetir **el mismo** comando la reutiliza y la API no lo duplica.
- La clave se descarta cuando la API acepta el comando (`202`) o lo rechaza (4xx). Un comando distinto usa una clave nueva.
- No hay reintentos automáticos ni cola offline: repetir es siempre una acción explícita del lanzador.

La estrategia de caché y comportamiento offline sigue pendiente de diseño.

---

## 15. Responsabilidades de imSafeAPI para esta app

La API central deberá soportar, dentro del alcance relacionado con la aplicación de lanzadores:

- Autenticación de lanzadores.
- Autorización de lanzadores.
- Solicitudes de acceso a instituciones.
- Consulta de la institución y configuración necesaria para operar.
- Consulta de tipos de emergencia configurados cuando corresponda.
- Consulta de áreas relevantes (omitida por ahora; ver §8.3).
- Emisión de alertas autorizadas.
- Consulta del estado vigente de alertas.
- Actualización de alertas.
- Finalización de alertas.
- Consulta de reportes de incidentes.
- Registro de auditoría de acciones críticas.

Los nombres, rutas HTTP, cuerpos JSON, códigos de respuesta y esquema de autenticación de los endpoints **no están definidos todavía**.

No inventarlos como contratos definitivos sin una fase de diseño y aprobación.

---

## 16. Modelo de datos: conceptos confirmados

Los siguientes conceptos existen en el alcance funcional y pueden utilizarse como base para el modelado futuro:

- Usuario administrador.
- Lanzador de alertas.
- Solicitud de acceso de un lanzador.
- Institución.
- Perímetro institucional.
- Área.
- Área contigua o relación equivalente de cobertura.
- Edificio.
- Planta, cuando exista.
- Croquis o plano.
- Zona segura.
- Punto de reunión.
- Tipo de emergencia.
- Instrucciones validadas.
- Alerta.
- Destinatarios o alcance de difusión.
- Reporte de incidente.
- Notificación.
- Registro de auditoría.

Esta lista **no es un esquema MongoDB** y no obliga a que cada concepto sea una colección independiente.

La forma exacta de documentos, referencias, embebidos, índices y validaciones deberá proponerse y aprobarse antes de tratarla como definitiva.

---

## 17. Seguridad y privacidad

Deben respetarse como mínimo las siguientes reglas:

- Exigir autenticación y autorización para emitir, actualizar o finalizar alertas.
- Proteger las operaciones críticas.
- Mantener trazabilidad de alertas y reportes.
- Minimizar datos personales cuando sea posible.
- No interpretar la recepción de una notificación como prueba de que alguien la leyó o está a salvo.
- Mantener prioridad de las indicaciones oficiales y del personal de protección civil.
- No utilizar el sistema como reemplazo de números o servicios oficiales de emergencia.

Las decisiones concretas sobre tokens, sesiones, cifrado, almacenamiento seguro de credenciales, expiraciones y mecanismos antiabuso deben definirse antes de implementarlas como arquitectura definitiva.

---

## 18. Funciones fuera del alcance del MVP

No implementar en esta etapa, salvo nueva aprobación explícita:

- Integración directa con alertas gubernamentales de sismo.
- Integración con otros sistemas oficiales de alertamiento.
- Apertura forzada automática de la app a partir de alertas gubernamentales.
- Posicionamiento interior preciso por balizas, Wi-Fi u otra infraestructura especializada.
- Cálculo automático de rutas de evacuación en tiempo real.

También deberá evitarse cualquier funcionalidad adicional no respaldada por el alcance actual aunque técnicamente parezca útil.

---

## 19. Criterios funcionales del MVP relevantes para esta app

Para esta etapa, el desarrollo deberá contribuir a cumplir al menos estos criterios:

- Una institución puede aprobar lanzadores mediante el sistema correspondiente.
- Un lanzador autorizado puede emitir una alerta de sismo.
- Un lanzador autorizado puede emitir una alerta localizada de otro tipo cuando corresponda.
- Un lanzador autorizado puede finalizar una alerta.
- Un lanzador autorizado puede consultar reportes de incidentes.
- Consultar un reporte no provoca automáticamente una alerta general.
- La API conserva el estado vigente de las alertas.
- Las operaciones críticas tienen autorización y trazabilidad.

Los criterios que pertenecen exclusivamente a la app de usuario final o a la administración web no deben trasladarse artificialmente a esta aplicación.

---

## 20. Decisiones técnicas aún pendientes

El estándar técnico compartido de la sección 5.1 ya define arquitectura Flutter, Riverpod, Dio, `go_router`, estructura general por features, entornos, criterios de logging/pruebas y almacenamiento seguro para credenciales persistentes. Esos puntos **ya no deben tratarse como decisiones abiertas**.

Continúan pendientes y no deben escogerse silenciosamente:

- Mecanismo concreto de autenticación de imSafeAPI.
- Formato, claims, duración, renovación y revocación de sesiones/tokens.
- Estructura exacta de endpoints REST.
- Convenciones definitivas de respuestas y errores de API.
- Esquemas exactos de MongoDB.
- Índices de MongoDB.
- Estrategia y estructura exacta de auditoría.
- Caché local y funcionamiento offline.
- Servicio y comportamiento de notificaciones push para lanzadores.
- Manejo de secretos del backend e infraestructura.
- Hosting/despliegue de la API.
- Herramientas concretas de observabilidad del backend.
- Diseño visual final: valores exactos de tokens, tipografías y componentes.

Un agente puede **proponer** opciones para estos puntos, pero debe explicar sus implicaciones antes de convertirlas en decisiones del proyecto.

---

## 21. Protocolo para propuestas de arquitectura

Cuando sea necesario tomar una decisión pendiente, el agente deberá presentar una propuesta breve en el siguiente formato:

### Propuesta

**Decisión necesaria:** qué debe decidirse.

**Por qué:** motivo técnico o funcional.

**Para qué:** problema que resuelve dentro de imSafe.

**Opción recomendada:** tecnología o enfoque sugerido.

**Alternativas:** otras opciones razonables, si existen.

**Impacto:** archivos, Flutter, API, MongoDB, seguridad y/o UX que serían afectados.

**¿Es crítica?:** sí/no.

Si la decisión es crítica o cambia el comportamiento funcional, se deberá esperar aprobación del usuario antes de implementarla.

---

## 22. Reglas de desarrollo para ChatGPT y Claude Code

### Antes de programar

1. Leer este `AGENTS.md`.
2. Identificar qué requisito aprobado se está implementando.
3. Revisar si la tarea requiere una decisión pendiente.
4. Si implica una decisión crítica no aprobada, proponerla antes de implementarla.

### Durante la implementación

- Mantener cambios pequeños y relacionados con la tarea actual.
- No modificar archivos sin necesidad.
- No refactorizar áreas no relacionadas solo por preferencia del agente.
- No cambiar contratos aprobados sin avisar.
- No eliminar validaciones de seguridad para simplificar el desarrollo.
- No colocar secretos, contraseñas, tokens privados o credenciales en el repositorio.
- No conectar Flutter directamente a MongoDB.
- No confiar exclusivamente en validaciones del cliente para permisos críticos.
- No marcar una operación crítica como exitosa sin confirmación del backend.
- Mantener nombres y conceptos coherentes con imSafe.

### Después de implementar

Cada agente deberá indicar:

- Qué cambió.
- Qué archivos cambió.
- Qué requisito cubre.
- Cómo probarlo.
- Qué queda pendiente.
- Si apareció alguna decisión nueva que requiera aprobación.

---

## 23. Coordinación entre ChatGPT y Claude Code

El proyecto se trabajará de forma colaborativa.

### ChatGPT

Puede utilizarse principalmente para:

- Analizar el alcance.
- Diseñar flujos.
- Revisar arquitectura.
- Proponer contratos de API.
- Revisar código y decisiones de Claude Code.
- Crear documentación.
- Detectar contradicciones con los requisitos.
- Ayudar a depurar errores.
- Preparar instrucciones precisas para Claude Code.

### Claude Code

Puede utilizarse principalmente para:

- Inspeccionar el repositorio.
- Crear y modificar archivos del proyecto.
- Implementar funcionalidades aprobadas.
- Ejecutar comandos, pruebas y validaciones disponibles en el entorno.
- Reportar cambios realizados y problemas encontrados.

### Regla de sincronización

Ningún agente debe asumir que una propuesta realizada en otro chat fue aprobada si la decisión no aparece en:

- El código actual.
- Este archivo.
- Documentación aprobada del proyecto.
- Una instrucción explícita del usuario compartida con el agente.

Cuando una decisión importante sea aprobada, deberá actualizarse `AGENTS.md` para mantener ambos agentes sincronizados.

---

## 24. Reglas para trabajar con Git

Los agentes deben favorecer cambios fáciles de revisar.

Antes de realizar modificaciones amplias, se debe conocer el estado actual del repositorio.

Buenas prácticas esperadas:

- No borrar trabajo existente sin autorización.
- No sobrescribir archivos importantes sin revisarlos.
- Mantener commits relacionados con una función o corrección concreta cuando el flujo de trabajo del usuario lo permita.
- Evitar incluir archivos de configuración con secretos.
- Documentar cambios relevantes.

La estrategia exacta de ramas, nombres de commits, CI/CD y protección de ramas todavía no se considera definida.

---

## 25. Definición de terminado para una tarea

Una tarea no se considera terminada únicamente porque compile.

Cuando sea aplicable, debe cumplirse lo siguiente:

- Implementa el requisito solicitado y nada ajeno sin aprobación.
- Respeta permisos y reglas de negocio.
- Maneja estados de carga y error necesarios para no confundir operaciones críticas.
- No expone secretos.
- No rompe funcionalidades existentes conocidas.
- Puede explicarse cómo probarla.
- Se documentaron las decisiones nuevas relevantes.

---

## 26. Regla especial sobre emergencias

Este sistema participa en un contexto sensible.

Por ello:

- No presentar suposiciones como información validada de protección civil.
- No generar rutas de evacuación improvisadas.
- No inventar zonas seguras.
- No emitir automáticamente una alerta a partir de un reporte.
- No asumir que una notificación recibida significa que una persona está a salvo.
- No presentar imSafe como sustituto de mecanismos oficiales.
- Mantener claras las diferencias entre una operación solicitada y una operación confirmada por el backend.

---

## 27. Estado actual del proyecto para los agentes

### Confirmado

- Producto: `imSafe`.
- Módulo actual: aplicación móvil para lanzadores de alertas.
- Frontend móvil: Flutter/Dart.
- Plataformas: Android/iOS.
- Backend: Node.js + Express.
- Base de datos: MongoDB.
- Comunicación con datos: a través de imSafeAPI.
- Alertas emitidas únicamente por personal autorizado.
- Sismo como opción predeterminada en la interfaz de emisión.
- Selección de áreas afectadas omitida por ahora: imSafeAPI 0.4.0 no la contempla (§8.3).
- Contrato de alertas publicado en imSafeAPI 0.4.0 (ver `docs/API_CONTRACT_LANZADORES.md`).
- Idempotencia de operaciones críticas: `Idempotency-Key` persistida en el teléfono, sin reintentos automáticos (§14).
- Los lanzadores consultan reportes y deciden si corresponde emitir una alerta.
- Los reportes no generan alertas masivas automáticamente.
- Las operaciones críticas requieren autenticación, autorización y auditoría.
- Estándar Flutter compartido aprobado: feature-first con capas ligeras `data/domain/presentation`.
- Estado/DI: Riverpod.
- HTTP: Dio.
- Navegación: `go_router`.
- Entornos: development/staging/production.
- Persistencia sensible de sesión: almacenamiento seguro del sistema operativo; detalles del token siguen pendientes.

### Aún por diseñar/aprobar

Consultar la sección **20. Decisiones técnicas aún pendientes** antes de asumir cualquier elección técnica no documentada.

---

## 28. Instrucción final para cualquier agente

Antes de agregar algo que no esté explícitamente respaldado por los requisitos actuales, preguntarse:

> ¿Esto fue solicitado o aprobado por el usuario, o lo estoy agregando porque me parece conveniente?

Si la respuesta es la segunda, debe tratarse como **propuesta**, no como requisito ni implementación automática.

El objetivo no es construir la aplicación con la mayor cantidad posible de funciones, sino construir correctamente el alcance aprobado de **imSafe** y evolucionarlo mediante decisiones conscientes del usuario.