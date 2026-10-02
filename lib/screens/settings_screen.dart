import 'package:flutter/material.dart';
import 'package:horas_hombre_mobile/config/app_config.dart';
import 'package:horas_hombre_mobile/config/biometric_config.dart';
import 'package:horas_hombre_mobile/models/attendance.dart';
import 'package:horas_hombre_mobile/models/location.dart';
import 'package:horas_hombre_mobile/screens/biometric_test_screen.dart';
import 'package:horas_hombre_mobile/services/api_service.dart';
import 'package:horas_hombre_mobile/services/attendance_sync_service.dart';
import 'package:horas_hombre_mobile/services/face_gallery_service.dart';
import 'package:horas_hombre_mobile/services/face_sdk_service.dart';
import 'package:horas_hombre_mobile/services/settings_service.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<KioskLocation> _locations = [];
  bool _loadingLocations = true;
  String? _locationsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLocations());
  }

  Future<void> _loadLocations() async {
    setState(() {
      _loadingLocations = true;
      _locationsError = null;
    });

    try {
      final api = context.read<ApiService>();
      final locations = await api.getLocations();
      if (!mounted) return;

      final settings = context.read<SettingsService>();
      final selectedId = settings.locationId;
      if (selectedId != null &&
          !locations.any((location) => location.locationId == selectedId)) {
        await settings.clearSelectedLocation();
      }

      setState(() {
        _locations = locations;
        _loadingLocations = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _locationsError = e.message;
        _loadingLocations = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationsError = e.toString();
        _loadingLocations = false;
      });
    }
  }

  Future<void> _setEventType(AttendanceType type) {
    return context.read<SettingsService>().setKioskEventType(type);
  }

  Future<void> _setLocation(KioskLocation? location) async {
    final settings = context.read<SettingsService>();
    if (location == null) {
      await settings.clearSelectedLocation();
      return;
    }
    await settings.setSelectedLocation(location);
  }

  @override
  Widget build(BuildContext context) {
    final faceSdk = context.read<FaceSdkService>();
    final settings = context.watch<SettingsService>();

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
                    'Kiosko',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'El tipo de evento queda fijo en este dispositivo. '
                    'Identificación: rostro 1:N, luego QR o número de empleado.',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tipo de evento',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<AttendanceType>(
                    segments: const [
                      ButtonSegment(
                        value: AttendanceType.entrada,
                        label: Text('ENTRADA'),
                        icon: Icon(Icons.login),
                      ),
                      ButtonSegment(
                        value: AttendanceType.salida,
                        label: Text('SALIDA'),
                        icon: Icon(Icons.logout),
                      ),
                    ],
                    emptySelectionAllowed: true,
                    selected: {
                      if (settings.kioskEventType != null) settings.kioskEventType!,
                    },
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) return;
                      _setEventType(selection.first);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ubicación',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualizar catálogo',
                        onPressed: _loadingLocations ? null : _loadLocations,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  if (_loadingLocations)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    )
                  else if (_locationsError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _locationsError!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    )
                  else if (_locations.isEmpty)
                    const Text(
                      'No hay ubicaciones activas. Agréguelas en el catálogo del sistema Nova.',
                    )
                  else
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _locations.any(
                            (location) => location.locationId == settings.locationId,
                          )
                          ? settings.locationId
                          : null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Seleccione una ubicación',
                      ),
                      items: _locations
                          .map(
                            (location) => DropdownMenuItem<int>(
                              value: location.locationId,
                              child: Text(location.locationName),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        final location = _locations
                            .where((item) => item.locationId == id)
                            .firstOrNull;
                        _setLocation(location);
                      },
                    ),
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
                    label: 'Umbral coincidencia 1:1',
                    value: BiometricConfig.faceMatchThreshold.toString(),
                  ),
                  _InfoRow(
                    label: 'Umbral identificación 1:N',
                    value: BiometricConfig.identifyThreshold.toString(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Consumer<FaceGalleryService>(
            builder: (context, gallery, _) {
              final synced = gallery.lastSyncedAt;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Galería facial 1:N',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        label: 'Rostros en índice',
                        value: '${gallery.cachedEmployeeCount}',
                      ),
                      _InfoRow(
                        label: 'Última sync',
                        value: synced?.toLocal().toString() ?? 'Nunca',
                      ),
                      if (gallery.lastError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            gallery.lastError!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: gallery.isSyncing || !faceSdk.isInitialized
                              ? null
                              : () async {
                                  try {
                                    final n = await gallery.syncFromBackend(
                                      force: false,
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Galería sincronizada: $n rostros',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error sync: $e'),
                                      ),
                                    );
                                  }
                                },
                          icon: gallery.isSyncing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_download),
                          label: Text(
                            gallery.isSyncing
                                ? 'Sincronizando…'
                                : 'Sincronizar galería',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const _AttendanceQueueCard(),
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

class _AttendanceQueueCard extends StatelessWidget {
  const _AttendanceQueueCard();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<AttendanceSyncService>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Asistencia sin conexión',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              sync.pendingCount == 0
                  ? 'No hay marcas pendientes.'
                  : '${sync.pendingCount} marca${sync.pendingCount == 1 ? '' : 's'} en el dispositivo'
                      '${sync.conflictCount == 0 ? '' : ' · ${sync.conflictCount} en conflicto'}.',
            ),
            if (sync.lastSyncNotice != null) ...[
              const SizedBox(height: 8),
              Text(sync.lastSyncNotice!),
            ],
            if (sync.lastError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  sync.lastError!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            const SizedBox(height: 8),
            for (final item in sync.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${item.displayName} · ${item.type.label}'),
                subtitle: Text(
                  '${item.attendanceDate} ${item.attendanceTime}'
                  '${item.isConflict ? '\n${item.serverMessage ?? 'En conflicto con un registro existente'}' : ''}',
                ),
                trailing: IconButton(
                  tooltip: 'Descartar marca local',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final discard = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Descartar marca'),
                        content: Text(
                          'Se eliminará del kiosko la ${item.type.label.toLowerCase()} de ${item.displayName} '
                          '(${item.attendanceDate} ${item.attendanceTime}). '
                          'No se enviará al servidor.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Descartar'),
                          ),
                        ],
                      ),
                    );
                    if (discard == true) {
                      await sync.discard(item.offlineEventId);
                    }
                  },
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: sync.isSyncing
                    ? null
                    : () async {
                        await sync.flush();
                        if (!context.mounted) return;
                        final notice = sync.lastSyncNotice;
                        final error = sync.lastError;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error ??
                                  notice ??
                                  (sync.pendingCount == 0
                                      ? 'No hay marcas pendientes'
                                      : 'Sin conexión. Las marcas siguen en el dispositivo.'),
                            ),
                          ),
                        );
                      },
                icon: sync.isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(sync.isSyncing ? 'Sincronizando…' : 'Sincronizar ahora'),
              ),
            ),
          ],
        ),
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
