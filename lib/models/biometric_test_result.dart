/// Resultado de la prueba biométrica aislada (Fase 1 AGENTS.md).
class BiometricTestResult {
  const BiometricTestResult({
    required this.isLive,
    required this.livenessScore,
    required this.isMatch,
    required this.faceMatchScore,
  });

  final bool isLive;
  final double livenessScore;
  final bool isMatch;
  final double faceMatchScore;

  bool get passed => isLive && isMatch;
}
