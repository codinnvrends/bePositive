import 'package:flutter/foundation.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/notification_settings.dart';
import '../services/notification_service.dart';
import '../database/database_helper.dart';

class NotificationProvider with ChangeNotifier {
  NotificationSettings _settings = const NotificationSettings();
  bool _isLoading = false;
  String? _error;
  bool _permissionGranted = false;

  NotificationSettings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get permissionGranted => _permissionGranted;

  final NotificationService _notificationService = NotificationService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  String _normalizeUserId(String? userId) => userId ?? 'default';

  Future<void> initialize(String? userId) async {
    _setLoading(true);
    try {
      await _notificationService.initialize();
      _permissionGranted = await _notificationService.requestPermissions();
      
      // Load settings for the given user or a default profile if none exists
      await loadSettings(_normalizeUserId(userId));
      
      _error = null;
    } catch (e) {
      _error = 'Failed to initialize notifications: $e';
      if (kDebugMode) print(_error);
    } finally {
      _setLoading(false);
    }
  }

  // Debug helpers
  Future<bool> areNotificationsEnabled() async {
    try {
      return await _notificationService.areNotificationsEnabled();
    } catch (_) {
      return _permissionGranted;
    }
  }

  Future<bool> areExactAlarmsAllowed() async {
    try {
      return await _notificationService.areExactAlarmsAllowed();
    } catch (_) {
      return true;
    }
  }

  Future<List<String>> getPendingSummaries() async {
    try {
      final pending = await _notificationService.getPendingRequests();
      return pending
          .map((p) => '#${p.id} ${p.title ?? ''} — ${p.body ?? ''}')
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> scheduleOneOffIn(Duration delay) async {
    try {
      await _notificationService.scheduleOneOffIn(delay);
    } catch (e) {
      _error = 'Failed to schedule one-off: $e';
      if (kDebugMode) print(_error);
    }
  }

  Future<void> refreshPermissionStatus() async {
    try {
      _permissionGranted = await _notificationService.isPermissionGranted();
      notifyListeners();
    } catch (_) {}
  }
  

  Future<void> loadSettings(String userId) async {
    try {
      _settings = await _databaseHelper.getNotificationSettings(userId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load notification settings: $e';
      if (kDebugMode) print(_error);
    }
  }

  Future<bool> updateSettings(String? userId, NotificationSettings newSettings) async {
    _setLoading(true);
    try {
      final uid = _normalizeUserId(userId);
      await _databaseHelper.saveNotificationSettings(uid, newSettings);
      _settings = newSettings;
      
      // Schedule notifications with new settings
      await _notificationService.scheduleAffirmationNotifications(newSettings);
      
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update notification settings: $e';
      if (kDebugMode) print(_error);
      _setLoading(false);
      return false;
    }
  }

  Future<void> toggleNotifications(String? userId) async {
    final newSettings = _settings.copyWith(enabled: !_settings.enabled);
    await updateSettings(_normalizeUserId(userId), newSettings);
  }

  Future<void> updateTime(String? userId, int hour, int minute) async {
    final newSettings = _settings.copyWith(hour: hour, minute: minute);
    await updateSettings(_normalizeUserId(userId), newSettings);
  }

  Future<void> updateDailyCount(String? userId, int count) async {
    final newSettings = _settings.copyWith(dailyCount: count);
    await updateSettings(_normalizeUserId(userId), newSettings);
  }

  Future<void> updateSelectedDays(String? userId, List<int> days) async {
    final newSettings = _settings.copyWith(selectedDays: days);
    await updateSettings(_normalizeUserId(userId), newSettings);
  }

  Future<void> requestPermissions() async {
    try {
      _permissionGranted = await _notificationService.requestPermissions();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to request notification permissions: $e';
      if (kDebugMode) print(_error);
    }
  }

  Future<void> showTestNotification() async {
    try {
      await _notificationService.showInstantNotification(
        title: 'Test Notification 🌟',
        body: 'Your notifications are working perfectly!',
      );
    } catch (e) {
      _error = 'Failed to show test notification: $e';
      if (kDebugMode) print(_error);
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notificationService.cancelAllNotifications();
    } catch (e) {
      _error = 'Failed to cancel notifications: $e';
      if (kDebugMode) print(_error);
    }
  }

  Future<void> openExactAlarmsSettings() async {
    try {
      final info = await PackageInfo.fromPlatform();
      // Primary: exact alarms permission screen (Android 12+)
      try {
        final intent = AndroidIntent(
          action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
          data: 'package:${info.packageName}',
        );
        await intent.launch();
        return;
      } catch (_) {/* fall back below */}

      // Fallback: app details settings
      final fallback = AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:${info.packageName}',
      );
      await fallback.launch();
    } catch (e) {
      _error = 'Failed to open exact alarms settings: $e';
      if (kDebugMode) print(_error);
    }
  }

  Future<int> getPendingScheduledCount() async {
    try {
      return await _notificationService.getPendingCount();
    } catch (e) {
      _error = 'Failed to get pending notifications: $e';
      if (kDebugMode) print(_error);
      return 0;
    }
  }

  Future<void> reschedule() async {
    try {
      await _notificationService.cancelAllNotifications();
      await _notificationService.scheduleAffirmationNotifications(_settings);
    } catch (e) {
      _error = 'Failed to reschedule notifications: $e';
      if (kDebugMode) print(_error);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Helper methods for UI
  String get timeDisplay => _settings.formattedTime;
  bool get notificationsEnabled => _settings.enabled && _permissionGranted;
  
  List<String> get selectedDaysDisplay {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return _settings.selectedDays.map((day) => dayNames[day - 1]).toList();
  }
}
