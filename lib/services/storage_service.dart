import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // User onboarding status
  Future<bool> isFirstLaunch() async {
    await initialize();
    return _prefs?.getBool('is_first_launch') ?? true;
  }

  Future<void> setFirstLaunchCompleted() async {
    await initialize();
    await _prefs?.setBool('is_first_launch', false);
  }

  // User ID
  Future<String?> getUserId() async {
    await initialize();
    return _prefs?.getString('user_id');
  }

  Future<void> setUserId(String userId) async {
    await initialize();
    await _prefs?.setString('user_id', userId);
  }

  // App settings
  Future<bool> isDarkMode() async {
    await initialize();
    return _prefs?.getBool('dark_mode') ?? false;
  }

  Future<void> setDarkMode(bool isDark) async {
    await initialize();
    await _prefs?.setBool('dark_mode', isDark);
  }

  // Daily streak
  Future<int> getDailyStreak() async {
    await initialize();
    return _prefs?.getInt('daily_streak') ?? 0;
  }

  Future<void> setDailyStreak(int streak) async {
    await initialize();
    await _prefs?.setInt('daily_streak', streak);
  }

  Future<DateTime?> getLastAffirmationDate() async {
    await initialize();
    final timestamp = _prefs?.getInt('last_affirmation_date');
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  Future<void> setLastAffirmationDate(DateTime date) async {
    await initialize();
    await _prefs?.setInt('last_affirmation_date', date.millisecondsSinceEpoch);
  }

  // Affirmation display preferences
  Future<String> getAffirmationSource() async {
    await initialize();
    return _prefs?.getString('affirmation_source') ?? 'personalized';
  }

  Future<void> setAffirmationSource(String source) async {
    await initialize();
    await _prefs?.setString('affirmation_source', source);
  }

  // Clear all data
  Future<void> clearAllData() async {
    await initialize();
    await _prefs?.clear();
  }

  // Generic methods
  Future<void> setString(String key, String value) async {
    await initialize();
    await _prefs?.setString(key, value);
  }

  Future<String?> getString(String key) async {
    await initialize();
    return _prefs?.getString(key);
  }

  Future<void> setInt(String key, int value) async {
    await initialize();
    await _prefs?.setInt(key, value);
  }

  Future<int?> getInt(String key) async {
    await initialize();
    return _prefs?.getInt(key);
  }

  Future<void> setBool(String key, bool value) async {
    await initialize();
    await _prefs?.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    await initialize();
    return _prefs?.getBool(key);
  }

  Future<void> remove(String key) async {
    await initialize();
    await _prefs?.remove(key);
  }

  Future<bool> containsKey(String key) async {
    await initialize();
    return _prefs?.containsKey(key) ?? false;
  }
}
