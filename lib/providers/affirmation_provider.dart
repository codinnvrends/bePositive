import 'package:flutter/foundation.dart';
import 'dart:math';
import '../models/affirmation.dart';
import '../models/user_profile.dart';
import '../database/database_helper.dart';
import '../services/storage_service.dart';

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

  Future<void> initialize(UserProfile? userProfile) async {
    _setLoading(true);
    try {
      await _loadDailyStreak();
      await _loadAffirmationSource();
      await loadAffirmations(userProfile);
      await loadFavorites(userProfile?.id);
      _error = null;
    } catch (e) {
      _error = 'Failed to initialize affirmations: $e';
      if (kDebugMode) print(_error);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAffirmations(UserProfile? userProfile) async {
    try {
      if (userProfile != null && _affirmationSource == 'personalized') {
        _affirmations = await _databaseHelper.getPersonalizedAffirmations(userProfile);
      } else {
        _affirmations = await _databaseHelper.getAllAffirmations();
      }
      
      if (_affirmations.isNotEmpty && _currentAffirmation == null) {
        _currentAffirmation = _affirmations[_random.nextInt(_affirmations.length)];
      }
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load affirmations: $e';
      if (kDebugMode) print(_error);
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
  bool get hasAffirmations => _affirmations.isNotEmpty;
  bool get hasFavorites => _favoriteAffirmations.isNotEmpty;
  int get totalAffirmations => _affirmations.length;
  int get totalFavorites => _favoriteAffirmations.length;

  List<Affirmation> getAffirmationsByCategory(String category) {
    return _affirmations.where((a) => a.category == category).toList();
  }

  List<String> get availableCategories {
    return _affirmations.map((a) => a.category).toSet().toList()..sort();
  }
}
