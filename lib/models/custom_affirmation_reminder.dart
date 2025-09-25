class CustomAffirmationReminder {
  final int? id;
  final String affirmationId;
  final bool enabled;
  // Legacy single time (kept for backward compatibility)
  final int? hour;
  final int? minute;

  // New window + count
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int dailyCount; // how many times per day within window

  final List<int> selectedDays; // 1=Mon .. 7=Sun

  const CustomAffirmationReminder({
    this.id,
    required this.affirmationId,
    this.enabled = true,
    this.hour,
    this.minute,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.dailyCount = 1,
    this.selectedDays = const [1, 2, 3, 4, 5, 6, 7],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'affirmation_id': affirmationId,
      'enabled': enabled ? 1 : 0,
      'hour': hour, // may be null post-migration
      'minute': minute,
      'start_hour': startHour,
      'start_minute': startMinute,
      'end_hour': endHour,
      'end_minute': endMinute,
      'daily_count': dailyCount,
      'selected_days': selectedDays.join(','),
    };
  }

  factory CustomAffirmationReminder.fromMap(Map<String, dynamic> map) {
    final legacyHour = map['hour'] as int?;
    final legacyMinute = map['minute'] as int?;
    final startHour = map['start_hour'] as int? ?? legacyHour ?? 9;
    final startMinute = map['start_minute'] as int? ?? legacyMinute ?? 0;
    // Default end = start + 30m if not provided
    final tmpEndMinuteTotal = (startHour * 60 + startMinute + 30) % (24 * 60);
    final defaultEndHour = tmpEndMinuteTotal ~/ 60;
    final defaultEndMinute = tmpEndMinuteTotal % 60;

    return CustomAffirmationReminder(
      id: map['id'],
      affirmationId: map['affirmation_id'] ?? '',
      enabled: (map['enabled'] ?? 1) == 1,
      hour: legacyHour,
      minute: legacyMinute,
      startHour: startHour,
      startMinute: startMinute,
      endHour: map['end_hour'] as int? ?? defaultEndHour,
      endMinute: map['end_minute'] as int? ?? defaultEndMinute,
      dailyCount: map['daily_count'] as int? ?? 1,
      selectedDays: map['selected_days'] != null
          ? (map['selected_days'] as String)
              .split(',')
              .map((e) => int.tryParse(e) ?? 1)
              .toList()
          : const [1, 2, 3, 4, 5, 6, 7],
    );
  }
}
