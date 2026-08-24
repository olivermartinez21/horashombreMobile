import 'package:flutter_test/flutter_test.dart';
import 'package:horas_hombre_mobile/main.dart';
import 'package:horas_hombre_mobile/services/face_sdk_service.dart';
import 'package:horas_hombre_mobile/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Home screen shows attendance actions', (WidgetTester tester) async {
    final settingsService = SettingsService();
    await settingsService.load();

    await tester.pumpWidget(
      HorasHombreApp(
        settingsService: settingsService,
        faceSdkService: FaceSdkService(),
      ),
    );

    expect(find.text('Asistencia'), findsOneWidget);
    expect(find.text('ENTRADA'), findsOneWidget);
    expect(find.text('SALIDA'), findsOneWidget);
  });
}
