# AGENTS.md

## Proyecto
App móvil de asistencia con validación biométrica usando **Flutter + 3DiVi Face SDK + Java Spring + MySQL**.

## Objetivo del MVP
Implementar el flujo:

1. Escanear QR para identificar al empleado.
2. Tomar foto desde la app Flutter.
3. Ejecutar prueba de vida.
4. Verificar que la persona capturada coincide con la foto registrada del empleado.
5. Registrar el evento de asistencia.
6. Soportar modo offline con sincronización posterior.

---

## Estado actual del proyecto

### Ya disponible
- Backend para registro de empleado.
- Backend para subir foto del empleado.
- Base de aplicación Flutter.
- Plugin **3DiVi Face SDK 3.26.1** (`face_sdk_3divi` en `C:\Users\olive\3DiVi_FaceSDK\3_26_1`).
- Assets locales: `assets/conf`, `assets/lib`, `assets/share`, `assets/license/3divi_face_sdk.lic` (gitignored).
- **Fase 1 completada (Luxand, histórica):** `FaceSdkService` y pantalla de prueba biométrica.
- **Fase 2 completada:** flujo QR → empleado → referencia → captura → liveness → match 1:1 → resultado.
- **Proveedor biométrico actual:** 3DiVi (pipeline de Simose: detector `uld`, fitter `fda`, liveness `2d_light`, templates `100m`).
- Licencia de prueba de Luxand ya no se usa.
- Base de datos MySQL.
- Backend en Java Spring.

### Suposiciones actuales
- Existe una entidad de empleado y una API para alta.
- Existe almacenamiento de foto de referencia.
- La app Flutter ya compila y permite agregar pantallas nuevas.
- El backend puede exponer endpoints adicionales para asistencia y sincronización.
- La integración biométrica se ejecuta en el dispositivo móvil con **3DiVi Face SDK**.

### Gaps identificados
- Fase 3 incompleta: asistencia sin metadatos biométricos ni auditoría.
- No está implementada la cola offline / sincronización (Fase 4).
- Umbrales biométricos iniciales definidos; pendiente ajuste con pruebas de campo.

---

## Decisión de arquitectura

### Regla principal
Toda la validación biométrica del MVP se ejecuta en el **dispositivo móvil** usando **3DiVi Face SDK**.

### Razones
- Permite funcionamiento offline real.
- Reduce latencia.
- Evita enviar imágenes al backend en cada intento.
- Reutiliza el pipeline ya validado en Simose (`uld` / `fda` / `2d_light` / `100m`).

### Responsabilidades por capa

#### Flutter app
- Escaneo de QR.
- Captura de foto.
- Invocación del SDK biométrico.
- Persistencia local.
- Cola offline.
- Sincronización.

#### Plugin / bridge nativo 3DiVi
- `MainActivity` carga `libfacerec` y expone `getNativeLibDir`.
- Liveness pasivo `2d_light`.
- Verificación 1:1 con `FACE_TEMPLATE_EXTRACTOR` + `VERIFICATION_MODULE` (`100m`).
- Licencia: `assets/license/3divi_face_sdk.lic` ligada al `android_app_id` de release.

#### Backend Spring
- Alta de empleados.
- Entrega de referencia biométrica al móvil.
- Registro de asistencia.
- Validación de negocio.
- Auditoría.
- Sincronización de eventos pendientes.

#### MySQL
- Empleados.
- Foto o referencia facial.
- Eventos de asistencia.
- Auditoría.
- Control de sincronización.

---

## Reglas de implementación

### 1. Tipo de biometría
Usar **verificación 1:1**, no reconocimiento 1:N.

El QR identifica al empleado esperado.
La biometría solo confirma si la foto tomada coincide con ese empleado.

### 2. Referencia biométrica
Para el MVP, usar como referencia la **foto registrada** del empleado.

Más adelante, si conviene, persistir templates faciales.

### 3. Liveness
Implementar primero liveness con el flujo disponible en el sample de Luxand.

### 4. Offline
La app debe poder:
- usar referencia biométrica local ya sincronizada,
- validar biometría sin internet,
- registrar evento local pendiente,
- sincronizar después.

### 5. Inicialización de FaceSDK
Inicializar FaceSDK una sola vez al arrancar el módulo biométrico o la app.
No inicializar/finalizar repetidamente por cada operación.

### 6. Seguridad
- No hardcodear la licencia en múltiples lugares.
- No exponer secretos del QR en claro.
- No confiar solo en el resultado del cliente para reglas de negocio.
- Usar HTTPS cuando haya backend.

---

## Fases de desarrollo

## Fase 1 — Integración Luxand en Flutter ✅ TERMINADA

> Validada en dispositivo: licencia activa, liveness y match 1:1 en pantalla de prueba aislada.

### Objetivo
Lograr que la app Flutter pueda invocar funciones biométricas básicas.

### Tareas
- [x] Revisar estructura del sample **Advanced Flutter**.
- [x] Identificar cómo inicializa Luxand FaceSDK.
- [x] Extraer o adaptar el bridge/plugin nativo hacia la app base (`packages/flutter_face_sdk`).
- [x] Crear un servicio Flutter `FaceSdkService` (`lib/services/face_sdk_service.dart`).
- [x] Implementar una pantalla de prueba que:
  - [x] reciba una foto de referencia,
  - [x] capture una foto nueva,
  - [x] ejecute liveness,
  - [x] ejecute verificación 1:1,
  - [x] muestre resultado (`isLive`, `livenessScore`, `isMatch`, `faceMatchScore`).

### Entregable
Pantalla biométrica funcional aislada del resto del flujo → **Ajustes → Prueba biométrica (Fase 1)**.

### Criterio de éxito
Se puede comparar una foto capturada contra una foto de referencia desde la app. **Cumplido.**

---

## Fase 2 — Flujo QR + verificación ✅ TERMINADA

> Flujo online validado: QR identifica empleado, Luxand ejecuta liveness + verify 1:1 contra foto de referencia.

### Objetivo
Conectar la biometría al flujo de identificación del empleado.

### Tareas
- [x] Agregar lector de QR.
- [x] Definir payload del QR (`QrPayload`: número plano o JSON con `numberUser`).
- [x] Resolver `numberUser` a partir del QR.
- [x] Obtener la foto de referencia del empleado:
  - [x] desde cache local (`FaceReferenceRepository`),
  - [x] o desde backend si hay conexión.
- [x] Tomar foto.
- [x] Ejecutar liveness (Luxand FaceSDK).
- [x] Ejecutar verificación 1:1 (Luxand FaceSDK).
- [x] Mostrar pantalla de resultado.

### Entregable
Flujo de validación completo desde QR hasta aceptación/rechazo → **Entrada/Salida en pantalla principal**.

### Criterio de éxito
Dado un QR válido y una referencia disponible, la app determina si el intento pasa o falla. **Cumplido (modo online).**

---

## Fase 3 — Registro de asistencia
### Objetivo
Persistir el resultado del intento y registrar asistencia real.

### Tareas
- Diseñar DTO de evento de asistencia.
- Crear endpoint Spring `POST /api/attendance`.
- Enviar resultado desde Flutter.
- Guardar:
  - employeeId,
  - timestamp,
  - liveness score,
  - face match score,
  - resultado final,
  - deviceId,
  - offlineEventId.
- Registrar auditoría de rechazos.

### Entregable
Evento de asistencia registrado en backend.

### Criterio de éxito
Un intento aceptado genera un registro persistido y deduplicable.

---

## Fase 4 — Offline y sincronización
### Objetivo
Permitir operación sin internet.

### Tareas
- Crear base local para eventos pendientes.
- Crear cache local de referencias biométricas.
- Guardar intentos pendientes si no hay red.
- Crear proceso de sincronización.
- Crear endpoint batch `POST /api/attendance/sync`.
- Marcar eventos locales como sincronizados.

### Entregable
Flujo offline funcional.

### Criterio de éxito
La app puede registrar asistencia sin internet y sincronizar luego.

---

## Contratos internos sugeridos

## Flutter

### FaceSdkService
Responsabilidad: abstracción del bridge Luxand.

```dart
abstract class FaceSdkService {
  Future<void> initialize();
  Future<LivenessResult> checkLiveness(String imagePath);
  Future<VerifyResult> verifyFace({
    required String capturedImagePath,
    required String referenceImagePath,
  });
}
```

### AttendanceRepository
```dart
abstract class AttendanceRepository {
  Future<void> sendAttendance(AttendanceEvent event);
  Future<void> savePendingAttendance(AttendanceEvent event);
  Future<List<AttendanceEvent>> getPendingAttendances();
  Future<void> markAsSynced(String offlineEventId);
}
```

### FaceReferenceRepository
```dart
abstract class FaceReferenceRepository {
  Future<FaceReference?> getLocalReference(String employeeId);
  Future<FaceReference?> fetchRemoteReference(String employeeId);
  Future<void> saveLocalReference(FaceReference ref);
}
```

---

## Backend Spring

### Endpoints mínimos

#### Obtener referencia biométrica
`GET /api/employees/{id}/face-reference`

Respuesta sugerida:
```json
{
  "employeeId": "123",
  "version": 1,
  "referenceImageUrl": "https://server/faces/123.jpg"
}
```

#### Registrar asistencia
`POST /api/attendance`

#### Sincronizar eventos pendientes
`POST /api/attendance/sync`

---

## Modelo de datos mínimo

### attendance_event
Campos sugeridos:
- id
- employee_id
- event_type
- device_id
- offline_event_id
- captured_at_device
- received_at_server
- qr_valid
- liveness_score
- liveness_result
- face_match_score
- face_match_result
- final_result
- created_at

### attendance_attempt_audit
Campos sugeridos:
- id
- employee_id
- device_id
- reason_code
- detail
- created_at

### face_profile
Campos sugeridos:
- id
- employee_id
- reference_image_path
- version
- active
- created_at
- updated_at

---

## Reglas de negocio mínimas

### Aceptar si
- QR válido.
- Existe referencia biométrica del empleado.
- Solo hay una cara usable.
- Liveness aprobado.
- Face match aprobado.

### Rechazar si
- QR inválido.
- Empleado sin referencia local/remota.
- No hay rostro detectable.
- Hay múltiples rostros.
- Liveness falla.
- Face match falla.

### Registrar auditoría cuando
- falle liveness,
- falle face match,
- no exista referencia,
- QR sea inválido,
- la sincronización falle.

---

## Criterios de calidad biométrica
Estos umbrales son iniciales y deben ajustarse con pruebas reales.

### Umbrales iniciales sugeridos
- Liveness 3DiVi: categoría `REAL` (`2d_light`)
- `face_match_score >= 0.75`

No congelar estos valores hasta probar con:
- diferentes cámaras,
- distintas iluminaciones,
- fotos impresas,
- pantallas,
- usuarios reales.

---

## Convenciones para el equipo

### No hacer
- No meter lógica biométrica en el backend para el MVP offline.
- No construir reconocimiento 1:N en esta fase.
- No enviar siempre la foto al backend si no hace falta.
- No mezclar la capa UI con la invocación directa del SDK.
- No duplicar la lógica de umbrales en varios archivos.

### Sí hacer
- Encapsular 3DiVi en `FaceSdkService`.
- Separar UI, dominio y acceso a datos.
- Guardar logs/auditoría de rechazo.
- Mantener el flujo determinista.
- Probar en dispositivo real, no solo emulador.

---

## Orden de trabajo recomendado

1. ~~Verificar que el sample Advanced Flutter corre con la licencia de prueba.~~ ✅
2. ~~Extraer integración Luxand a la app base.~~ ✅
3. ~~Crear pantalla de prueba biométrica.~~ ✅
4. ~~Integrar captura de foto en flujo de asistencia.~~ ✅
5. ~~Integrar QR.~~ ✅
6. ~~Conectar referencia facial del backend.~~ ✅
7. Implementar evento de asistencia (Fase 3).
8. Implementar persistencia local (Fase 4).
9. Implementar sincronización (Fase 4).
10. Ajustar umbrales y reglas.

---

## Checklist de avance

### Integración Luxand (Fase 1)
- [x] El sample compila en el entorno actual.
- [x] La licencia de prueba funciona.
- [x] FaceSDK inicializa correctamente.
- [x] Flutter puede invocar liveness.
- [x] Flutter puede invocar verify 1:1.

### Flujo funcional
- [x] Se puede escanear QR.
- [x] Se puede resolver empleado.
- [x] Se puede obtener foto de referencia.
- [x] Se puede capturar foto.
- [x] Se puede validar liveness.
- [x] Se puede validar coincidencia facial.
- [x] Se muestra aceptación/rechazo.

### Backend
- [ ] Existe endpoint para obtener referencia.
- [ ] Existe endpoint para registrar asistencia.
- [ ] Existe persistencia de auditoría.
- [ ] Existe deduplicación por offlineEventId.

### Offline
- [x] Existe cache local de referencias (`FaceReferenceRepository`).
- [ ] Existe cola local de eventos.
- [ ] Existe proceso de sync.
- [ ] Los eventos sincronizados se marcan correctamente.

---

## Riesgos conocidos

### Riesgo 1
El sample Advanced Flutter podría no encajar directo con la arquitectura actual.
**Mitigación:** aislar primero el bridge nativo y luego adaptarlo.

### Riesgo 2
La foto registrada del empleado puede no tener calidad suficiente.
**Mitigación:** validar calidad mínima en el enrolamiento.

### Riesgo 3
El liveness inicial puede requerir ajuste o add-on más robusto.
**Mitigación:** arrancar con el flujo disponible y medir falsos positivos/falsos rechazos.

### Riesgo 4
Offline sin referencia local no sirve.
**Mitigación:** sincronizar referencias antes de usar modo offline.

---

## Definición de “MVP terminado”
El MVP se considera terminado cuando:

- la app Flutter escanea QR,
- obtiene referencia del empleado,
- toma foto,
- ejecuta liveness,
- verifica rostro 1:1 con Luxand FaceSDK,
- registra asistencia,
- funciona online y offline,
- sincroniza pendientes,
- y deja auditoría suficiente para depuración.

---

## Siguiente primer hito

**Fase 3 — Registro de asistencia:** enviar scores biométricos, `deviceId`, auditoría de rechazos y alinear el contrato con el backend Spring.
