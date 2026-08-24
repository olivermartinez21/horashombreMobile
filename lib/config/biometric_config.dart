/// Umbrales biométricos iniciales (ajustar con pruebas en dispositivo real).
///
/// El match usa el score de VERIFICATION_MODULE de 3DiVi (mismo umbral que Simose).
/// El liveness 2d_light se aprueba por categoría REAL, no por este umbral.
class BiometricConfig {
  BiometricConfig._();

  static const double livenessThreshold = 0.90;
  static const double faceMatchThreshold = 0.75;
}
