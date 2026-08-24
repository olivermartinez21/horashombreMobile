/// Configuración de entorno vía `--dart-define`.
class AppConfig {
  AppConfig._();

  static const String env = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/nova',
  );

  static const String faceSdkName = '3DiVi Face SDK';

  static bool get isDev => env == 'dev';
  static bool get isProd => env == 'prod';

  static String get displayEnv => env.toUpperCase();
}
