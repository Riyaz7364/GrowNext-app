import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class TimezoneService {
  TimezoneService() {
    tz.initializeTimeZones();
    final defaultLocation = tz.getLocation('Asia/Kolkata');
    tz.setLocalLocation(defaultLocation);
  }

  /// Set timezone dynamically (e.g., from user preference)
  void setTimeZone(String zoneName) {
    try {
      final location = tz.getLocation(zoneName);
      tz.setLocalLocation(location);
    } catch (_) {
      // fallback to default
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }
  }

  /// Safely parse a datetime string in the current local timezone
  tz.TZDateTime safeParse(String? dateString, {bool fallbackNow = true}) {
    try {
      if (dateString == null || dateString.isEmpty) {
        throw const FormatException('Empty date');
      }
      return tz.TZDateTime.parse(tz.local, dateString);
    } catch (_) {
      return fallbackNow
          ? tz.TZDateTime.now(tz.local)
          : tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, 0);
    }
  }

  /// Convert UTC DateTime to local timezone
  tz.TZDateTime from(DateTime utcDate) {
    return tz.TZDateTime.from(utcDate, tz.local);
  }

  /// Get current local time
  tz.TZDateTime now() => tz.TZDateTime.now(tz.local);
}
