const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// 15 Jan 2027
String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Just now, 5m ago, 3h ago, 2d ago, or a date after a week.
String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return formatDate(t);
}
/// 1400 -> 1.4K, 2300000 -> 2.3M, 380 -> 380
String formatCount(int n) {
  if (n >= 1000000) return '${_trimZero(n / 1000000)}M';
  if (n >= 1000) return '${_trimZero(n / 1000)}K';
  return '$n';
}

String _trimZero(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}