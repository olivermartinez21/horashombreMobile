# Horas Hombre Mobile

App kiosko Flutter para registro de asistencia (entrada/salida) con escaneo QR y verificación facial con **3DiVi Face SDK 3.31.00**.

## Qué cambió (SDK 3.31)

El portal de 3DiVi ya no ofrece 3.26.1; la versión actual es **3.31.00**.

| 3.26.1 | 3.31.00 |
|---|---|
| Plugin: `…/3DiVi_FaceSDK/3_26_1/flutter/face_sdk_3divi` | `../../3DIVI_FaceSDK/face_sdk_3/flutter/face_sdk_3divi` |
| Licencia con `max_sdk_version` 3.30 | Licencia en `keys/3divi_face_sdk.lic` (`max_sdk_version` 3.31, app `com.arinco.horas_hombre_mobile`) |
| Modelos `100m/1/part1.enc` … `part3.enc` | Un solo archivo `100m/1.enc` |
| JDK 25 de Android Studio + Gradle 8.14 (incompatible) | OpenJDK 17 (`flutter config --jdk-dir`) |

**No existe un Face SDK para macOS.** En el equipo de desarrollo solo se descomprimen archivos; la app corre en Android. Hay que bajar dos piezas: el paquete **Flutter / Mobile** y el zip **The most current models** (`share`).

## Layout esperado

`pubspec.yaml` apunta al plugin con la ruta relativa `../../3DIVI_FaceSDK/face_sdk_3/flutter/face_sdk_3divi`. El SDK debe quedar **dos niveles por encima** de este repositorio:

```text
<raiz>/
  3DIVI_FaceSDK/face_sdk_3/          # SDK 3.31 (plugin Flutter + libs nativas)
    flutter/face_sdk_3divi/
    flutter/lib/                     # .so Android + frameworks iOS
    conf/
    share/                           # modelos (zip aparte)
      processing_block/face_detector/uld/
      processing_block/face_fitter/fda/
      processing_block/liveness_estimator/2d_light/
      processing_block/face_template_extractor/100m/1.enc
  <grupo>/
    horashombreMobile/               # este repo
      pubspec.yaml
      keys/3divi_face_sdk.lic
      keys/horas-hombre-release.jks
      assets/license/3divi_face_sdk.lic  # copia de keys/ que carga el SDK
      assets/lib/                        # copia de flutter/lib 3.31
      assets/share/                      # copia de los 4 processing blocks
```

Si el SDK está en otra ruta, ajuste el `path` de `face_sdk_3divi` en `pubspec.yaml`.

## Requisitos

- Flutter 3.11+ (probado con 3.47.2)
- OpenJDK **17** (el JDK 25 incluido en Android Studio no es compatible con Gradle 8.14)
- Android SDK + **NDK 28.2.13676358** + CMake 3.22.1
- Dispositivo Android físico (USB debugging). El emulador no sirve para 3DiVi
- Backend Nova en `http://<host>:5000/nova`
- Licencia 3DiVi ligada al Application ID de un APK **release** firmado con `keys/horas-hombre-release.jks`

## Instalación

Los comandos se ejecutan desde la **raíz de este repositorio**, salvo que se indique otra cosa.

### 1. Flutter y Java 17

```bash
# macOS (Homebrew). En Linux instale un JDK 17 y apunte --jdk-dir a su JAVA_HOME.
brew install openjdk@17
flutter config --jdk-dir="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
```

### 2. Android SDK / NDK

Desde Android Studio SDK Manager, o:

```bash
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
sdkmanager "ndk;28.2.13676358" "cmake;3.22.1"
```

En Linux, `ANDROID_HOME` suele ser `$HOME/Android/Sdk`.

### 3. Descargar 3DiVi Face SDK 3.31

Portal: [FaceSDK downloads](https://download.3divi.com/facesdk/archives/latest.html)

1. **Mobile → Flutter** (no Windows, no Linux, no un paquete “Mac”). Extraer en `<raiz>/3DIVI_FaceSDK/face_sdk_3`.
2. **The most current models** (no “Outdated models from the legacy api”). Extraer la carpeta `share` **dentro** de `face_sdk_3`:

```text
<raiz>/3DIVI_FaceSDK/face_sdk_3/share/processing_block/...
```

### 4. Copiar assets a la app

```bash
SDK=../../3DIVI_FaceSDK/face_sdk_3

# Native libs (Gradle las toma de assets/lib)
rsync -a --delete "$SDK/flutter/lib/" assets/lib/

# Modelos del pipeline (uld / fda / 2d_light / 100m)
PB="$SDK/share/processing_block"
DST=assets/share/processing_block
rsync -a --delete "$PB/face_detector/uld/" "$DST/face_detector/uld/"
rsync -a --delete "$PB/face_fitter/fda/" "$DST/face_fitter/fda/"
rsync -a --delete "$PB/liveness_estimator/2d_light/" "$DST/liveness_estimator/2d_light/"
rsync -a --delete "$PB/face_template_extractor/100m/" "$DST/face_template_extractor/100m/"

# Licencia: keys/ es la fuente; assets/license/ es la que empaqueta Flutter
cp keys/3divi_face_sdk.lic assets/license/3divi_face_sdk.lic
```

Si se actualizan modelos, **desinstale la app del teléfono** antes de reinstalar. El plugin 3DiVi copia `share` a Documents y no lo sobrescribe si el archivo ya existe.

### 5. Dependencias Flutter

```bash
flutter pub get
```

## Licencia 3DiVi

Coloque `3divi_face_sdk.lic` en `keys/` y cópielo a `assets/license/`. Debe coincidir con:

- `android_app_id` del APK **release** (`com.arinco.horas_hombre_mobile` + firma de `keys/horas-hombre-release.jks`)
- `max_sdk_version` **3.31** (una licencia 3.30 no abre este SDK)

`flutter run` (debug) usa otro keystore: la licencia **no va a validar**. Use `--release`.

Para capturar el Application ID, deje `"license_debug_log": true` en `assets/conf/facerec/config.json`, instale el APK release e inicialice el SDK. En logcat:

```
android_app_id: '<hash>-com.arinco.horas_hombre_mobile'
```

## Ejecutar en el teléfono

Conecte el dispositivo por USB (depuración USB activada). Use la IP LAN del equipo donde corre el backend:

```bash
flutter devices
flutter run --release -d <deviceId> \
  --dart-define=APP_ENV=dev \
  --dart-define=API_BASE_URL=http://<host>:5000/nova
```

En Windows también están `scripts/run_dev.ps1` y `scripts/build_prod.ps1`.

## Compilar producción

```bash
flutter build apk --release \
  --dart-define=APP_ENV=prod \
  --dart-define=API_BASE_URL=https://su-servidor/nova
```

APK: `build/app/outputs/flutter-apk/app-release.apk`.

## Flujo

1. **Entrada** o **Salida** en pantalla principal.
2. Escanear QR con el número de empleado.
3. Consulta `GET /attendance/employee/{numberUser}`.
4. Selfie con cámara frontal: liveness + comparación 1:1 contra foto del empleado (3DiVi).
5. `POST /attendance/save` con `ENTRADA` o `SALIDA`.

## Biometría

- Plugin: `face_sdk_3divi` (SDK 3.31.00), pipeline `uld` / `fda` / `2d_light` / `100m`.
- Fachada: `lib/services/face_sdk_service.dart`.
- Umbrales en `lib/config/biometric_config.dart` (match `>= 0.75`).
- Ajustes muestra estado del SDK y umbrales activos.

Error típico si los modelos no coinciden con 3.31:

```
Assertion failed (not the current face_template_extractor model)
```

### Validar licencia

1. Coloque `3divi_face_sdk.lic` en `assets/license/`.
2. Ejecute **release** en dispositivo físico.
3. Vaya a **Ajustes → Prueba biométrica (Fase 1)**.
4. Elija una foto de referencia (galería), tome una selfie y pulse **Ejecutar liveness + verificación 1:1**.
5. Debe mostrar `isLive`, `livenessScore`, `isMatch` y `faceMatchScore`.

## Ajustes

- Muestra `APP_ENV`, `API_BASE_URL` y estado de FaceSDK.
