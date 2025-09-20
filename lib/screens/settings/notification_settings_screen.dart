import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
import '../../providers/notification_provider.dart';
import '../../utils/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  late TimeOfDay _selectedTime;
  late int _dailyCount;
  late List<int> _selectedDays;

  @override
  void initState() {
    super.initState();
    final notificationProvider = context.read<NotificationProvider>();
    final settings = notificationProvider.settings;
    
    _selectedTime = TimeOfDay(hour: settings.hour, minute: settings.minute);
    _dailyCount = settings.dailyCount;
    _selectedDays = List.from(settings.selectedDays);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
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
                            if (userProvider.hasProfile) {
                              notificationProvider.toggleNotifications(
                                userProvider.userProfile!.id,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: AppTheme.spacingS),
                    
                    Text(
                      'Receive daily affirmation reminders',
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
    
    if (!userProvider.hasProfile) return;
    
    final newSettings = notificationProvider.settings.copyWith(
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      dailyCount: _dailyCount,
      selectedDays: _selectedDays,
    );
    
    final success = await notificationProvider.updateSettings(
      userProvider.userProfile!.id,
      newSettings,
    );
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification settings saved'),
        ),
      );
      context.pop();
    }
  }
}
