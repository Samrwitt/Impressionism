/// Backend API configuration.
///
/// Override at build/run time:
///   flutter run --dart-define=API_BASE=http://192.168.1.112:8008
///   flutter build apk --dart-define=API_BASE=http://192.168.1.112:8008
class AppConfig {
  static const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://192.168.1.112:8008',
  );
}
