import 'package:flutter/material.dart';
import 'package:horas_hombre_mobile/config/app_config.dart';
import 'package:horas_hombre_mobile/config/biometric_config.dart';
import 'package:horas_hombre_mobile/screens/biometric_test_screen.dart';
import 'package:horas_hombre_mobile/services/face_sdk_service.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faceSdk = context.read<FaceSdkService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entorno',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'APP_ENV', value: AppConfig.displayEnv),
                  _InfoRow(label: 'API_BASE_URL', value: AppConfig.baseUrl),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3DiVi Face SDK',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Licencia',
                    value: 'assets/license/3divi_face_sdk.lic',
                  ),
                  _InfoRow(
                    label: 'SDK inicializado',
                    value: faceSdk.isInitialized ? 'Sí' : 'No',
                  ),
                  _InfoRow(
                    label: 'Umbral liveness',
                    value: BiometricConfig.livenessThreshold.toString(),
                  ),
                  _InfoRow(
                    label: 'Umbral coincidencia',
                    value: BiometricConfig.faceMatchThreshold.toString(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.biotech),
              title: const Text('Prueba biométrica (Fase 1)'),
              subtitle: Text(
                faceSdk.isInitialized
                    ? 'Validar licencia, liveness y match 1:1'
                    : 'Requiere SDK inicializado',
              ),
              trailing: const Icon(Icons.chevron_right),
              enabled: faceSdk.isInitialized,
              onTap: faceSdk.isInitialized
                  ? () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const BiometricTestScreen(),
                        ),
                      );
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(value),
        ],
      ),
    );
  }
}
