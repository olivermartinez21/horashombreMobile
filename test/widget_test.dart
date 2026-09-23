import 'package:flutter_test/flutter_test.dart';
import 'package:horas_hombre_mobile/main.dart';
import 'package:horas_hombre_mobile/models/attendance.dart';
import 'package:horas_hombre_mobile/models/location.dart';
import 'package:horas_hombre_mobile/services/face_sdk_service.dart';
import 'package:horas_hombre_mobile/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Home screen asks to configure kiosk when unset', (
    WidgetTester tester,
  ) async {
    final settingsService = SettingsService();
    await settingsService.load();

    await tester.pumpWidget(
      HorasHombreApp(
        settingsService: settingsService,
        faceSdkService: FaceSdkService(),
      ),
    );

    expect(find.text('Asistencia'), findsOneWidget);
    expect(find.text('Configure el kiosko'), findsOneWidget);
    expect(find.text('ENTRADA'), findsNothing);
    expect(find.text('SALIDA'), findsNothing);

    await tester.tap(find.text('Ir a Ajustes'));
    await tester.pumpAndSettle();

    expect(find.text('PIN administrativo no configurado'), findsOneWidget);
    expect(find.text('Ajustes'), findsNothing);
  });

  testWidgets('Home screen shows locked kiosk event', (
    WidgetTester tester,
  ) async {
    final settingsService = SettingsService();
    await settingsService.load();
    await settingsService.setKioskEventType(AttendanceType.entrada);
    await settingsService.setSelectedLocation(
      const KioskLocation(locationId: 1, locationName: 'Acceso principal'),
    );

    await tester.pumpWidget(
      HorasHombreApp(
        settingsService: settingsService,
        faceSdkService: FaceSdkService(),
      ),
    );

    expect(find.text('Asistencia'), findsOneWidget);
    expect(find.text('Kiosko de entrada'), findsOneWidget);
    expect(find.text('Acceso principal'), findsOneWidget);
    expect(find.text('ENTRADA'), findsOneWidget);
    expect(find.text('SALIDA'), findsNothing);
  });
}
