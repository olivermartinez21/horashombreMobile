/// Umbrales biométricos iniciales (ajustar con pruebas en dispositivo real).
///
/// El match 1:1 usa VERIFICATION_MODULE; la identificación 1:N usa MATCHER_MODULE.
/// El liveness 2d_light se aprueba por categoría REAL, no por este umbral.
class BiometricConfig {
  BiometricConfig._();

  static const double livenessThreshold = 0.90;
  static const double faceMatchThreshold = 0.75;

  /// Score mínimo del MATCHER_MODULE para aceptar identificación 1:N.
  static const double identifyThreshold = 0.75;
}
