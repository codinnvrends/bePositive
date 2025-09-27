class NotificationSettings {
  final bool enabled;
  final int hour;
  final int minute;
  final int dailyCount;
  final List<int> selectedDays; // 1-7 for Monday-Sunday
  final int endHour;   // New: end of reminder window
  final int endMinute; // New: end of reminder window
  final bool showOnLockScreen; // New: show notifications on lock screen
  final bool useFrequencyMode; // New: use frequency-based notifications instead of window-based
  final int frequencyValue; // New: frequency value (e.g., 30 for "every 30 minutes")
  final String frequencyUnit; // New: frequency unit ('minutes', 'hours', 'days')

  const NotificationSettings({
    this.enabled = true,
    this.hour = 9,
    this.minute = 0,
    this.dailyCount = 3,
    this.selectedDays = const [1, 2, 3, 4, 5, 6, 7], // All days by default
    this.endHour = 21,
    this.endMinute = 0,
    this.showOnLockScreen = true,
    this.useFrequencyMode = false, // Default to window-based mode
    this.frequencyValue = 2, // Default: every 2 hours
    this.frequencyUnit = 'hours', // Default unit
  });

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled ? 1 : 0,
      'hour': hour,
      'minute': minute,
      'daily_count': dailyCount,
      'selected_days': selectedDays.join(','),
      'end_hour': endHour,
      'end_minute': endMinute,
      'show_on_lock_screen': showOnLockScreen ? 1 : 0,
      'use_frequency_mode': useFrequencyMode ? 1 : 0,
      'frequency_value': frequencyValue,
      'frequency_unit': frequencyUnit,
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
      endHour: map['end_hour'] ?? (map['hour'] ?? 9),
      endMinute: map['end_minute'] ?? ((map['minute'] ?? 0) + 30) % 60,
      showOnLockScreen: (map['show_on_lock_screen'] ?? 1) == 1,
      useFrequencyMode: (map['use_frequency_mode'] ?? 0) == 1,
      frequencyValue: map['frequency_value'] ?? 2,
      frequencyUnit: map['frequency_unit'] ?? 'hours',
    );
  }

  NotificationSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    int? dailyCount,
    List<int>? selectedDays,
    int? endHour,
    int? endMinute,
    bool? showOnLockScreen,
    bool? useFrequencyMode,
    int? frequencyValue,
    String? frequencyUnit,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      dailyCount: dailyCount ?? this.dailyCount,
      selectedDays: selectedDays ?? this.selectedDays,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      showOnLockScreen: showOnLockScreen ?? this.showOnLockScreen,
      useFrequencyMode: useFrequencyMode ?? this.useFrequencyMode,
      frequencyValue: frequencyValue ?? this.frequencyValue,
      frequencyUnit: frequencyUnit ?? this.frequencyUnit,
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

  String get formattedEndTime {
    final period = endHour >= 12 ? 'PM' : 'AM';
    final displayHour = endHour == 0 ? 12 : (endHour > 12 ? endHour - 12 : endHour);
    final minuteStr = endMinute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }

  /// Get frequency description for display
  String get frequencyDescription {
    if (!useFrequencyMode) return 'Window-based';
    
    final unit = frequencyValue == 1 
        ? frequencyUnit.substring(0, frequencyUnit.length - 1) // Remove 's' for singular
        : frequencyUnit;
    
    return 'Every $frequencyValue $unit';
  }

  /// Get frequency in minutes for scheduling calculations
  int get frequencyInMinutes {
    if (!useFrequencyMode) return 0;
    
    switch (frequencyUnit) {
      case 'minutes':
        return frequencyValue;
      case 'hours':
        return frequencyValue * 60;
      case 'days':
        return frequencyValue * 24 * 60;
      default:
        return frequencyValue * 60; // Default to hours
    }
  }

  /// Check if frequency settings are valid
  bool get isValidFrequency {
    if (!useFrequencyMode) return true;
    
    switch (frequencyUnit) {
      case 'minutes':
        return frequencyValue >= 1 && frequencyValue <= 1440; // 1 minute to 24 hours
      case 'hours':
        return frequencyValue >= 1 && frequencyValue <= 24; // 1 to 24 hours
      case 'days':
        return frequencyValue >= 1 && frequencyValue <= 7; // 1 to 7 days
      default:
        return false;
    }
  }

  /// Get suggested frequency values for each unit
  static List<int> getFrequencyOptions(String unit) {
    switch (unit) {
      case 'minutes':
        return [1, 2, 3, 5, 10, 15, 30, 45, 60, 90, 120]; // 1 minute to 2 hours
      case 'hours':
        return [1, 2, 3, 4, 6, 8, 12, 24]; // 1 to 24 hours
      case 'days':
        return [1, 2, 3, 7]; // 1 to 7 days
      default:
        return [1, 2, 3, 4, 6, 8, 12];
    }
  }

  /// Get all available frequency units
  static List<String> get availableUnits => ['minutes', 'hours', 'days'];
}
