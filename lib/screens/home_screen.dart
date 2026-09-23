import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:horas_hombre_mobile/models/attendance.dart';
import 'package:horas_hombre_mobile/screens/face_identify_screen.dart';
import 'package:horas_hombre_mobile/screens/result_screen.dart';
import 'package:horas_hombre_mobile/screens/settings_screen.dart';
import 'package:horas_hombre_mobile/services/face_gallery_service.dart';
import 'package:horas_hombre_mobile/services/face_sdk_service.dart';
import 'package:horas_hombre_mobile/services/settings_service.dart';
import 'package:horas_hombre_mobile/widgets/admin_pin_guard.dart';
import 'package:horas_hombre_mobile/widgets/big_action_button.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _platform = MethodChannel('samples.flutter.dev/facesdk');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmGallery());
  }

  Future<void> _warmGallery() async {
    final gallery = context.read<FaceGalleryService>();
    final faceSdk = context.read<FaceSdkService>();
    if (!faceSdk.isInitialized) return;

    try {
      await gallery.loadLocalIndex();
      // Sync en background si hay red; no bloquea el kiosko.
      gallery.syncFromBackend().catchError((Object e) {
        debugPrint('Sync galería en background: $e');
        return gallery.cachedEmployeeCount;
      });
    } catch (e) {
      debugPrint('Carga local galería: $e');
    }
  }

  Future<void> _sendToBackground() async {
    try {
      await _platform.invokeMethod<bool>('moveTaskToBack');
    } on PlatformException {
      await SystemNavigator.pop();
    }
  }

  Future<void> _openSettings(BuildContext context) async {
    final authorized = await AdminPinGuard.requestAccess(context);
    if (!authorized || !context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _startFlow(BuildContext context) async {
    final settings = context.read<SettingsService>();
    final type = settings.kioskEventType;
    if (type == null || !settings.isKioskConfigured) {
      await _openSettings(context);
      return;
    }

    final faceSdk = context.read<FaceSdkService>();
    if (!faceSdk.isInitialized) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(
            success: false,
            title: 'Biometría no disponible',
            subtitle:
                '3DiVi Face SDK no está inicializado. Revise la licencia en Ajustes.',
            attendanceType: type,
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FaceIdentifyScreen(attendanceType: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final type = settings.kioskEventType;
    final configured = settings.isKioskConfigured;
    final gallery = context.watch<FaceGalleryService>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _sendToBackground();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Asistencia'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Ajustes',
              onPressed: () => _openSettings(context),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: configured && type != null
                ? _KioskReadyView(
                    type: type,
                    locationName: settings.locationName ?? '',
                    galleryCount: gallery.cachedEmployeeCount,
                    gallerySyncing: gallery.isSyncing,
                    onStart: () => _startFlow(context),
                  )
                : _KioskSetupView(onOpenSettings: () => _openSettings(context)),
          ),
        ),
      ),
    );
  }
}

class _KioskReadyView extends StatelessWidget {
  const _KioskReadyView({
    required this.type,
    required this.locationName,
    required this.galleryCount,
    required this.gallerySyncing,
    required this.onStart,
  });

  final AttendanceType type;
  final String locationName;
  final int galleryCount;
  final bool gallerySyncing;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final isEntrada = type == AttendanceType.entrada;
    return Column(
      children: [
        Text(
          'Kiosko de ${type.label.toLowerCase()}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          locationName,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 4),
        Text(
          gallerySyncing
              ? 'Sincronizando galería facial…'
              : 'Galería: $galleryCount rostros · 1:N → QR → número',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: BigActionButton(
            label: type.apiValue,
            icon: isEntrada ? Icons.login : Icons.logout,
            color: isEntrada ? Colors.green.shade600 : Colors.red.shade600,
            onPressed: onStart,
          ),
        ),
      ],
    );
  }
}

class _KioskSetupView extends StatelessWidget {
  const _KioskSetupView({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront, size: 72, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              'Configure el kiosko',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Seleccione el tipo de evento (ENTRADA o SALIDA) y la ubicación en Ajustes.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings),
              label: const Text('Ir a Ajustes'),
            ),
          ],
        ),
      ),
    );
  }
}
