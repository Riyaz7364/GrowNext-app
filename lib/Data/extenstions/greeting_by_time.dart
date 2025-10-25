import 'package:timezone/timezone.dart' as tz;

extension GreetingByTime on String {
  String greet() {
    final hour = tz.TZDateTime.now(tz.local).hour;

    String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = "Good Morning";
    } else if (hour >= 12 && hour < 17) {
      greeting = "Good Afternoon";
    } else if (hour >= 17 && hour < 21) {
      greeting = "Good Evening";
    } else {
      greeting = "Good Night";
    }

    return "$greeting, $this";
  }
}
