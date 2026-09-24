# imSafe — Sistema de alertas y orientación ante emergencias

## 1. Propósito

imSafe es una plataforma de apoyo a la gestión de emergencias dentro de instituciones, como centros educativos, edificios administrativos y otros recintos. Su propósito es que las personas presentes en una institución reciban avisos oportunos, consulten un croquis con zonas seguras previamente definidas y sigan instrucciones breves establecidas por los responsables de protección civil de la institución.

A diferencia de una alerta sonora genérica, imSafe incorpora contexto local: identifica aproximadamente la institución en la que se encuentra el dispositivo y presenta información pertinente al tipo de emergencia y a las áreas afectadas. También permite que cualquier usuario de la aplicación reporte incidentes a los responsables autorizados.

imSafe es un sistema **complementario** a los mecanismos oficiales de alertamiento y a los protocolos institucionales de protección civil. No sustituye las alertas gubernamentales, la señalización física, los simulacros ni las instrucciones de los servicios de emergencia.

## 2. Alcance de la primera versión (MVP)

La primera versión se centra en alertas **emitidas por personal autorizado de una institución** y en la recepción de reportes de incidentes de sus usuarios. Incluye cuatro componentes: administración web, aplicación móvil para lanzadores de alertas, aplicación móvil para usuarios finales y API central.

### 2.1 Administración web

Una persona administradora podrá:

- Crear su cuenta y registrar una institución con datos generales y ubicación.
- Delimitar en un mapa el perímetro aproximado de la institución y sus áreas, incluidos edificios y espacios exteriores.
- Registrar zonas seguras, puntos de reunión y croquis o planos por edificio o planta cuando estén disponibles y hayan sido validados por la institución.
- Asociar indicaciones breves a cada tipo de emergencia, área y zona segura. Las indicaciones y puntos seguros deben ser revisados por responsables de protección civil.
- Revisar y aprobar o rechazar solicitudes de personas que deseen lanzar alertas; revocar permisos cuando corresponda.
- Consultar alertas activas, su historial y los reportes de incidentes recibidos.
- Configurar qué áreas pueden recibir cada tipo de alerta, con posibilidad de incluir áreas contiguas como margen de seguridad.

### 2.2 Aplicación móvil para lanzadores de alertas

Las personas autorizadas podrán crear una cuenta, solicitar acceso a una institución y, tras su aprobación, emitir y finalizar alertas. La interfaz ofrecerá sismo como opción predeterminada; para otros incidentes permitirá seleccionar tipo de emergencia y áreas afectadas (por ejemplo, incendio, inundación, fuga de gas u otro evento configurado).

Cada alerta incluirá, al menos, institución, tipo, áreas afectadas cuando aplique, instrucciones breves, hora de emisión, estado y persona emisora. El sistema registrará las acciones realizadas. Los lanzadores podrán consultar reportes de incidentes de usuarios finales y decidir, de acuerdo con los protoc
olos institucionales, si corresponde emitir una alerta.

### 2.3 Aplicación móvil para usuarios finales

No requerirá crear una cuenta. Con el permiso de ubicación, utilizará las coordenadas **aproximadas** del dispositivo para identificar una institución cercana o aquella en la que probablemente se encuentra. Si hay varias instituciones posibles o la ubicación es imprecisa, permitirá seleccionar manualmente la institución.

La aplicación mostrará el croquis institucional, las áreas identificadas y las zonas seguras previamente validadas. No intentará determinar con precisión el salón, el edificio o la planta mediante GPS. El usuario podrá elegir manualmente su edificio, planta o área cuando esa información sea necesaria y esté disponible.

Al recibir una alerta dirigida a su institución o a un conjunto de áreas que pueda incluir su ubicación, presentará una notificación de emergencia destacada y acceso inmediato al croquis e instrucciones pertinentes. **Se priorizará la cobertura ante la duda:** una alerta puede distribuirse a áreas contiguas o a toda la institución, según su configuración. No se excluirá a una persona únicamente porque su GPS indique un área adyacente.

También podrá **reportar incidentes** a los lanzadores autorizados, sin iniciar por sí misma una alerta general. El reporte podrá incluir institución, área o ubicación aproximada seleccionada, tipo de incidente (incendio, olor a gas, inundación, persona lesionada u otro), una descripción breve y hora de envío. El sistema mostrará la confirmación de recepción cuando exista; no debe prometer atención inmediata ni reemplazar los números de emergencia.

### 2.4 API central — imSafeAPI

Tecnologías iniciales:

- **Backend:** Node.js con Express.
- **Base de datos:** MongoDB.

La API atenderá las tres aplicaciones y centralizará autenticación y autorización de administradores y lanzadores, gestión de instituciones, perímetros y áreas, croquis y zonas seguras, alertas, destinatarios, reportes de incidentes y notificaciones. Deberá registrar auditoría de emisión, modificación y finalización de alertas, y proteger las operaciones críticas.

## 3. Geolocalización y selección de destinatarios

La ubicación del celular es **orientativa, no una medición exacta de posición interior**. Su precisión puede degradarse dentro de edificios y no permite identificar de forma fiable una planta o salón.

Reglas funcionales iniciales:

1. Utilizar la ubicación aproximada, cuando el usuario conceda permiso, para sugerir una institución y mostrar su información.
2. Permitir selección manual de institución y, opcionalmente, edificio, planta o área. No asumir que esa selección o el GPS permanecen siempre actualizados.
3. Al distribuir una alerta, incluir las áreas seleccionadas por el lanzador y, si así se configura, las áreas contiguas o la institución completa.
4. Ante una ubicación ambigua, favorecer la recepción de alertas potencialmente relevantes sobre la exclusión por un límite geográfico demasiado estricto.
5. Distinguir entre **área reportada por el usuario**, **ubicación aproximada del dispositivo** y **área afectada por la emergencia**.
6. Si no hay permiso de ubicación o señal suficiente, conservar la selección manual de institución para que el usuario pueda consultar el croquis y recibir las alertas correspondientes.

Las zonas seguras y las instrucciones dependen del tipo y lugar del incidente: una zona segura para sismo podría no ser apropiada ante un incendio o una fuga de gas. La aplicación no calculará rutas de evacuación ni afirmará que un trayecto es seguro sin información institucional validada y actualizada.

## 4. Recepción de alertas en segundo plano

**Objetivo funcional:** que la aplicación móvil del usuario final pueda recibir avisos aunque no esté abierta y que la persona acceda de inmediato a las instrucciones y al croquis.

La implementación inicial utilizará notificaciones push y los mecanismos de notificación de emergencia que permita cada plataforma. La notificación contendrá información breve y abrirá la pantalla de la alerta al tocarla. Cuando el sistema operativo permita una presentación más visible, se aprovechará respetando sus permisos y restricciones.

**Limitación:** no es posible garantizar que una aplicación de terceros se abra automáticamente en primer plano en todos los dispositivos Android e iOS, ni que una notificación llegue instantáneamente si el teléfono está apagado, sin conexión, con permisos denegados o sujeto a restricciones del sistema. El MVP no dependerá de una apertura forzada de la aplicación para funcionar.

La aplicación deberá recuperar la alerta vigente y el croquis al abrirse, y mostrar el estado actualizado cuando recupere conectividad. Se evaluará conservar localmente el último croquis e instrucciones validadas para su consulta sin conexión, indicando su fecha de actualización.

## 5. Flujo principal

1. Una institución registra su perímetro, áreas, croquis, zonas seguras e instrucciones validadas.
2. La persona administradora autoriza a los lanzadores de alertas.
3. El usuario final instala la aplicación, concede ubicación si lo desea y confirma la institución sugerida o la selecciona manualmente.
4. Un lanzador autorizado selecciona el tipo de emergencia y, cuando corresponda, las áreas afectadas y el alcance de difusión.
5. La API registra la alerta y envía notificaciones a los dispositivos asociados a la institución y al alcance configurado, con tolerancia para áreas contiguas o ubicación incierta.
6. El usuario recibe una notificación destacada y accede al croquis y a las instrucciones pertinentes.
7. Los lanzadores actualizan o finalizan la alerta; los dispositivos pueden consultar el estado vigente.

**Flujo de reporte:** un usuario final identifica un incidente, selecciona institución y área aproximada, envía una descripción breve y recibe confirmación de envío. El reporte llega a los lanzadores autorizados, quienes lo evalúan y, si procede, activan una alerta institucional. El reporte por sí solo no dispara una alerta masiva.

## 6. Seguridad, privacidad y confiabilidad

- Exigir autenticación y autorización para administrar instituciones y emitir, actualizar o finalizar alertas.
- Mantener trazabilidad de alertas y reportes, con marcas de tiempo y estados.
- Proteger los reportes contra abuso, duplicados y envío automatizado; permitir reportar sin cuenta, minimizando los datos personales recopilados.
- Solicitar consentimiento para la ubicación y explicar su uso. Evitar el seguimiento continuo o el almacenamiento innecesario del historial de ubicación.
- No utilizar la recepción de una notificación como prueba de que el usuario la leyó o está a salvo.
- Definir procedimientos ante falta de conectividad, notificaciones no entregadas y datos de croquis desactualizados.
- Mostrar claramente que las indicaciones oficiales y el personal de protección civil tienen prioridad.

## 7. Fuera del alcance de la primera versión

Se dejan para evaluación en una segunda versión:

- Integración con alertas gubernamentales de sismo u otros sistemas oficiales, sujeta a disponibilidad de interfaces, autorizaciones y pruebas.
- Apertura automática de la aplicación a partir de alertas gubernamentales, si las capacidades de cada sistema operativo y los acuerdos correspondientes lo permiten.
- Posicionamiento interior preciso mediante balizas, Wi-Fi u otra infraestructura especializada.
- Cálculo automático de rutas de evacuación en tiempo real.

## 8. Criterios iniciales de aceptación del MVP

- Una institución puede registrar áreas y zonas seguras y aprobar lanzadores.
- Un lanzador autorizado puede emitir y finalizar una alerta de sismo o una alerta localizada de otro tipo.
- Un usuario sin cuenta puede seleccionar una institución, consultar su croquis y recibir notificaciones cuando tenga permisos y conectividad.
- La difusión de alertas puede incluir áreas contiguas y usuarios cuya ubicación sea imprecisa.
- El usuario final puede enviar un reporte de incidente y un lanzador autorizado puede consultarlo sin que se emita automáticamente una alerta general.
- Al abrir una notificación, la aplicación consulta y presenta la alerta vigente y las indicaciones correspondientes.
- Se prueban explícitamente los casos de ubicación imprecisa, selección manual, permisos denegados, conectividad intermitente y notificaciones no recibidas.

## 9. Estado del proyecto

Documento de alcance funcional para orientar el desarrollo inicial de **imSafeAPI** y las tres interfaces de usuario. Las decisiones de arquitectura, servicios de notificaciones, modelo de datos y plataformas móviles se definirán durante la implementación.

## 10. Desarrollo actual: aplicación móvil para lanzadores de alertas

Este repositorio corresponde actualmente al desarrollo de **imSafe — aplicación móvil para lanzadores de alertas** (Flutter/Dart, Android e iOS). Las reglas para agentes y las decisiones aprobadas están en [`AGENTS.md`](AGENTS.md).

Estado: estándar compartido (feature-first, Riverpod, Dio, `go_router`, tres entornos) con autenticación real contra imSafeAPI, restauración de sesión y consulta/solicitud de acceso como lanzador. Alertas y reportes quedan pendientes porque imSafeAPI v0.2.0 aún no los expone. Contrato usado: [`docs/API_CONTRACT_LANZADORES.md`](docs/API_CONTRACT_LANZADORES.md).

### Ejecutar

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter run            # requiere un dispositivo Android/iOS o emulador
```

### Entornos

El entorno y la URL de imSafeAPI se pasan en compilación (solo configuración pública, nunca secretos):

```bash
flutter run -d <DEVICE_ID> --dart-define=IMSAFE_ENV=production --dart-define=IMSAFE_API_BASE_URL=https://api.imsafe.tlajomulco.tecnm.mx/api/v1
```

`IMSAFE_ENV` admite `development` (por defecto), `staging` y `production`; `staging` y `production` exigen `https`. Android no permite tráfico HTTP en claro (no está habilitado).

### Pruebas contra la API real

`flutter test` nunca usa la red. Las pruebas contra imSafeAPI real están separadas en `integration_api/`, solo hacen login, lecturas propias y logout (nunca alertas ni solicitudes de acceso), y se omiten si faltan credenciales:

```bash
flutter test integration_api --dart-define=IMSAFE_API_BASE_URL=https://api.imsafe.tlajomulco.tecnm.mx/api/v1 --dart-define=IMSAFE_TEST_EMAIL=<correo> --dart-define=IMSAFE_TEST_PASSWORD=<contraseña>
```

Por ahora solo se trabaja Android; la compilación para iOS requiere macOS con Xcode.

> El nombre de paquete `imsafe_lanzadores` y los identificadores `com.example.imsafe_lanzadores` (Android `applicationId` / iOS Bundle ID) son **temporales** y deben definirse antes de cualquier publicación.
