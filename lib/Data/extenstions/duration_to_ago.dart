import 'package:timezone/timezone.dart' as tz;

extension DurationToAgo on tz.TZDateTime {
  String toAgo() {
    final difference = tz.TZDateTime.now(tz.local).difference(this);
    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).round()}mo ago';
    } else {
      return '${(difference.inDays / 365).round()}y ago';
    }
  }

  String toHumanReadable() {
    final date = this;
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$yyyy-$mm-$dd';
  }
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

extension FancyDateFormat on tz.TZDateTime? {
  String toFancyDate() {
    if (this == null) return '';
    final day = this!.day;
    final month = _monthName(this!.month);
    final year = this!.year;
    final suffix = _daySuffix(day);
    return '$day$suffix $month, $year';
  }
}

String _monthName(int month) {
  const months = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return months[month];
}

String _daySuffix(int day) {
  if (day >= 11 && day <= 13) {
    return 'th';
  }
  switch (day % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}

extension DateTimeToAmPm on tz.TZDateTime {
  /// Converts DateTime to "hh:mm AM/PM" format
  String toAmPmString() {
    int hours = hour;
    int minutes = minute;

    final ampm = hours >= 12 ? 'PM' : 'AM';
    final hour12 = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours);

    final minuteStr = minutes.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $ampm';
  }
}
