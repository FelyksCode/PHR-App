/// Global app behavior mode.
///
/// Use `--dart-define=APP_MODE=simulation` to enable simulation mode.
enum AppMode { production, simulation }

class AppConfig {
  // Compile-time switch (works in main isolate + WorkManager background isolates).
  static const String _rawMode = String.fromEnvironment(
    'APP_MODE',
    defaultValue: 'production',
  );

  static AppMode get mode {
    switch (_rawMode.trim().toLowerCase()) {
      case 'simulation':
        return AppMode.simulation;
      case 'production':
      default:
        return AppMode.production;
    }
  }

  static bool get isSimulation => mode == AppMode.simulation;
  static bool get isProduction => mode == AppMode.production;
}
