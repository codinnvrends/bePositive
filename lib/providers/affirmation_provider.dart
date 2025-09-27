import 'package:flutter/foundation.dart';
import 'dart:math';
import '../models/affirmation.dart';
import '../models/user_profile.dart';
import '../database/database_helper.dart';
import '../services/storage_service.dart';
import '../models/custom_affirmation_reminder.dart';
import '../services/notification_service.dart';

class AffirmationProvider with ChangeNotifier {
  List<Affirmation> _affirmations = [];
  List<Affirmation> _favoriteAffirmations = [];
  Affirmation? _currentAffirmation;
  bool _isLoading = false;
  String? _error;
  int _dailyStreak = 0;
  String _affirmationSource = 'personalized'; // 'personalized', 'manual', 'all'

  List<Affirmation> get affirmations => _affirmations;
  List<Affirmation> get favoriteAffirmations => _favoriteAffirmations;
  Affirmation? get currentAffirmation => _currentAffirmation;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get dailyStreak => _dailyStreak;
  String get affirmationSource => _affirmationSource;

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final StorageService _storageService = StorageService();
  final Random _random = Random();
  final NotificationService _notificationService = NotificationService();

  Future<void> initialize(UserProfile? userProfile) async {
    _setLoading(true);
    try {
      // Debug database state
      if (kDebugMode) {
        await _databaseHelper.debugDatabaseState();
      }
      
      await _loadDailyStreak();
      await _loadAffirmationSource();
      await loadAffirmations(userProfile);
      await loadFavorites(userProfile?.id);
      
      // If no affirmations loaded, try to load all affirmations as fallback
      if (_affirmations.isEmpty) {
        if (kDebugMode) print('No personalized affirmations found, loading all affirmations');
        _affirmations = await _databaseHelper.getAllAffirmations();
        if (kDebugMode) print('Fallback: Found ${_affirmations.length} total affirmations');
      }
      
      // If still no affirmations, there's a database issue
      if (_affirmations.isEmpty) {
        _error = 'No affirmations available. Please check your internet connection or try again later.';
        if (kDebugMode) print('Database appears to be empty - no affirmations found');
      } else {
        // Ensure we have a current affirmation
        if (_currentAffirmation == null) {
          _currentAffirmation = _affirmations[_random.nextInt(_affirmations.length)];
        }
        _error = null;
      }
    } catch (e) {
      _error = 'Failed to initialize affirmations: $e';
      if (kDebugMode) print('Affirmation initialization error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<CustomAffirmationReminder?> getCustomReminderById(String affirmationId) async {
    try {
      return await _databaseHelper.getCustomReminderByAffirmationId(affirmationId);
    } catch (e) {
      if (kDebugMode) print('Failed to load custom reminder: $e');
      return null;
    }
  }

  Future<bool> addCustomAffirmationWithReminder({
    required String content,
    required String category,
    required bool enabled,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required int dailyCount,
    required List<int> selectedDays,
  }) async {
    try {
      // Enforce max 5 configured custom reminders (user-visible)
      final configured = await _databaseHelper.getConfiguredCustomAffirmationsCount();
      if (configured >= 5) {
        return false;
      }

      final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
      final customAffirmation = Affirmation(
        id: id,
        content: content,
        category: category,
        isCustom: true,
        createdAt: DateTime.now(),
      );

      await _databaseHelper.insertCustomAffirmation(customAffirmation);
      _affirmations.add(customAffirmation);
      notifyListeners();

      // Save reminder
      final reminder = CustomAffirmationReminder(
        affirmationId: id,
        enabled: enabled,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
        dailyCount: dailyCount,
        selectedDays: selectedDays,
      );
      try {
        await _databaseHelper.upsertCustomReminder(reminder);

        if (enabled) {
          await _notificationService.scheduleCustomAffirmationWindowReminder(
            affirmationId: id,
            content: content,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            dailyCount: dailyCount,
            selectedDays: selectedDays,
          );
        }
      } catch (e) {
        // Rollback: delete the newly inserted affirmation and any reminder
        try {
          await _databaseHelper.deleteCustomReminderByAffirmationId(id);
        } catch (_) {}
        try {
          await _databaseHelper.deleteCustomAffirmation(id);
          _affirmations.removeWhere((a) => a.id == id);
          notifyListeners();
        } catch (_) {}
        rethrow;
      }

      return true;
    } catch (e) {
      _error = 'Failed to add custom affirmation with reminder: $e';
      if (kDebugMode) print(_error);
      return false;
    }
  }
  Future<void> loadAffirmations(UserProfile? userProfile) async {
    try {
      if (userProfile != null && _affirmationSource == 'personalized') {
        if (kDebugMode) {
          print('Loading personalized affirmations for user: ${userProfile.ageGroup}, ${userProfile.gender}, focus areas: ${userProfile.focusAreas}');
        }
        _affirmations = await _databaseHelper.getPersonalizedAffirmations(userProfile);
        if (kDebugMode) {
          print('Found ${_affirmations.length} personalized affirmations');
        }
      } else {
        if (kDebugMode) {
          print('Loading all affirmations (source: $_affirmationSource)');
        }
        _affirmations = await _databaseHelper.getAllAffirmations();
        if (kDebugMode) {
          print('Found ${_affirmations.length} total affirmations');
        }
      }
      
      if (_affirmations.isNotEmpty && _currentAffirmation == null) {
        _currentAffirmation = _affirmations[_random.nextInt(_affirmations.length)];
        if (kDebugMode) {
          print('Set current affirmation: ${_currentAffirmation?.content}');
        }
      }
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load affirmations: $e';
      if (kDebugMode) print('Error loading affirmations: $_error');
    }
  }

  Future<void> loadFavorites(String? userId) async {
    if (userId == null) return;
    
    try {
      _favoriteAffirmations = await _databaseHelper.getFavoriteAffirmations(userId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load favorites: $e';
      if (kDebugMode) print(_error);
    }
  }

  Future<void> getNextAffirmation() async {
    if (_affirmations.isEmpty) return;

    try {
      // Get a random affirmation that's different from the current one
      List<Affirmation> availableAffirmations = _affirmations;
      if (_affirmations.length > 1 && _currentAffirmation != null) {
        availableAffirmations = _affirmations
            .where((a) => a.id != _currentAffirmation!.id)
            .toList();
      }

      if (availableAffirmations.isNotEmpty) {
        _currentAffirmation = availableAffirmations[
            _random.nextInt(availableAffirmations.length)];
        
        // Record view history
        final userProfile = await _databaseHelper.getUserProfile();
        if (userProfile != null && _currentAffirmation != null) {
          await _databaseHelper.addToViewHistory(
            userProfile.id,
            _currentAffirmation!.id,
          );
        }

        await _updateDailyStreak();
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to get next affirmation: $e';
      if (kDebugMode) print(_error);
    }
  }

  Future<void> toggleFavorite(String userId, Affirmation affirmation) async {
    try {
      final isFavorite = await _databaseHelper.isFavorite(userId, affirmation.id);
      
      if (isFavorite) {
        await _databaseHelper.removeFromFavorites(userId, affirmation.id);
        _favoriteAffirmations.removeWhere((a) => a.id == affirmation.id);
      } else {
        await _databaseHelper.addToFavorites(userId, affirmation.id);
        _favoriteAffirmations.add(affirmation);
      }
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to toggle favorite: $e';
      if (kDebugMode) print(_error);
    }
  }

  Future<bool> isFavorite(String userId, String affirmationId) async {
    try {
      return await _databaseHelper.isFavorite(userId, affirmationId);
    } catch (e) {
      if (kDebugMode) print('Error checking favorite status: $e');
      return false;
    }
  }

  Future<void> addCustomAffirmation(String content, String category) async {
    try {
      final customAffirmation = Affirmation(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        content: content,
        category: category,
        isCustom: true,
        createdAt: DateTime.now(),
      );

      await _databaseHelper.insertAffirmation(customAffirmation);
      _affirmations.add(customAffirmation);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add custom affirmation: $e';
      if (kDebugMode) print(_error);
    }
  }

  Future<void> setAffirmationSource(String source) async {
    _affirmationSource = source;
    await _storageService.setAffirmationSource(source);
    
    // Reload affirmations with new source
    final userProfile = await _databaseHelper.getUserProfile();
    await loadAffirmations(userProfile);
    notifyListeners();
  }

  Future<bool> updateCustomAffirmation({
    required String id,
    String? content,
    String? category,
    CustomAffirmationReminder? reminder,
  }) async {
    try {
      // Update affirmation fields if provided
      if (content != null || category != null) {
        final updated = await _databaseHelper.updateCustomAffirmation(
          id,
          content: content,
          category: category,
        );
        if (updated > 0) {
          // Update in-memory
          final idx = _affirmations.indexWhere((a) => a.id == id);
          if (idx != -1) {
            final old = _affirmations[idx];
            _affirmations[idx] = Affirmation(
              id: old.id,
              content: content ?? old.content,
              category: category ?? old.category,
              isCustom: old.isCustom,
              createdAt: old.createdAt,
            );
          }
          // Also update current if necessary
          if (_currentAffirmation?.id == id) {
            _currentAffirmation = _affirmations.firstWhere((a) => a.id == id, orElse: () => _currentAffirmation!);
          }
        }
      }

      // Update reminder if provided
      if (reminder != null) {
        await _databaseHelper.upsertCustomReminder(reminder);
        // Re-schedule notifications for this affirmation id
        await _notificationService.cancelCustomAffirmationNotifications(id);
        if (reminder.enabled) {
          await _notificationService.scheduleCustomAffirmationWindowReminder(
            affirmationId: id,
            content: content ?? (_affirmations.firstWhere((a) => a.id == id, orElse: () => _currentAffirmation!).content),
            startHour: reminder.startHour,
            startMinute: reminder.startMinute,
            endHour: reminder.endHour,
            endMinute: reminder.endMinute,
            dailyCount: reminder.dailyCount,
            selectedDays: reminder.selectedDays,
          );
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update custom affirmation: $e';
      if (kDebugMode) print(_error);
      return false;
    }
  }

  Future<bool> deleteCustomAffirmationById(String id) async {
    try {
      // Cancel any scheduled notifications
      await _notificationService.cancelCustomAffirmationNotifications(id);
      // Delete from DB (reminder + affirmation)
      await _databaseHelper.deleteCustomAffirmation(id);
      // Remove from in-memory collections
      _affirmations.removeWhere((a) => a.id == id);
      _favoriteAffirmations.removeWhere((a) => a.id == id);
      if (_currentAffirmation?.id == id) {
        _currentAffirmation = _affirmations.isNotEmpty ? _affirmations.first : null;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete custom affirmation: $e';
      if (kDebugMode) print(_error);
      return false;
    }
  }

  Future<void> _loadAffirmationSource() async {
    _affirmationSource = await _storageService.getAffirmationSource();
  }

  Future<void> _updateDailyStreak() async {
    final now = DateTime.now();
    final lastDate = await _storageService.getLastAffirmationDate();
    
    if (lastDate == null) {
      // First time using the app
      _dailyStreak = 1;
    } else {
      final daysDifference = now.difference(lastDate).inDays;
      
      if (daysDifference == 0) {
        // Same day, no change to streak
        return;
      } else if (daysDifference == 1) {
        // Consecutive day, increment streak
        _dailyStreak++;
      } else {
        // Missed days, reset streak
        _dailyStreak = 1;
      }
    }
    
    await _storageService.setDailyStreak(_dailyStreak);
    await _storageService.setLastAffirmationDate(now);
  }

  Future<void> _loadDailyStreak() async {
    _dailyStreak = await _storageService.getDailyStreak();
    if (kDebugMode) {
      print('AffirmationProvider: Loaded daily streak: $_dailyStreak');
    }
  }

  void _setLoading(bool loading) {
    if (kDebugMode) {
      print('AffirmationProvider: Setting loading to $loading');
    }
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    if (kDebugMode) {
      print('AffirmationProvider: Cleared error');
    }
    notifyListeners();
  }

  void forceStopLoading() {
    if (kDebugMode) {
      print('AffirmationProvider: Force stopping loading');
    }
    _isLoading = false;
    notifyListeners();
  }

  // Helper methods for UI
  bool get hasAffirmations => _affirmations.isNotEmpty;
  bool get hasCurrentAffirmation => _currentAffirmation != null;
  bool get hasFavorites => _favoriteAffirmations.isNotEmpty;
  int get totalAffirmations => _affirmations.length;
  int get totalFavorites => _favoriteAffirmations.length;

  List<Affirmation> getAffirmationsByCategory(String category) {
    return _affirmations.where((a) => a.category == category).toList();
  }

  List<String> get availableCategories {
    return _affirmations.map((a) => a.category).toSet().toList()..sort();
  }

  Future<void> setCurrentAffirmationById(String id, {UserProfile? user}) async {
    try {
      // Ensure affirmations are loaded
      if (_affirmations.isEmpty) {
        await loadAffirmations(user);
      }

      // Try to find in current list first
      final found = _affirmations.cast<Affirmation?>().firstWhere(
        (a) => a?.id == id,
        orElse: () => null,
      );

      if (found != null) {
        _currentAffirmation = found;
        notifyListeners();
        return;
      }

      // Fallback: load all affirmations from DB and search
      final all = await _databaseHelper.getAllAffirmations();
      Affirmation? byId;
      for (final a in all) {
        if (a.id == id) {
          byId = a;
          break;
        }
      }
      byId ??= all.isNotEmpty ? all.first : null;
      if (byId != null) {
        _currentAffirmation = byId;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Failed to set affirmation by id: $e');
    }
  }
}
