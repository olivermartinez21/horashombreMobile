import 'package:flutter/material.dart';
import 'package:horas_hombre_mobile/config/app_config.dart';
import 'package:horas_hombre_mobile/config/device_form_factor.dart';
import 'package:horas_hombre_mobile/screens/home_screen.dart';
import 'package:horas_hombre_mobile/services/api_service.dart';
import 'package:horas_hombre_mobile/services/attendance_sync_service.dart';
import 'package:horas_hombre_mobile/services/face_gallery_service.dart';
import 'package:horas_hombre_mobile/services/face_match_service.dart';
import 'package:horas_hombre_mobile/services/face_reference_repository.dart';
import 'package:horas_hombre_mobile/services/face_sdk_service.dart';
import 'package:horas_hombre_mobile/services/settings_service.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await applyKioskOrientations();

  final settingsService = SettingsService();
  await settingsService.load();

  final faceSdkService = FaceSdkService();
  String? faceSdkInitError;
  try {
    await faceSdkService.initialize();
  } on FaceSdkException catch (e) {
    faceSdkInitError = e.message;
    debugPrint('FaceSDK: $e');
  } catch (e) {
    faceSdkInitError = e.toString();
    debugPrint('FaceSDK init error: $e');
  }

  runApp(
    HorasHombreApp(
      settingsService: settingsService,
      faceSdkService: faceSdkService,
      faceSdkInitError: faceSdkInitError,
    ),
  );
}

class HorasHombreApp extends StatefulWidget {
  const HorasHombreApp({
    super.key,
    required this.settingsService,
    required this.faceSdkService,
    this.faceSdkInitError,
  });

  final SettingsService settingsService;
  final FaceSdkService faceSdkService;
  final String? faceSdkInitError;

  @override
  State<HorasHombreApp> createState() => _HorasHombreAppState();
}

class _HorasHombreAppState extends State<HorasHombreApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      widget.faceSdkService.dispose();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(
          value: widget.settingsService,
        ),
        Provider<FaceSdkService>.value(value: widget.faceSdkService),
        Provider<ApiService>(
          create: (_) => ApiService(),
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProvider<AttendanceSyncService>(
          create: (context) => AttendanceSyncService(
            api: context.read<ApiService>(),
          ),
        ),
        Provider<FaceReferenceRepository>(
          create: (_) => FaceReferenceRepository(),
        ),
        ProxyProvider<FaceSdkService, FaceMatchService>(
          update: (_, sdk, _) => DeviceFaceMatchService(sdk),
        ),
        ChangeNotifierProxyProvider2<ApiService, FaceSdkService,
            FaceGalleryService>(
          create: (context) => FaceGalleryService(
            api: context.read<ApiService>(),
            faceSdk: widget.faceSdkService,
          ),
          update: (_, api, faceSdk, previous) =>
              previous ?? FaceGalleryService(api: api, faceSdk: faceSdk),
        ),
      ],
      child: MaterialApp(
        title: 'Horas Hombre — Asistencia',
        debugShowCheckedModeBanner: AppConfig.isDev,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home:
            widget.faceSdkInitError != null &&
                !widget.faceSdkService.isInitialized
            ? FaceSdkErrorScreen(
                message: widget.faceSdkInitError!,
                faceSdkService: widget.faceSdkService,
              )
            : const HomeScreen(),
      ),
    );
  }
}

class FaceSdkErrorScreen extends StatelessWidget {
  const FaceSdkErrorScreen({
    super.key,
    required this.message,
    required this.faceSdkService,
  });

  final String message;
  final FaceSdkService faceSdkService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FaceSDK')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade700),
            const SizedBox(height: 16),
            Text(
              'No se pudo inicializar 3DiVi Face SDK',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 16),
            const Text(
              'Coloque 3divi_face_sdk.lic en assets/license/\n'
              'ligada al applicationId de release (com.arinco.horas_hombre_mobile).',
              style: TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                try {
                  await faceSdkService.initialize();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => const HomeScreen(),
                      ),
                    );
                  }
                } on FaceSdkException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar activación'),
            ),
          ],
        ),
      ),
    );
  }
}
