import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/notification_settings.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Initialize timezone database for zoned scheduling
    try {
      tz.initializeTimeZones();
      // Optionally, set local location if needed. Without explicit set, tz.local
      // falls back to the device environment where supported.
      // If needed later, integrate flutter_native_timezone to set location.
    } catch (_) {
      // Safe to ignore; plugin will still work with best effort
    }
    _initialized = true;
  }

  Future<bool> areNotificationsEnabled() async {
    return await isPermissionGranted();
  }

  Future<int> getPendingCount() async {
    final list = await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    return list.length;
  }

  Future<List<PendingNotificationRequest>> getPendingRequests() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  Future<void> scheduleOneOffIn(Duration delay, {String? title, String? body}) async {
    final when = DateTime.now().add(delay);
    await _scheduleNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000000),
      title: title ?? 'Debug One-off Notification',
      body: body ?? 'This was scheduled ${delay.inSeconds}s ago',
      scheduledDate: when,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
    // Handle notification tap - navigate to app
  }

  Future<bool> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    bool granted = true;

    if (androidImplementation != null) {
      final bool? result = await androidImplementation.requestNotificationsPermission();
      // If result is null (older Android) or false, fall back to checking current status
      if (result == null) {
        granted = await isPermissionGranted();
      } else {
        granted = result;
      }

      // Exact alarm permission is handled via Settings intent from UI (Android 12+)
    }

    // For iOS, we'll use a simpler approach that doesn't require type resolution
    try {
      // This will work on iOS but gracefully fail on other platforms
      await _flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        ),
      );
    } catch (_) {
      // Ignore iOS-specific initialization errors on Android
    }

    return granted;
  }

  // Check current notifications enabled status (Android 13+ reports accurately)
  Future<bool> isPermissionGranted() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation == null) return true; // Pre-Android 13
    final bool? enabled = await androidImplementation.areNotificationsEnabled();
    return enabled ?? true;
  }

  Future<bool> areExactAlarmsAllowed() async {
    // Removed as it's not supported by the current plugin version
    return true;
  }

  Future<void> scheduleAffirmationNotifications(NotificationSettings settings) async {
    if (!settings.enabled) {
      await cancelAllNotifications();
      return;
    }

    // Cancel existing notifications
    await cancelAllNotifications();

    // Schedule notifications for the next 30 days
    final now = DateTime.now();
    for (int day = 0; day < 30; day++) {
      final scheduledDate = DateTime(
        now.year,
        now.month,
        now.day + day,
        settings.hour,
        settings.minute,
      );

      // Check if this day is selected
      final weekday = scheduledDate.weekday;
      if (!settings.selectedDays.contains(weekday)) continue;

      // Schedule up to dailyCount notifications per day, spaced by 2 hours
      final int count = settings.dailyCount.clamp(1, 10);
      for (int i = 0; i < count; i++) {
        final dt = scheduledDate.add(Duration(hours: i * 2));
        // Skip past times if scheduling for today
        if (day == 0 && dt.isBefore(now)) continue;
        // Ensure still on the same day; if not, skip overflowed times
        if (dt.day != scheduledDate.day) continue;

        await _scheduleNotification(
          id: day * 100 + i, // Unique ID per day/index window
          title: 'Daily Affirmation 🌟',
          body: 'Your personalized affirmation is ready to inspire you!',
          scheduledDate: dt,
        );
      }
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'affirmation_channel',
      'Daily Affirmations',
      channelDescription: 'Notifications for daily affirmations',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    final tz.TZDateTime tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzDateTime,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'affirmation_notification',
    );
  }

  // Removed legacy conversion helper; now using tz.TZDateTime.from directly

  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'instant_channel',
      'Instant Notifications',
      channelDescription: 'Instant affirmation notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'instant_notification',
    );
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }
}
