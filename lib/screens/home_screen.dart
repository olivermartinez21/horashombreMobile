import 'package:flutter/material.dart';
import 'package:horas_hombre_mobile/models/attendance.dart';
import 'package:horas_hombre_mobile/screens/face_capture_screen.dart';
import 'package:horas_hombre_mobile/screens/qr_scan_screen.dart';
import 'package:horas_hombre_mobile/screens/result_screen.dart';
import 'package:horas_hombre_mobile/screens/settings_screen.dart';
import 'package:horas_hombre_mobile/services/api_service.dart';
import 'package:horas_hombre_mobile/services/face_reference_repository.dart';
import 'package:horas_hombre_mobile/services/face_sdk_service.dart';
import 'package:horas_hombre_mobile/widgets/big_action_button.dart';
import 'package:horas_hombre_mobile/widgets/loading_overlay.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _startFlow(BuildContext context, AttendanceType type) async {
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

    final numberUser = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(builder: (_) => const QrScanScreen()),
    );

    if (numberUser == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingOverlay(message: 'Buscando empleado…'),
    );

    try {
      final api = context.read<ApiService>();
      final faceRefRepo = context.read<FaceReferenceRepository>();
      final employee = await api.getEmployee(numberUser);
      await faceRefRepo.cacheFromEmployee(employee);

      if (!context.mounted) return;
      Navigator.of(context).pop(); // loading

      if (employee.active == false) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ResultScreen(
              success: false,
              title: 'Empleado inactivo',
              subtitle: employee.fullName,
              attendanceType: type,
            ),
          ),
        );
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => FaceCaptureScreen(
            employee: employee,
            attendanceType: type,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // loading
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(
            success: false,
            title: 'Empleado no encontrado',
            subtitle: e.message,
            attendanceType: type,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // loading
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(
            success: false,
            title: 'Error de conexión',
            subtitle: e.toString(),
            attendanceType: type,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistencia'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ajustes',
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Seleccione el tipo de registro',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: BigActionButton(
                  label: 'ENTRADA',
                  icon: Icons.login,
                  color: Colors.green.shade600,
                  onPressed: () =>
                      _startFlow(context, AttendanceType.entrada),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: BigActionButton(
                  label: 'SALIDA',
                  icon: Icons.logout,
                  color: Colors.red.shade600,
                  onPressed: () =>
                      _startFlow(context, AttendanceType.salida),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
