import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:horas_hombre_mobile/config/app_config.dart';
import 'package:horas_hombre_mobile/screens/home_screen.dart';
import 'package:horas_hombre_mobile/services/api_service.dart';
import 'package:horas_hombre_mobile/services/face_match_service.dart';
import 'package:horas_hombre_mobile/services/face_reference_repository.dart';
import 'package:horas_hombre_mobile/services/face_sdk_service.dart';
import 'package:horas_hombre_mobile/services/settings_service.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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

class HorasHombreApp extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(
          value: settingsService,
        ),
        Provider<FaceSdkService>.value(value: faceSdkService),
        Provider<ApiService>(
          create: (_) => ApiService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<FaceReferenceRepository>(
          create: (_) => FaceReferenceRepository(),
        ),
        ProxyProvider<FaceSdkService, FaceMatchService>(
          update: (_, sdk, _) => DeviceFaceMatchService(sdk),
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
        home: faceSdkInitError != null && !faceSdkService.isInitialized
            ? FaceSdkErrorScreen(
                message: faceSdkInitError!,
                faceSdkService: faceSdkService,
                settingsService: settingsService,
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
    required this.settingsService,
  });

  final String message;
  final FaceSdkService faceSdkService;
  final SettingsService settingsService;

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
                        builder: (_) => HorasHombreApp(
                          settingsService: settingsService,
                          faceSdkService: faceSdkService,
                        ),
                      ),
                    );
                  }
                } on FaceSdkException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message)),
                    );
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
