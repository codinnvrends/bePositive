import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:be_positive/providers/user_provider.dart';
import 'package:be_positive/providers/notification_provider.dart';
import 'package:be_positive/utils/app_theme.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:package_info_plus/package_info_plus.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  late TimeOfDay _selectedTime;
  late int _dailyCount;
  late List<int> _selectedDays;
  // Debug panel state
  int _pendingCount = 0;
  List<String> _pendingSummaries = const [];
  bool? _notificationsEnabled;
  bool? _exactAlarmsAllowed;

  @override
  void initState() {
    super.initState();
    final notificationProvider = context.read<NotificationProvider>();
    final settings = notificationProvider.settings;
    
    _selectedTime = TimeOfDay(hour: settings.hour, minute: settings.minute);
    _dailyCount = settings.dailyCount;
    _selectedDays = List.from(settings.selectedDays);

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
          _dailyCount = s.dailyCount;
          _selectedDays = List.from(s.selectedDays);
        });
        await _refreshDebug();
      }
    });
  }

  Future<void> _refreshDebug() async {
    final np = context.read<NotificationProvider>();
    final enabled = await np.areNotificationsEnabled();
    final alarms = await np.areExactAlarmsAllowed();
    final count = await np.getPendingScheduledCount();
    final summaries = await np.getPendingSummaries();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
      _exactAlarmsAllowed = alarms;
      _pendingCount = count;
      _pendingSummaries = summaries;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        // Show back button only when this screen was pushed (e.g., from Settings)
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Consumer2<NotificationProvider, UserProvider>(
        builder: (context, notificationProvider, userProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            children: [
              // Enable/Disable Notifications
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Daily Notifications',
                          style: AppTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: notificationProvider.settings.enabled,
                          onChanged: (value) {
                            notificationProvider.toggleNotifications(
                              userProvider.userProfile?.id,
                            );
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: AppTheme.spacingS),
                    
                    Text(
                      'Receive daily affirmation notifications',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textLight,
                      ),
                    ),
                    
                    if (!notificationProvider.permissionGranted) ...[
                      const SizedBox(height: AppTheme.spacingM),
                      Container(
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
                              size: 20,
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: Text(
                                'Notification permission not granted',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.warningOrange,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => notificationProvider.requestPermissions(),
                              child: const Text('Enable'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingL),
              
              // Time Selection
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification Time',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingM),
                    
                    InkWell(
                      onTap: _selectTime,
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.spacingL),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: AppTheme.primaryTeal,
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Text(
                              _formatTime(_selectedTime),
                              style: AppTheme.bodyLarge,
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: AppTheme.textLight,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingL),
              
              // Daily Count
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Affirmations',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingS),
                    
                    Text(
                      'Number of affirmations per day: $_dailyCount',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textLight,
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingM),
                    
                    Slider(
                      value: _dailyCount.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: _dailyCount.toString(),
                      onChanged: (value) {
                        setState(() {
                          _dailyCount = value.round();
                        });
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingL),
              
              // Days Selection
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Days of Week',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingM),
                    
                    Wrap(
                      spacing: AppTheme.spacingS,
                      children: List.generate(7, (index) {
                        final dayNumber = index + 1;
                        final dayName = _getDayName(dayNumber);
                        final isSelected = _selectedDays.contains(dayNumber);
                        
                        return FilterChip(
                          label: Text(dayName),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedDays.add(dayNumber);
                              } else {
                                _selectedDays.remove(dayNumber);
                              }
                            });
                          },
                          selectedColor: AppTheme.primaryTeal.withOpacity(0.2),
                          checkmarkColor: AppTheme.primaryTeal,
                        );
                      }),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingL),
              
              // Test Notification
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Notifications',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingS),
                    
                    Text(
                      'Send a test notification to make sure everything works',
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
                        label: const Text('Send Test Notification'),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingL),

              // Scheduling Utilities
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scheduling Utilities',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingS),

                    if (!notificationProvider.permissionGranted) ...[
                      Text(
                        'Notifications permission not granted',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.warningOrange),
                      ),
                    ],

                    const SizedBox(height: AppTheme.spacingM),

                    Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await notificationProvider.openExactAlarmsSettings();
                          },
                          child: const Text('Open Alarm Permission'),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await notificationProvider.reschedule();
                            final count = await notificationProvider.getPendingScheduledCount();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Scheduled $count notifications')),
                            );
                          },
                          child: const Text('Reschedule & Count'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.spacingM),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        final info = await PackageInfo.fromPlatform();
                        // Launch system notifications settings for this app
                        const action = 'android.settings.APP_NOTIFICATION_SETTINGS';
                        final intent = AndroidIntent(
                          action: action,
                          arguments: <String, dynamic>{
                            // For Android 8+ (API 26+)
                            'android.provider.extra.APP_PACKAGE': info.packageName,
                            // Some OEMs/versions use these extras
                            'app_package': info.packageName,
                            'app_uid': 0,
                          },
                        );
                        await intent.launch();
                      },
                      child: const Text('Open App Notification Settings'),
                    ),
                  ),
                ],
              ),
          ),

          const SizedBox(height: AppTheme.spacingL),

          // Debug Panel
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            decoration: AppTheme.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Debug Panel',
                  style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppTheme.spacingS),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Notifications enabled: ${_notificationsEnabled == null ? '—' : (_notificationsEnabled! ? 'Yes' : 'No')}'),
                          Text('Exact alarms allowed: ${_exactAlarmsAllowed == null ? '—' : (_exactAlarmsAllowed! ? 'Yes' : 'No')}'),
                          Text('Pending scheduled: $_pendingCount'),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Column(
                      children: [
                        OutlinedButton(
                          onPressed: _refreshDebug,
                          child: const Text('Refresh Status'),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        OutlinedButton(
                          onPressed: () async {
                            await context.read<NotificationProvider>().scheduleOneOffIn(const Duration(seconds: 15));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('One-off scheduled in 15s')),
                            );
                            await _refreshDebug();
                          },
                          child: const Text('Schedule One-off (15s)'),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        OutlinedButton(
                          onPressed: () async {
                            await context.read<NotificationProvider>().cancelAllNotifications();
                            await _refreshDebug();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cancelled all scheduled notifications')),
                            );
                          },
                          child: const Text('Cancel All'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),
                if (_pendingSummaries.isNotEmpty) ...[
                  Text('Pending list:', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppTheme.spacingS),
                  ..._pendingSummaries.take(10).map((e) => Text(e)).toList(),
                  if (_pendingSummaries.length > 10) Text('...and ${_pendingSummaries.length - 10} more'),
                ] else ...[
                  Text('No pending notifications.'),
                ],
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

  Future<void> _saveSettings() async {
    final notificationProvider = context.read<NotificationProvider>();
    final userProvider = context.read<UserProvider>();
    
    final newSettings = notificationProvider.settings.copyWith(
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      dailyCount: _dailyCount,
      selectedDays: _selectedDays,
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
