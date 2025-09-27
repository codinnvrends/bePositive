import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:be_positive/providers/user_provider.dart';
import 'package:be_positive/providers/notification_provider.dart';
import 'package:be_positive/utils/app_theme.dart';
import 'package:be_positive/widgets/frequency_selector.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:package_info_plus/package_info_plus.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

// Simple editable row with a label on the left and a trailing widget on the right
class _EditRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;
  final double? labelWidth;

  const _EditRow({
    required this.label,
    required this.trailing,
    this.onTap,
    this.labelWidth,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final target = screenW * 0.42; // prefer ~42% for label area
    final computedLabelW = (labelWidth ?? target).clamp(120, 160).toDouble();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
        child: Row(
          children: [
            SizedBox(
              width: computedLabelW,
              child: Text(
                label,
                style: AppTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

// Stepper row with - and + controls, and a central dynamic value text
class _StepperRow extends StatelessWidget {
  final String label;
  final String Function() valueBuilder;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final double? labelWidth;

  const _StepperRow({
    required this.label,
    required this.valueBuilder,
    required this.onDecrement,
    required this.onIncrement,
    this.labelWidth = 160,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final computedLabelW = (labelWidth ?? screenW * 0.5).clamp(120, 180).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
      child: Row(
        children: [
          SizedBox(
            width: computedLabelW,
            child: Text(
              label,
              style: AppTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _RoundIconButton(icon: Icons.remove, onPressed: onDecrement, size: 32, iconSize: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  valueBuilder(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  softWrap: false,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _RoundIconButton(icon: Icons.add, onPressed: onIncrement, size: 32, iconSize: 18),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.size = 40,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          minimumSize: Size(size, size),
        ),
        onPressed: onPressed,
        child: Icon(icon, size: iconSize),
      ),
    );
  }
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  late TimeOfDay _selectedTime;
  late TimeOfDay _endTime;
  late int _dailyCount;
  late List<int> _selectedDays;
  late bool _useFrequencyMode;
  late int _frequencyValue;
  late String _frequencyUnit;
  late bool _showOnLockScreen;

  @override
  void initState() {
    super.initState();
    final notificationProvider = context.read<NotificationProvider>();
    final settings = notificationProvider.settings;
    
    _selectedTime = TimeOfDay(hour: settings.hour, minute: settings.minute);
    _endTime = TimeOfDay(hour: settings.endHour, minute: settings.endMinute);
    _dailyCount = settings.dailyCount;
    _selectedDays = List.from(settings.selectedDays);
    _useFrequencyMode = settings.useFrequencyMode;
    _frequencyValue = settings.frequencyValue;
    _frequencyUnit = settings.frequencyUnit;
    _showOnLockScreen = settings.showOnLockScreen;

    // Initialize provider (permissions + load settings) after first frame
    // so that context.read works safely and UI can update via notifyListeners
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userProvider = context.read<UserProvider>();
      await context.read<NotificationProvider>().initialize(
            userProvider.userProfile?.id,
          );
      if (mounted) {
        final s = context.read<NotificationProvider>().settings;
        setState(() {
          _selectedTime = TimeOfDay(hour: s.hour, minute: s.minute);
          _endTime = TimeOfDay(hour: s.endHour, minute: s.endMinute);
          _dailyCount = s.dailyCount;
          _selectedDays = List.from(s.selectedDays);
          _useFrequencyMode = s.useFrequencyMode;
          _frequencyValue = s.frequencyValue;
          _frequencyUnit = s.frequencyUnit;
          _showOnLockScreen = s.showOnLockScreen;
        });
      }
    });
  }

  // Helpers for start/end/count relationship (inside State)
  int _minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

  void _ensureEndAfterStart() {
    final start = _minutesOf(_selectedTime);
    final end = _minutesOf(_endTime);
    if (end <= start) {
      final newEnd = (start + 15) % (24 * 60);
      _endTime = TimeOfDay(hour: newEnd ~/ 60, minute: newEnd % 60);
    }
  }

  int _maxAllowedCount() {
    final start = _minutesOf(_selectedTime);
    final end = _minutesOf(_endTime);
    final total = (end - start).clamp(0, 24 * 60);
    final maxByFive = (total ~/ 5);
    return maxByFive.clamp(1, 96);
  }

  void _enforceCountCap() {
    final max = _maxAllowedCount();
    if (_dailyCount > max) _dailyCount = max;
    if (_dailyCount < 1) _dailyCount = 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit reminder'),
        // Show back button only when this screen was pushed (e.g., from Settings)
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: Consumer2<NotificationProvider, UserProvider>(
        builder: (context, notificationProvider, userProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            children: [
              // Top enable switch
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                  vertical: AppTheme.spacingM,
                ),
                decoration: AppTheme.cardDecoration,
                child: Row(
                  children: [
                    Text(
                      'Reminders',
                      style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Switch(
                      value: notificationProvider.settings.enabled,
                      onChanged: (value) async {
                        await notificationProvider.toggleNotifications(
                          userProvider.userProfile?.id,
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingL),

              // Permission Banner
              if (!notificationProvider.permissionGranted) Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: AppTheme.warningOrange.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      color: AppTheme.warningOrange,
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    const Expanded(
                      child: Text('Reminder permission not granted'),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    OutlinedButton(
                      onPressed: () => notificationProvider.requestPermissions(),
                      child: const Text('Enable Reminders'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingL),

              // Frequency Selector
              FrequencySelector(
                useFrequencyMode: _useFrequencyMode,
                frequencyValue: _frequencyValue,
                frequencyUnit: _frequencyUnit,
                onChanged: (useFrequencyMode, value, unit) {
                  setState(() {
                    _useFrequencyMode = useFrequencyMode;
                    _frequencyValue = value;
                    _frequencyUnit = unit;
                  });
                  // Auto-save frequency settings
                  context.read<NotificationProvider>().updateSettings(
                    context.read<UserProvider>().userProfile?.id,
                    context.read<NotificationProvider>().settings.copyWith(
                      useFrequencyMode: _useFrequencyMode,
                      frequencyValue: _frequencyValue,
                      frequencyUnit: _frequencyUnit,
                    ),
                  );
                },
              ),

              const SizedBox(height: AppTheme.spacingL),

              // Lock Screen Settings
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: AppTheme.cardDecoration,
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      color: AppTheme.primaryTeal,
                      size: 24,
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Show on Lock Screen',
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Display full affirmation content on lock screen',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _showOnLockScreen,
                      onChanged: (value) {
                        setState(() {
                          _showOnLockScreen = value;
                        });
                        // Auto-save lock screen setting
                        context.read<NotificationProvider>().updateSettings(
                          context.read<UserProvider>().userProfile?.id,
                          context.read<NotificationProvider>().settings.copyWith(
                            showOnLockScreen: _showOnLockScreen,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingL),

              // Edit reminder card styled controls (only show for window-based mode)
              if (!_useFrequencyMode)
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // How many with +/-
                    _StepperRow(
                      label: 'How many',
                      valueBuilder: () => '${_dailyCount}x',
                      onDecrement: () async {
                        setState(() {
                          _dailyCount = (_dailyCount - 1).clamp(1, _maxAllowedCount());
                        });
                        await context.read<NotificationProvider>().updateSettings(
                          context.read<UserProvider>().userProfile?.id,
                          context.read<NotificationProvider>().settings.copyWith(
                                hour: _selectedTime.hour,
                                minute: _selectedTime.minute,
                                dailyCount: _dailyCount,
                                selectedDays: _selectedDays,
                                endHour: _endTime.hour,
                                endMinute: _endTime.minute,
                              ),
                        );
                      },
                      onIncrement: () async {
                        setState(() {
                          _dailyCount = (_dailyCount + 1).clamp(1, _maxAllowedCount());
                        });
                        await context.read<NotificationProvider>().updateSettings(
                          context.read<UserProvider>().userProfile?.id,
                          context.read<NotificationProvider>().settings.copyWith(
                                hour: _selectedTime.hour,
                                minute: _selectedTime.minute,
                                dailyCount: _dailyCount,
                                selectedDays: _selectedDays,
                                endHour: _endTime.hour,
                                endMinute: _endTime.minute,
                              ),
                        );
                      },
                    ),

                    const Divider(height: AppTheme.spacingXL),

                    // Start at with +/- 15m
                    _StepperRow(
                      label: 'Start at',
                      valueBuilder: () => _formatTime(_selectedTime),
                      onDecrement: () async {
                        setState(() {
                          final m = (_selectedTime.hour * 60 + _selectedTime.minute - 15) % (24 * 60);
                          _selectedTime = TimeOfDay(hour: m ~/ 60, minute: m % 60);
                          _enforceCountCap();
                          _ensureEndAfterStart();
                        });
                        await context.read<NotificationProvider>().updateSettings(
                          context.read<UserProvider>().userProfile?.id,
                          context.read<NotificationProvider>().settings.copyWith(
                                hour: _selectedTime.hour,
                                minute: _selectedTime.minute,
                                dailyCount: _dailyCount,
                                selectedDays: _selectedDays,
                                endHour: _endTime.hour,
                                endMinute: _endTime.minute,
                              ),
                        );
                      },
                      onIncrement: () async {
                        setState(() {
                          final m = (_selectedTime.hour * 60 + _selectedTime.minute + 15) % (24 * 60);
                          _selectedTime = TimeOfDay(hour: m ~/ 60, minute: m % 60);
                          _enforceCountCap();
                          _ensureEndAfterStart();
                        });
                        await context.read<NotificationProvider>().updateSettings(
                          context.read<UserProvider>().userProfile?.id,
                          context.read<NotificationProvider>().settings.copyWith(
                                hour: _selectedTime.hour,
                                minute: _selectedTime.minute,
                                dailyCount: _dailyCount,
                                selectedDays: _selectedDays,
                                endHour: _endTime.hour,
                                endMinute: _endTime.minute,
                              ),
                        );
                      },
                    ),

                    const Divider(height: AppTheme.spacingXL),

                    // End at with +/- 15m (independent)
                    _StepperRow(
                      label: 'End at',
                      valueBuilder: () => _formatTime(_endTime),
                      onDecrement: () async {
                        setState(() {
                          final total = (_endTime.hour * 60 + _endTime.minute - 15);
                          var minutes = (total % (24 * 60) + (24 * 60)) % (24 * 60);
                          _endTime = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
                          _ensureEndAfterStart();
                          _enforceCountCap();
                        });
                        await context.read<NotificationProvider>().updateSettings(
                          context.read<UserProvider>().userProfile?.id,
                          context.read<NotificationProvider>().settings.copyWith(
                                hour: _selectedTime.hour,
                                minute: _selectedTime.minute,
                                dailyCount: _dailyCount,
                                selectedDays: _selectedDays,
                                endHour: _endTime.hour,
                                endMinute: _endTime.minute,
                              ),
                        );
                      },
                      onIncrement: () async {
                        setState(() {
                          final minutesTotal = (_endTime.hour * 60 + _endTime.minute + 15) % (24 * 60);
                          _endTime = TimeOfDay(hour: minutesTotal ~/ 60, minute: minutesTotal % 60);
                          _ensureEndAfterStart();
                          _enforceCountCap();
                        });
                        await context.read<NotificationProvider>().updateSettings(
                          context.read<UserProvider>().userProfile?.id,
                          context.read<NotificationProvider>().settings.copyWith(
                                hour: _selectedTime.hour,
                                minute: _selectedTime.minute,
                                dailyCount: _dailyCount,
                                selectedDays: _selectedDays,
                                endHour: _endTime.hour,
                                endMinute: _endTime.minute,
                              ),
                        );
                      },
                    ),

                    const SizedBox(height: AppTheme.spacingM),

                    // Day selection
                    Text('Repeat', style: AppTheme.bodyMedium),
                    const SizedBox(height: AppTheme.spacingS),
                    Wrap(
                      spacing: AppTheme.spacingS,
                      runSpacing: AppTheme.spacingS,
                      children: [
                        for (final day in [7,1,2,3,4,5,6]) // S M T W T F S
                          ChoiceChip(
                            label: SizedBox(
                              width: 28,
                              height: 28,
                              child: Center(
                                child: Text(
                                  _getDayLetter(day),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ),
                            selected: _selectedDays.contains(day),
                            onSelected: (selected) async {
                              setState(() {
                                if (selected) {
                                  if (!_selectedDays.contains(day)) _selectedDays.add(day);
                                } else {
                                  _selectedDays.remove(day);
                                }
                              });
                              await context.read<NotificationProvider>().updateSettings(
                                context.read<UserProvider>().userProfile?.id,
                                context.read<NotificationProvider>().settings.copyWith(
                                      hour: _selectedTime.hour,
                                      minute: _selectedTime.minute,
                                      dailyCount: _dailyCount,
                                      selectedDays: _selectedDays,
                                    ),
                              );
                            },
                            shape: const CircleBorder(),
                            selectedColor: AppTheme.primaryTeal.withOpacity(0.2),
                            labelStyle: Theme.of(context).textTheme.bodySmall,
                            showCheckmark: false,
                          ),
                      ],
                    ),

                    const Divider(height: AppTheme.spacingXL),

                    // Sound picker
                    _EditRow(
                      label: 'Sound',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('Positive'),
                          SizedBox(width: AppTheme.spacingS),
                          Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () async {
                        // Open Android channel settings directly for our channel
                        try {
                          final info = await PackageInfo.fromPlatform();
                          final intent = AndroidIntent(
                            action: 'android.settings.CHANNEL_NOTIFICATION_SETTINGS',
                            arguments: <String, dynamic>{
                              'android.provider.extra.APP_PACKAGE': info.packageName,
                              'android.provider.extra.CHANNEL_ID': 'affirmation_channel',
                            },
                          );
                          await intent.launch();
                        } catch (_) {
                          // Fallback to app-level settings
                          final info = await PackageInfo.fromPlatform();
                          final fallback = AndroidIntent(
                            action: 'android.settings.APP_NOTIFICATION_SETTINGS',
                            arguments: <String, dynamic>{
                              'android.provider.extra.APP_PACKAGE': info.packageName,
                            },
                          );
                          await fallback.launch();
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingL),

              // Test Reminder
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test reminders',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingS),
                    
                    Text(
                      'Send a test reminder to make sure everything works',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textLight,
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingM),
                    
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => notificationProvider.showTestNotification(),
                        icon: const Icon(Icons.notifications_active),
                        label: const Text('Send Test Reminder'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour == 0 ? 12 : hour}:$minute $period';
  }

  String _getDayName(int dayNumber) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dayNumber - 1];
  }

  String _getDayLetter(int dayNumber) {
    // 1=Mon..7=Sun
    switch (dayNumber) {
      case 1:
        return 'M';
      case 2:
        return 'T';
      case 3:
        return 'W';
      case 4:
        return 'T';
      case 5:
        return 'F';
      case 6:
        return 'S';
      case 7:
        return 'S';
      default:
        return '';
    }
  }

  Future<void> _saveSettings() async {
    final notificationProvider = context.read<NotificationProvider>();
    final userProvider = context.read<UserProvider>();
    
    final newSettings = notificationProvider.settings.copyWith(
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      dailyCount: _dailyCount,
      selectedDays: _selectedDays,
      endHour: _endTime.hour,
      endMinute: _endTime.minute,
      useFrequencyMode: _useFrequencyMode,
      frequencyValue: _frequencyValue,
      frequencyUnit: _frequencyUnit,
      showOnLockScreen: _showOnLockScreen,
    );
    
    final success = await notificationProvider.updateSettings(
      userProvider.userProfile?.id,
      newSettings,
    );
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Notification settings saved'
            : 'Failed to save notification settings'),
      ),
    );
    
    if (success && Navigator.of(context).canPop()) {
      context.pop();
    }
  }
}
