import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/notification_settings.dart';
import '../database/database_helper.dart';
import '../models/user_profile.dart';
import '../models/affirmation.dart';
import 'storage_service.dart';

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

  Future<void> scheduleCustomAffirmationWindowReminder({
    required String affirmationId,
    required String content,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required int dailyCount,
    required List<int> selectedDays,
    int horizonDays = 30,
  }) async {
    final now = DateTime.now();
    final count = dailyCount.clamp(1, 96);
    for (int day = 0; day < horizonDays; day++) {
      final dayStart = DateTime(now.year, now.month, now.day + day);
      final start = DateTime(dayStart.year, dayStart.month, dayStart.day, startHour, startMinute);
      final end = DateTime(dayStart.year, dayStart.month, dayStart.day, endHour, endMinute);
      final weekday = start.weekday;
      if (!selectedDays.contains(weekday)) continue;
      final effectiveEnd = end.isAfter(start) ? end : start.add(const Duration(minutes: 15));
      if (count <= 1) {
        if (day == 0 && start.isBefore(now)) continue;
        final ymd = start.year * 10000 + start.month * 100 + start.day;
        final id = 710000 + (ymd % 100000) * 1 + 0;
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          'Affirmation',
          content,
          tz.TZDateTime.from(start, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'affirmation_channel',
              'Daily Affirmations',
              channelDescription: 'Notifications for daily affirmations',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: affirmationId,
        );
        continue;
      }

      final totalMinutes = effectiveEnd.difference(start).inMinutes;
      final minStep = 5;
      final step = (totalMinutes / (count - 1)).floor();
      final actualStep = step < minStep ? minStep : step;
      for (int i = 0; i < count; i++) {
        DateTime dt;
        if (i == 0) {
          dt = start;
        } else if (i == count - 1) {
          dt = effectiveEnd;
        } else {
          dt = start.add(Duration(minutes: actualStep * i));
        }
        if (day == 0 && dt.isBefore(now)) continue;
        if (dt.day != start.day) continue;
        final ymd = dt.year * 10000 + dt.month * 100 + dt.day;
        final id = 720000 + (ymd % 100000) * 200 + i; // spread ids
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          'Affirmation',
          content,
          tz.TZDateTime.from(dt, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'affirmation_channel',
              'Daily Affirmations',
              channelDescription: 'Notifications for daily affirmations',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: affirmationId,
        );
      }
    }
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

  void _onNotificationTapped(NotificationResponse response) async {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
    // Store the tapped affirmationId for the app to consume on resume/start
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      await StorageService().setString('pending_affirmation_id', payload);
    }
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
    // Load affirmations once for selection
    final db = DatabaseHelper();
    final UserProfile? user = await db.getUserProfile();
    final List<Affirmation> affirmations = user != null
        ? await db.getPersonalizedAffirmations(user)
        : await db.getAllAffirmations();
    final List<Affirmation> safeAffirmations = affirmations.isNotEmpty
        ? affirmations
        : [
            Affirmation(
              id: 'fallback_${DateTime.now().millisecondsSinceEpoch}',
              content: 'You are capable, strong, and resilient.',
              category: 'Self-Esteem',
              isCustom: false,
              createdAt: DateTime.now(),
            )
          ];

    for (int day = 0; day < 30; day++) {
      final dayStart = DateTime(now.year, now.month, now.day + day);
      final start = DateTime(
        dayStart.year,
        dayStart.month,
        dayStart.day,
        settings.hour,
        settings.minute,
      );
      final end = DateTime(
        dayStart.year,
        dayStart.month,
        dayStart.day,
        settings.endHour,
        settings.endMinute,
      );

      // Check if this day is selected
      final weekday = start.weekday;
      if (!settings.selectedDays.contains(weekday)) continue;

      // Guard: end must be after start; if not, push end to start + 15m
      final effectiveEnd = end.isAfter(start) ? end : start.add(const Duration(minutes: 15));

      // Determine timestamps
      final int count = settings.dailyCount.clamp(1, 96); // at least 5-min spacing bound
      if (count <= 1) {
        final dt = start;
        if (day == 0 && dt.isBefore(now)) continue;
        final aff = safeAffirmations[(day + 0) % safeAffirmations.length];
        await _scheduleNotification(
          id: day * 100 + 0,
          title: 'Daily Affirmation 🌟',
          body: aff.content,
          scheduledDate: dt,
        );
        // overwrite payload via a direct zonedSchedule call with payload separate
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          day * 100 + 0,
          'Daily Affirmation 🌟',
          aff.content,
          tz.TZDateTime.from(dt, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'affirmation_channel',
              'Daily Affirmations',
              channelDescription: 'Notifications for daily affirmations',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: aff.id,
        );
        continue;
      }

      final totalMinutes = effectiveEnd.difference(start).inMinutes;
      final minStep = 5; // minutes
      final step = (totalMinutes / (count - 1)).floor();
      final actualStep = step < minStep ? minStep : step;

      for (int i = 0; i < count; i++) {
        DateTime dt;
        if (i == 0) {
          dt = start;
        } else if (i == count - 1) {
          dt = effectiveEnd;
        } else {
          dt = start.add(Duration(minutes: actualStep * i));
        }
        if (day == 0 && dt.isBefore(now)) continue; // Skip past times today
        if (dt.day != start.day) continue; // stay same day

        final aff = safeAffirmations[(day * 97 + i) % safeAffirmations.length];
        final id = day * 200 + i;
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          'Daily Affirmation 🌟',
          aff.content,
          tz.TZDateTime.from(dt, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'affirmation_channel',
              'Daily Affirmations',
              channelDescription: 'Notifications for daily affirmations',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: aff.id,
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

  Future<void> cancelNotificationsByPayload(String payload) async {
    final pending = await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    for (final req in pending) {
      if (req.payload == payload) {
        await _flutterLocalNotificationsPlugin.cancel(req.id);
      }
    }
  }

  Future<void> cancelCustomAffirmationNotifications(String affirmationId) async {
    await cancelNotificationsByPayload(affirmationId);
  }

  Future<void> scheduleCustomAffirmationReminder({
    required String affirmationId,
    required String content,
    required int hour,
    required int minute,
    required List<int> selectedDays,
    int horizonDays = 30,
  }) async {
    final now = DateTime.now();
    for (int day = 0; day < horizonDays; day++) {
      final date = DateTime(now.year, now.month, now.day + day, hour, minute);
      final weekday = date.weekday; // 1=Mon..7=Sun
      if (!selectedDays.contains(weekday)) continue;
      if (day == 0 && date.isBefore(now)) continue;

      // Build a deterministic ID from date (yyyyMMdd) and a small suffix so we avoid collisions
      final ymd = date.year * 10000 + date.month * 100 + date.day;
      final id = 700000 + (ymd % 100000) * 1 + 0; // one per day

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        'Affirmation',
        content,
        tz.TZDateTime.from(date, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'affirmation_channel',
            'Daily Affirmations',
            channelDescription: 'Notifications for daily affirmations',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: affirmationId,
      );
    }
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }
}
