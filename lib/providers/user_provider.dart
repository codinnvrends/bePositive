import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/user_profile.dart';
import '../database/database_helper.dart';
import '../services/storage_service.dart';

class UserProvider with ChangeNotifier {
  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _error;

  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasProfile => _userProfile != null;

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final StorageService _storageService = StorageService();

  Future<void> loadUserProfile() async {
    // Prevent concurrent loading calls
    if (_isLoading) {
      if (kDebugMode) print('UserProvider: Already loading, skipping duplicate call');
      return;
    }
    
    _setLoading(true);
    try {
      if (kDebugMode) print('UserProvider: Loading user profile...');
      _userProfile = await _databaseHelper.getUserProfile();
      if (kDebugMode) print('UserProvider: User profile loaded: ${_userProfile != null ? "Found" : "Not found"}');
      _error = null;
    } catch (e) {
      _error = 'Failed to load user profile: $e';
      if (kDebugMode) print('UserProvider: Error loading profile: $_error');
    } finally {
      if (kDebugMode) print('UserProvider: Finishing loadUserProfile, setting loading to false');
      _setLoading(false);
    }
  }

  Future<bool> createUserProfile({
    required String ageGroup,
    required String gender,
    required List<String> focusAreas,
  }) async {
    _setLoading(true);
    try {
      final userId = const Uuid().v4();
      final now = DateTime.now();
      
      final profile = UserProfile(
        id: userId,
        ageGroup: ageGroup,
        gender: gender,
        focusAreas: focusAreas,
        createdAt: now,
        lastUpdated: now,
      );

      await _databaseHelper.insertUserProfile(profile);
      await _storageService.setUserId(userId);
      await _storageService.setFirstLaunchCompleted();
      
      _userProfile = profile;
      _error = null;
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to create user profile: $e';
      if (kDebugMode) print(_error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateUserProfile({
    String? ageGroup,
    String? gender,
    List<String>? focusAreas,
  }) async {
    if (_userProfile == null) return false;

    _setLoading(true);
    try {
      final updatedProfile = _userProfile!.copyWith(
        ageGroup: ageGroup ?? _userProfile!.ageGroup,
        gender: gender ?? _userProfile!.gender,
        focusAreas: focusAreas ?? _userProfile!.focusAreas,
        lastUpdated: DateTime.now(),
      );

      await _databaseHelper.updateUserProfile(updatedProfile);
      _userProfile = updatedProfile;
      _error = null;
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update user profile: $e';
      if (kDebugMode) print(_error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteUserProfile() async {
    _setLoading(true);
    try {
      await _storageService.clearAllData();
      _userProfile = null;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete user profile: $e';
      if (kDebugMode) print(_error);
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    if (kDebugMode) {
      print('UserProvider: Setting loading to $loading');
    }
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void forceStopLoading() {
    if (kDebugMode) {
      print('UserProvider: Force stopping loading');
    }
    _isLoading = false;
    notifyListeners();
  }

  // Helper methods for UI
  String get displayAgeGroup => _userProfile?.ageGroup ?? '';
  String get displayGender => _userProfile?.gender ?? '';
  List<String> get displayFocusAreas => _userProfile?.focusAreas ?? [];
  
  bool hasFocusArea(String focusArea) {
    return _userProfile?.focusAreas.contains(focusArea) ?? false;
  }
}
