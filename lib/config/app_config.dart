/// Configuración de entorno vía `--dart-define`.
class AppConfig {
  AppConfig._();

  static const String env = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'qa',
  );

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://ec2-54-237-104-7.compute-1.amazonaws.com:8080/nova',
  );

  static const String kioskAdminPin = String.fromEnvironment('KIOSK_ADMIN_PIN');

  static const String faceSdkName = '3DiVi Face SDK';

  static bool get isDev => env == 'dev';
  static bool get isProd => env == 'prod';
  static bool get hasValidKioskAdminPin =>
      RegExp(r'^\d{6}$').hasMatch(kioskAdminPin);

  static String get displayEnv => env.toUpperCase();
}
