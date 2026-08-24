# Horas Hombre Mobile

App kiosko Flutter para registro de asistencia (entrada/salida) con escaneo QR y verificación facial con **3DiVi Face SDK**.

## Requisitos

- Flutter SDK 3.11+
- Backend Nova en `http://<host>:5000/nova`
- Face SDK 3.26.1 en `C:\Users\olive\3DiVi_FaceSDK\3_26_1`
- Licencia `assets/license/3divi_face_sdk.lic` ligada al Application ID de release
- Android: NDK 28.2.13676358 (CMake vía Android Studio SDK Manager)

## Licencia 3DiVi

Coloque el archivo `3divi_face_sdk.lic` en `assets/license/`. Debe estar ligada al `android_app_id` de un APK **release** firmado con el keystore de producción.

Para capturar ese ID, deje `"license_debug_log": true` en `assets/conf/facerec/config.json`, instale el APK release e inicialice el SDK. En logcat busque:

```
android_app_id: '<hash>-com.arinco.horas_hombre_mobile'
```

## Ejecutar (desarrollo)

1. Ajuste la IP en `scripts/run_dev.ps1` (o pase el parámetro).
2. En emulador Android use `http://10.0.2.2:5000/nova` por defecto en `AppConfig`.
3. En dispositivo físico use la IP LAN de su PC.

```powershell
.\scripts\run_dev.ps1 -ApiBaseUrl "http://192.168.1.50:5000/nova"
```

## Compilar producción

```powershell
.\scripts\build_prod.ps1 -ApiBaseUrl "https://su-servidor/nova"
```

## Flujo

1. **Entrada** o **Salida** en pantalla principal.
2. Escanear QR con el número de empleado.
3. Consulta `GET /attendance/employee/{numberUser}`.
4. Selfie con cámara frontal: liveness + comparación 1:1 contra foto del empleado (3DiVi).
5. `POST /attendance/save` con `ENTRADA` o `SALIDA`.

## Biometría

- Plugin: `face_sdk_3divi` (SDK 3.26.1), mismo pipeline que Simose (`uld` / `fda` / `2d_light` / `100m`).
- Fachada de la app: `lib/services/face_sdk_service.dart`.
- Umbrales iniciales en `lib/config/biometric_config.dart` (match `>= 0.75`).
- Ajustes muestra estado del SDK y umbrales activos.

### Validar licencia

1. Coloque `3divi_face_sdk.lic` en `assets/license/`.
2. Ejecute la app en **dispositivo físico** (recomendado).
3. Vaya a **Ajustes → Prueba biométrica (Fase 1)**.
4. Elija una foto de referencia (galería), tome una selfie y pulse **Ejecutar liveness + verificación 1:1**.
5. Debe mostrar `isLive`, `livenessScore`, `isMatch` y `faceMatchScore`.

## Ajustes

- Muestra `APP_ENV`, `API_BASE_URL` y estado de FaceSDK.
