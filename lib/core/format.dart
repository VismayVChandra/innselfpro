/// Small date/money formatters. Hand-rolled rather than pulling in
/// `intl`, since the app is single-locale (en-IN) and only needs these
/// four shapes.
library;

const _months = [
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

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "TUESDAY, 20 AUGUST" -- the eyebrow above the home greeting.
String formatHeaderDate(DateTime date) {
  final local = date.toLocal();
  final weekday = _weekdays[local.weekday - 1];
  return '$weekday, ${local.day} ${_months[local.month - 1]}'.toUpperCase();
}

/// "20 Aug" -- compact stamp on list rows.
String formatShortDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_months[local.month - 1].substring(0, 3)}';
}

/// "20 Aug 2026 · 14:32" -- full stamp on detail screens.
String formatDateTime(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_months[local.month - 1].substring(0, 3)} '
      '${local.year}  ·  $hour:$minute';
}

/// "2 hours ago" / "3 days ago" -- used where recency matters more than
/// the exact time, e.g. the notification list.
String formatRelative(DateTime date) {
  final diff = DateTime.now().difference(date.toLocal());
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
  return formatShortDate(date);
}

/// "₹1,240" -- whole rupees with Indian digit grouping (last three
/// digits, then pairs).
String formatRupees(num amount) {
  final whole = amount.round().abs().toString();
  final sign = amount < 0 ? '-' : '';
  if (whole.length <= 3) return '$sign₹$whole';

  final lastThree = whole.substring(whole.length - 3);
  var rest = whole.substring(0, whole.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '$sign₹${groups.join(',')},$lastThree';
}

/// "bid_accepted" -> "Bid accepted".
String humanizeStatus(String status) {
  final words = status.replaceAll('_', ' ');
  if (words.isEmpty) return words;
  return words[0].toUpperCase() + words.substring(1);
}

/// Normalises free-text `profiles.phone` into a dialable E.164-ish
/// number, or null when it isn't a plausible 10-digit Indian mobile
/// number. Strips everything non-digit, drops a leading trunk `0`, and
/// unwraps an already-present `91` country code before prepending `+91`.
String? normalisePhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('0')) digits = digits.substring(1);
  if (digits.length == 12 && digits.startsWith('91')) {
    digits = digits.substring(2);
  }
  if (digits.length != 10) return null;
  return '+91$digits';
}

/// Initials for an avatar tile: "Vismay Chandra" -> "VC".
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
