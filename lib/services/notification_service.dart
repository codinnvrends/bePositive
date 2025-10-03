import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

    if (kDebugMode) {
      print('Initializing NotificationService...');
    }

    // Initialize timezone database FIRST
    try {
      tz.initializeTimeZones();
      if (kDebugMode) {
        print('Timezone database initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize timezone database: $e');
      }
    }

    try {
      // Try with custom launcher icon first
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      if (kDebugMode) {
        print('Notification plugin initialized with custom launcher_icon');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize notifications with launcher_icon: $e');
      }
      
      // Fallback initialization
      try {
        const AndroidInitializationSettings fallbackAndroidSettings =
            AndroidInitializationSettings('@mipmap/launcher_icon');

        const InitializationSettings fallbackSettings =
            InitializationSettings(
          android: fallbackAndroidSettings,
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        );

        await _flutterLocalNotificationsPlugin.initialize(
          fallbackSettings,
          onDidReceiveNotificationResponse: _onNotificationTapped,
        );
        
        if (kDebugMode) {
          print('Notification plugin initialized with launcher_icon fallback');
        }
      } catch (fallbackError) {
        if (kDebugMode) {
          print('Failed to initialize notifications with fallback: $fallbackError');
        }
        // Mark as initialized to prevent repeated attempts
        _initialized = true;
        return;
      }
    }

    // Create notification channels for Android
    await _createNotificationChannels();
    
    _initialized = true;
    
    if (kDebugMode) {
      print('NotificationService initialization completed');
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      bool groupCreated = false;
      
      try {
        // First create the notification channel group
        const AndroidNotificationChannelGroup affirmGroup = AndroidNotificationChannelGroup(
          'affirm_group',
          'Affirm! Notifications',
          description: 'All notifications from the Affirm! app',
        );
        
        await androidImplementation.createNotificationChannelGroup(affirmGroup);
        groupCreated = true;
        
        if (kDebugMode) {
          print('Notification channel group created successfully');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Warning: Failed to create notification channel group: $e');
          print('Creating channels without group...');
        }
        // Continue without group - channels will work without groups
      }
      
      // Create channels with or without group based on group creation success
      final AndroidNotificationChannel richChannel = AndroidNotificationChannel(
        'rich_affirmation_channel',
        'Rich Affirmations',
        description: 'Rich affirmation notifications with full content and styling - always expanded',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        enableLights: true,
        ledColor: const Color(0xFF6ABDB8), // Teal color for LED
        // Only add groupId if group was created successfully
        groupId: groupCreated ? 'affirm_group' : null,
      );

      final AndroidNotificationChannel regularChannel = AndroidNotificationChannel(
        'affirmation_channel',
        'Daily Affirmations',
        description: 'Notifications for daily affirmations',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        groupId: groupCreated ? 'affirm_group' : null,
      );

      final AndroidNotificationChannel instantChannel = AndroidNotificationChannel(
        'instant_channel',
        'Instant Notifications',
        description: 'Instant affirmation notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        groupId: groupCreated ? 'affirm_group' : null,
      );

      try {
        await androidImplementation.createNotificationChannel(richChannel);
        await androidImplementation.createNotificationChannel(regularChannel);
        await androidImplementation.createNotificationChannel(instantChannel);
        
        if (kDebugMode) {
          print('Android notification channels created successfully');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error creating notification channels: $e');
        }
        rethrow;
      }
    }
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
        final scheduleMode = await _getScheduleMode();
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
              icon: '@mipmap/launcher_icon',
            ),
            iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
          ),
          androidScheduleMode: scheduleMode,
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
        final scheduleMode = await _getScheduleMode();
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
              icon: '@mipmap/launcher_icon',
            ),
            iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
          ),
          androidScheduleMode: scheduleMode,
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

  /// Test method to schedule a 1-minute frequency notification immediately
  Future<void> testOneMinuteFrequency() async {
    if (kDebugMode) {
      print('Testing 1-minute frequency notification...');
    }
    
    final settings = const NotificationSettings(
      enabled: true,
      useFrequencyMode: true,
      frequencyValue: 1,
      frequencyUnit: 'minutes',
      selectedDays: [1, 2, 3, 4, 5, 6, 7], // All days
    );
    
    await scheduleRichAffirmationNotifications(settings);
    
    final pendingCount = await getPendingCount();
    if (kDebugMode) {
      print('Test scheduled $pendingCount notifications');
      
      // List all pending notifications with detailed info
      await _debugPendingNotifications();
    }
  }

  /// Debug method to show all pending notifications with their IDs
  Future<void> _debugPendingNotifications() async {
    final pending = await getPendingRequests();
    if (kDebugMode) {
      print('=== PENDING NOTIFICATIONS DEBUG ===');
      print('Total pending: ${pending.length}');
      
      final idCounts = <int, int>{};
      for (final req in pending) {
        idCounts[req.id] = (idCounts[req.id] ?? 0) + 1;
        final bodyText = req.body ?? 'null';
        final displayBody = bodyText.length > 50 ? '${bodyText.substring(0, 50)}...' : bodyText;
        print('ID: ${req.id}, Title: ${req.title}, Body: $displayBody');
      }
      
      print('=== ID COLLISION CHECK ===');
      final duplicates = idCounts.entries.where((e) => e.value > 1).toList();
      if (duplicates.isEmpty) {
        print('✅ No ID collisions detected');
      } else {
        print('❌ ID collisions detected:');
        for (final dup in duplicates) {
          print('  ID ${dup.key} appears ${dup.value} times');
        }
      }
      print('===============================');
    }
  }

  /// Test method to schedule an immediate notification without sound issues
  Future<void> testImmediateNotification() async {
    if (kDebugMode) {
      print('Testing immediate notification (30 seconds)...');
    }
    
    try {
      final testTime = DateTime.now().add(const Duration(seconds: 30));
      await _scheduleRichNotification(
        id: 88888,
        affirmationId: 'test_immediate',
        title: 'Sound Fix Test ✅',
        content: 'This notification should work without sound errors! Scheduled at ${DateTime.now().toString().substring(11, 19)}',
        category: 'Test',
        scheduledDate: testTime,
        showOnLockScreen: true,
      );
      
      if (kDebugMode) {
        print('✅ Immediate test notification scheduled successfully for ${testTime.toString().substring(11, 19)}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Immediate test notification failed: $e');
      }
      rethrow;
    }
  }

  /// Test method to schedule a rich styled notification
  Future<void> testRichNotification() async {
    if (kDebugMode) {
      print('Testing rich styled notification (15 seconds)...');
    }
    
    try {
      final testTime = DateTime.now().add(const Duration(seconds: 15));
      await _scheduleRichNotification(
        id: 77777,
        affirmationId: 'test_rich',
        title: 'Daily Affirmation',
        content: 'You are capable of amazing things. Your potential is limitless and your journey is uniquely yours. This is a longer affirmation to test the expanded notification view.',
        category: 'Self-Esteem',
        scheduledDate: testTime,
        showOnLockScreen: true,
      );
      
      if (kDebugMode) {
        print('✅ Rich notification test scheduled successfully for ${testTime.toString().substring(11, 19)}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Rich notification test failed: $e');
      }
      rethrow;
    }
  }

  /// Test method to schedule an expanded notification
  Future<void> testExpandedNotification() async {
    if (kDebugMode) {
      print('Testing expanded notification (10 seconds)...');
    }
    
    try {
      final testTime = DateTime.now().add(const Duration(seconds: 10));
      await _scheduleRichNotification(
        id: 66666,
        affirmationId: 'test_expanded',
        title: 'Expanded Affirmation',
        content: 'This is a test of the expanded notification system. The notification should appear in full size without needing to be manually expanded. Your journey of self-improvement and positive thinking is valuable and meaningful.',
        category: 'Expanded Test',
        scheduledDate: testTime,
        showOnLockScreen: true,
      );
      
      if (kDebugMode) {
        print('✅ Expanded notification test scheduled successfully for ${testTime.toString().substring(11, 19)}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Expanded notification test failed: $e');
      }
      rethrow;
    }
  }

  /// Request exact alarm permission (Android 12+)
  Future<void> requestExactAlarmPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      try {
        await androidImplementation.requestExactAlarmsPermission();
        if (kDebugMode) {
          print('Exact alarm permission requested');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to request exact alarm permission: $e');
        }
      }
    }
  }

  /// Comprehensive test to verify background notifications work when app is closed
  Future<Map<String, dynamic>> verifyBackgroundNotifications() async {
    final results = <String, dynamic>{};
    
    if (kDebugMode) {
      print('=== BACKGROUND NOTIFICATION VERIFICATION ===');
    }
    
    // 1. Check initialization
    await initialize();
    results['initialized'] = _initialized;
    if (kDebugMode) {
      print('✓ Initialization: ${_initialized ? 'SUCCESS' : 'FAILED'}');
    }
    
    // 2. Check permissions
    final permissionGranted = await isPermissionGranted();
    results['permission_granted'] = permissionGranted;
    if (kDebugMode) {
      print('✓ Notification Permission: ${permissionGranted ? 'GRANTED' : 'DENIED'}');
    }
    
    // 3. Check exact alarms (Android 12+)
    final exactAlarmsAllowed = await areExactAlarmsAllowed();
    results['exact_alarms_allowed'] = exactAlarmsAllowed;
    if (kDebugMode) {
      print('✓ Exact Alarms: ${exactAlarmsAllowed ? 'ALLOWED' : 'RESTRICTED'}');
    }
    
    // 3a. Request exact alarm permission if not allowed
    if (!exactAlarmsAllowed) {
      if (kDebugMode) {
        print('Requesting exact alarm permission...');
      }
      await requestExactAlarmPermission();
    }
    
    // 4. Test immediate notification (30 seconds from now)
    final testTime = DateTime.now().add(const Duration(seconds: 30));
    try {
      await _scheduleRichNotification(
        id: 99999,
        affirmationId: 'test_background',
        title: 'Background Test ✨',
        content: 'This notification proves background scheduling works! Scheduled at ${DateTime.now().toString().substring(11, 19)}',
        category: 'Test',
        scheduledDate: testTime,
        showOnLockScreen: true,
      );
      results['test_notification_scheduled'] = true;
      if (kDebugMode) {
        print('✓ Test notification scheduled for: ${testTime.toString().substring(11, 19)}');
      }
    } catch (e) {
      results['test_notification_scheduled'] = false;
      results['test_notification_error'] = e.toString();
      if (kDebugMode) {
        print('✗ Test notification failed: $e');
      }
    }
    
    // 5. Check pending notifications
    final pendingCount = await getPendingCount();
    results['pending_notifications'] = pendingCount;
    if (kDebugMode) {
      print('✓ Pending notifications: $pendingCount');
    }
    
    // 6. Test timezone handling
    try {
      final now = DateTime.now();
      final tzNow = tz.TZDateTime.from(now, tz.local);
      results['timezone_working'] = true;
      results['current_timezone'] = tz.local.name;
      if (kDebugMode) {
        print('✓ Timezone: ${tz.local.name} (${now.toString().substring(11, 19)} -> ${tzNow.toString().substring(11, 19)})');
      }
    } catch (e) {
      results['timezone_working'] = false;
      results['timezone_error'] = e.toString();
      if (kDebugMode) {
        print('✗ Timezone error: $e');
      }
    }
    
    // 7. Overall status
    final allGood = results['initialized'] == true && 
                   results['permission_granted'] == true && 
                   results['test_notification_scheduled'] == true &&
                   results['timezone_working'] == true;
    
    results['background_ready'] = allGood;
    
    if (kDebugMode) {
      print('=== VERIFICATION RESULT ===');
      print(allGood ? '🎉 BACKGROUND NOTIFICATIONS READY!' : '⚠️  ISSUES DETECTED - CHECK ABOVE');
      print('Close the app now and wait 30 seconds for test notification...');
      print('===============================');
    }
    
    return results;
  }

  void _onNotificationTapped(NotificationResponse response) async {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}, action: ${response.actionId}');
    }
    
    // Store the tapped affirmationId for the app to consume on resume/start
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      await StorageService().setString('pending_affirmation_id', payload);
      
      // Handle different actions
      if (response.actionId == 'view_cards') {
        // Direct navigation to cards view
        await StorageService().setString('notification_action', 'view_all_cards');
        if (kDebugMode) {
          print('Action: Navigate to cards view');
        }
      } else {
        // Default tap - show specific card
        await StorageService().setString('notification_action', 'show_specific_card');
        if (kDebugMode) {
          print('Action: Show specific affirmation card');
        }
      }
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
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation == null) return true;
    
    try {
      // Try to check if exact alarms are allowed (Android 12+)
      final bool? canScheduleExactAlarms = await androidImplementation.canScheduleExactNotifications();
      return canScheduleExactAlarms ?? true;
    } catch (e) {
      if (kDebugMode) {
        print('Could not check exact alarm permission: $e');
      }
      return true; // Assume allowed for older versions
    }
  }

  Future<AndroidScheduleMode> _getScheduleMode() async {
    final canScheduleExact = await areExactAlarmsAllowed();
    if (canScheduleExact) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    } else {
      if (kDebugMode) {
        print('Exact alarms not permitted, using inexact scheduling');
        print('Note: Notifications may be delayed by the system to optimize battery usage');
      }
      return AndroidScheduleMode.inexact;
    }
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
        final scheduleMode = await _getScheduleMode();
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
              icon: '@mipmap/launcher_icon',
            ),
            iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
          ),
          androidScheduleMode: scheduleMode,
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
        final scheduleMode = await _getScheduleMode();
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
              icon: '@mipmap/launcher_icon',
            ),
            iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
          ),
          androidScheduleMode: scheduleMode,
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
      icon: '@mipmap/launcher_icon',
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
    final scheduleMode = await _getScheduleMode();

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzDateTime,
      platformChannelSpecifics,
      androidScheduleMode: scheduleMode,
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

  /// Show rich notification with full card display and lock screen support
  Future<void> showRichAffirmationNotification({
    required String affirmationId,
    required String title,
    required String content,
    required String category,
    bool showOnLockScreen = true,
  }) async {
    // Create rich Android notification with BigText style
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'rich_affirmation_channel',
      'Rich Affirmations',
      channelDescription: 'Rich affirmation notifications with full content',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/launcher_icon',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      styleInformation: BigTextStyleInformation(
        '<font color="#2E7D7A"><b>$content</b></font>',
        htmlFormatBigText: true,
        contentTitle: '<font color="#2E7D7A"><b>✨ $title</b></font>',
        htmlFormatContentTitle: true,
        summaryText: '<font color="#2E7D7A"><b>$content</b></font>',
        htmlFormatSummaryText: true,
      ),
      // Lock screen configuration
      visibility: showOnLockScreen 
          ? NotificationVisibility.public 
          : NotificationVisibility.private,
      fullScreenIntent: false,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      // Action buttons
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'view_card',
          'View Full Card',
          icon: DrawableResourceAndroidBitmap('@android:drawable/ic_menu_view'),
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'next_affirmation',
          'Next',
          icon: DrawableResourceAndroidBitmap('@android:drawable/ic_media_next'),
          showsUserInterface: false,
        ),
      ],
      // Enhanced display
      enableVibration: true,
      enableLights: true,
      ledColor: const Color(0xFF6ABDB8),
      ledOnMs: 1000,
      ledOffMs: 500,
      groupKey: 'affirm_notifications',
      setAsGroupSummary: false,
      autoCancel: true,
      ongoing: false,
      silent: false,
      channelShowBadge: true,
      onlyAlertOnce: false,
      showProgress: false,
      maxProgress: 0,
      progress: 0,
      indeterminate: false,
      channelAction: AndroidNotificationChannelAction.createIfNotExists,
      ticker: 'New affirmation: $title',
    );

    // Create rich iOS notification
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
      subtitle: 'Daily Affirmation',
      threadIdentifier: 'affirm_notifications',
      presentBanner: true,
      presentList: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      content, // Show full content, no truncation
      platformChannelSpecifics,
      payload: affirmationId,
    );
  }

  /// Schedule rich affirmation notifications
  Future<void> scheduleRichAffirmationNotifications(
    NotificationSettings settings, {
    bool showOnLockScreen = true,
  }) async {
    if (kDebugMode) {
      print('scheduleRichAffirmationNotifications called with settings: enabled=${settings.enabled}, useFrequencyMode=${settings.useFrequencyMode}, frequencyValue=${settings.frequencyValue}, frequencyUnit=${settings.frequencyUnit}');
    }
    
    if (!settings.enabled) {
      if (kDebugMode) {
        print('Notifications disabled, canceling all');
      }
      await cancelAllNotifications();
      return;
    }

    // Cancel existing notifications
    await cancelAllNotifications();
    
    if (kDebugMode) {
      print('Canceled existing notifications');
    }

    final db = DatabaseHelper();
    final UserProfile? user = await db.getUserProfile();
    final List<Affirmation> affirmations = user != null
        ? await db.getPersonalizedAffirmations(user)
        : await db.getAllAffirmations();

    if (kDebugMode) {
      print('Loaded ${affirmations.length} affirmations');
    }

    if (affirmations.isEmpty) {
      if (kDebugMode) {
        print('No affirmations available, returning');
      }
      return;
    }

    // Use frequency-based or window-based scheduling
    if (settings.useFrequencyMode) {
      if (kDebugMode) {
        print('Using frequency-based scheduling');
      }
      await _scheduleFrequencyBasedNotifications(settings, affirmations, showOnLockScreen);
    } else {
      if (kDebugMode) {
        print('Using window-based scheduling');
      }
      await _scheduleWindowBasedNotifications(settings, affirmations, showOnLockScreen);
    }
    
    // Check how many notifications were actually scheduled
    final pendingCount = await getPendingCount();
    if (kDebugMode) {
      print('Total pending notifications after scheduling: $pendingCount');
    }
  }

  /// Schedule notifications based on frequency (every X minutes/hours/days)
  Future<void> _scheduleFrequencyBasedNotifications(
    NotificationSettings settings,
    List<Affirmation> affirmations,
    bool showOnLockScreen,
  ) async {
    final now = DateTime.now();
    final frequencyMinutes = settings.frequencyInMinutes;
    
    if (kDebugMode) {
      print('_scheduleFrequencyBasedNotifications: now=$now, frequencyMinutes=$frequencyMinutes, selectedDays=${settings.selectedDays}');
    }
    
    if (frequencyMinutes <= 0) {
      if (kDebugMode) {
        print('Frequency minutes is <= 0, returning');
      }
      return;
    }

    // Calculate how many notifications to schedule (up to 100 for performance)
    final maxNotifications = 100;
    int notificationCount = 0;
    
    // Start from the next frequency interval
    DateTime nextNotification = _getNextFrequencyTime(now, settings);
    
    if (kDebugMode) {
      print('First notification scheduled for: $nextNotification');
    }
    
    while (notificationCount < maxNotifications) {
      // Check if this notification falls on a selected day
      if (settings.selectedDays.contains(nextNotification.weekday)) {
        final aff = affirmations[notificationCount % affirmations.length];
        
        // Generate unique ID based on notification count and timestamp
        final uniqueId = 10000 + notificationCount;
        
        if (kDebugMode) {
          print('Scheduling notification #$notificationCount (ID: $uniqueId) for $nextNotification with affirmation: ${aff.content.length > 50 ? '${aff.content.substring(0, 50)}...' : aff.content}');
        }
        
        await _scheduleRichNotification(
          id: uniqueId,
          affirmationId: aff.id,
          title: 'Daily Affirmation',
          content: aff.content,
          category: aff.category,
          scheduledDate: nextNotification,
          showOnLockScreen: showOnLockScreen,
        );
        
        notificationCount++;
      } else {
        if (kDebugMode) {
          print('Skipping notification for $nextNotification (weekday ${nextNotification.weekday} not in selected days)');
        }
      }
      
      // Calculate next notification time
      nextNotification = nextNotification.add(Duration(minutes: frequencyMinutes));
      
      // Stop if we've scheduled too far into the future (30 days)
      if (nextNotification.isAfter(now.add(const Duration(days: 30)))) {
        if (kDebugMode) {
          print('Reached 30-day limit, stopping scheduling');
        }
        break;
      }
    }
    
    if (kDebugMode) {
      print('Scheduled $notificationCount frequency-based notifications');
    }
  }

  /// Schedule notifications based on time window (existing logic)
  Future<void> _scheduleWindowBasedNotifications(
    NotificationSettings settings,
    List<Affirmation> affirmations,
    bool showOnLockScreen,
  ) async {
    final now = DateTime.now();
    
    for (int day = 0; day < 30; day++) {
      final date = DateTime(now.year, now.month, now.day + day);
      final weekday = date.weekday;

      if (!settings.selectedDays.contains(weekday)) continue;

      // Generate notification times based on settings
      final List<DateTime> notificationTimes = [];
      final startTime = DateTime(date.year, date.month, date.day, settings.hour, settings.minute);
      final endTime = DateTime(date.year, date.month, date.day, settings.endHour, settings.endMinute);
      
      if (settings.dailyCount == 1) {
        notificationTimes.add(startTime);
      } else {
        final totalMinutes = endTime.difference(startTime).inMinutes;
        final interval = totalMinutes / (settings.dailyCount - 1);
        
        for (int i = 0; i < settings.dailyCount; i++) {
          final time = startTime.add(Duration(minutes: (interval * i).round()));
          notificationTimes.add(time);
        }
      }

      int timeBasedNotificationId = 20000; // Start from 20000 for time-based notifications
      
      for (final scheduledDate in notificationTimes) {
        if (scheduledDate.isBefore(now)) continue;

        final aff = affirmations[
            timeBasedNotificationId % affirmations.length];

        await _scheduleRichNotification(
          id: timeBasedNotificationId,
          affirmationId: aff.id,
          title: 'Daily Affirmation',
          content: aff.content,
          category: aff.category,
          scheduledDate: scheduledDate,
          showOnLockScreen: showOnLockScreen,
        );
        
        timeBasedNotificationId++;
      }
    }
  }

  /// Calculate the next frequency-based notification time
  DateTime _getNextFrequencyTime(DateTime from, NotificationSettings settings) {
    final frequencyMinutes = settings.frequencyInMinutes;
    
    if (kDebugMode) {
      print('_getNextFrequencyTime: from=$from, frequencyMinutes=$frequencyMinutes, unit=${settings.frequencyUnit}, value=${settings.frequencyValue}');
    }
    
    switch (settings.frequencyUnit) {
      case 'minutes':
        // For minute-based frequencies, simply add the frequency to current time
        final nextTime = from.add(Duration(minutes: frequencyMinutes));
        final result = DateTime(nextTime.year, nextTime.month, nextTime.day, nextTime.hour, nextTime.minute, 0);
        if (kDebugMode) {
          print('Minutes calculation: next time = $result');
        }
        return result;
        
      case 'hours':
        // Next occurrence at the top of the hour based on frequency
        final hoursToAdd = settings.frequencyValue - (from.hour % settings.frequencyValue);
        final result = DateTime(from.year, from.month, from.day, from.hour + hoursToAdd, 0, 0);
        if (kDebugMode) {
          print('Hours calculation: next time = $result');
        }
        return result;
        
      case 'days':
        // Next occurrence at the start time on the next frequency day
        final daysToAdd = settings.frequencyValue;
        final result = DateTime(from.year, from.month, from.day + daysToAdd, settings.hour, settings.minute, 0);
        if (kDebugMode) {
          print('Days calculation: next time = $result');
        }
        return result;
        
      default:
        final result = from.add(Duration(minutes: frequencyMinutes));
        if (kDebugMode) {
          print('Default calculation: next time = $result');
        }
        return result;
    }
  }

  /// Schedule a single rich notification
  Future<void> _scheduleRichNotification({
    required int id,
    required String affirmationId,
    required String title,
    required String content,
    required String category,
    required DateTime scheduledDate,
    bool showOnLockScreen = true,
  }) async {
    try {
      // Ensure we're initialized
      if (!_initialized) {
        await initialize();
      }

      // Validate scheduling time
      final now = DateTime.now();
      if (scheduledDate.isBefore(now)) {
        if (kDebugMode) {
          print('Warning: Attempting to schedule notification in the past: $scheduledDate vs $now');
        }
        return;
      }

      // Check permissions before scheduling
      final hasPermission = await isPermissionGranted();
      if (!hasPermission) {
        if (kDebugMode) {
          print('Error: Notification permission not granted, cannot schedule notification');
        }
        return;
      }

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'rich_affirmation_channel',
        'Rich Affirmations',
        channelDescription: 'Rich affirmation notifications with full content',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/launcher_icon',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        styleInformation: BigTextStyleInformation(
          '<font color="#2E7D7A"><b>$content</b></font>',
          htmlFormatBigText: true,
          contentTitle: '<font color="#2E7D7A"><b>✨ $title</b></font>',
          htmlFormatContentTitle: true,
          summaryText: '<font color="#2E7D7A"><b>$content</b></font>',
          htmlFormatSummaryText: true,
        ),
        visibility: showOnLockScreen 
            ? NotificationVisibility.public 
            : NotificationVisibility.private,
        category: AndroidNotificationCategory.message, // Message category shows more content
        fullScreenIntent: false,
        autoCancel: true,
        ongoing: false,
        // Force heads-up notification behavior
        channelShowBadge: true,
        silent: false,
        enableVibration: true,
        playSound: true,
        color: const Color(0xFF6ABDB8), // Teal color from your app theme
        colorized: true,
        // Force expanded view properties
        ticker: '✨ New Affirmation: $content',
        when: scheduledDate.millisecondsSinceEpoch,
        showWhen: true,
        usesChronometer: false,
        // Force expansion and prominence
        setAsGroupSummary: false,
        groupKey: 'affirm_notifications',
        timeoutAfter: null, // Don't auto-dismiss
        // Additional properties to force expanded state
        onlyAlertOnce: false,
        showProgress: false,
        maxProgress: 0,
        progress: 0,
        indeterminate: false,
        // Make notification more prominent to encourage expansion
        ledColor: const Color(0xFF6ABDB8),
        ledOnMs: 1000,
        ledOffMs: 500,
        // Enhanced action for direct card navigation
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'view_cards',
            '💚 View All Cards',
            icon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
            showsUserInterface: true,
          ),
        ],
        // Additional properties to force expansion
        subText: 'Daily Affirmation',
        // Use default system sound instead of custom sound file
      );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: 1,
        subtitle: '✨ Daily Affirmation • $category',
        threadIdentifier: 'affirm_notifications',
        presentBanner: true,
        presentList: true,
        interruptionLevel: InterruptionLevel.active,
        categoryIdentifier: 'AFFIRMATION_CATEGORY',
      );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final tz.TZDateTime tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);
      final scheduleMode = await _getScheduleMode();

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        content, // Show full content, no truncation
        tzDateTime,
        platformChannelSpecifics,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: affirmationId,
      );

      if (kDebugMode) {
        print('✓ Scheduled notification ID $id for ${scheduledDate.toString().substring(11, 19)} (${scheduledDate.toString().substring(0, 10)})');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Failed to schedule notification ID $id: $e');
      }
      rethrow;
    }
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

      final scheduleMode = await _getScheduleMode();
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
            icon: '@mipmap/launcher_icon',
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
        ),
        androidScheduleMode: scheduleMode,
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
