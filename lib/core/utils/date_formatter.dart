import 'package:intl/intl.dart';

/// Date formatting helper for Indian editorial style.
class DateFormatter {
  static final DateFormat _editorialFormat = DateFormat('MMMM d, yyyy');
  static final DateFormat _shortFormat = DateFormat('d MMM yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');

  static String formatEditorial(DateTime dateTime) {
    return _editorialFormat.format(dateTime);
  }

  static String formatShort(DateTime dateTime) {
    return _shortFormat.format(dateTime);
  }

  static String formatWithTime(DateTime dateTime) {
    return '${_shortFormat.format(dateTime)} at ${_timeFormat.format(dateTime)}';
  }

  static String timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 30) {
      return formatShort(dateTime);
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
