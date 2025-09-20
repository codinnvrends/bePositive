class NotificationSettings {
  final bool enabled;
  final int hour;
  final int minute;
  final int dailyCount;
  final List<int> selectedDays; // 1-7 for Monday-Sunday

  const NotificationSettings({
    this.enabled = true,
    this.hour = 9,
    this.minute = 0,
    this.dailyCount = 3,
    this.selectedDays = const [1, 2, 3, 4, 5, 6, 7], // All days by default
  });

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled ? 1 : 0,
      'hour': hour,
      'minute': minute,
      'daily_count': dailyCount,
      'selected_days': selectedDays.join(','),
    };
  }

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      enabled: (map['enabled'] ?? 1) == 1,
      hour: map['hour'] ?? 9,
      minute: map['minute'] ?? 0,
      dailyCount: map['daily_count'] ?? 3,
      selectedDays: map['selected_days'] != null
          ? (map['selected_days'] as String)
              .split(',')
              .map((e) => int.tryParse(e) ?? 1)
              .toList()
          : [1, 2, 3, 4, 5, 6, 7],
    );
  }

  NotificationSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    int? dailyCount,
    List<int>? selectedDays,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      dailyCount: dailyCount ?? this.dailyCount,
      selectedDays: selectedDays ?? this.selectedDays,
    );
  }

  String get timeString {
    final hourStr = hour.toString().padLeft(2, '0');
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr';
  }

  String get formattedTime {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }
}
