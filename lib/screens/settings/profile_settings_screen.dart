import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_profile.dart';
import '../../providers/user_provider.dart';
import '../../providers/affirmation_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/selection_card.dart';
import '../../widgets/focus_areas_chips.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  String? _selectedAgeGroup;
  String? _selectedGender;
  List<String> _selectedFocusAreas = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  void _loadCurrentProfile() {
    final userProvider = context.read<UserProvider>();
    if (userProvider.hasProfile) {
      final profile = userProvider.userProfile!;
      setState(() {
        _selectedAgeGroup = profile.ageGroup;
        _selectedGender = profile.gender;
        _selectedFocusAreas = List.from(profile.focusAreas);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _hasChanges() && !_isLoading ? _saveProfile : null,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            children: [
              // Age Group Section
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Age Group',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingM),
                    
                    ...AgeGroup.values.map((ageGroup) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
                        child: SelectionCard(
                          title: ageGroup.displayName,
                          isSelected: _selectedAgeGroup == ageGroup.displayName,
                          onTap: () {
                            setState(() {
                              _selectedAgeGroup = ageGroup.displayName;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingL),
              
              // Gender Section
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gender',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingM),
                    
                    ...Gender.values.map((gender) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
                        child: SelectionCard(
                          title: gender.displayName,
                          isSelected: _selectedGender == gender.displayName,
                          onTap: () {
                            setState(() {
                              _selectedGender = gender.displayName;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingL),
              
              // Focus Areas Section
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Focus Areas',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingS),
                    
                    Text(
                      'Select the areas you want to focus on for your affirmations',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textLight,
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingM),
                    
                    EditableFocusAreasChips(
                      selectedAreas: _selectedFocusAreas,
                      availableAreas: FocusArea.values.map((e) => e.displayName).toList(),
                      onChanged: (areas) {
                        setState(() {
                          _selectedFocusAreas = areas;
                        });
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingL),
              
              // Changes Summary
              if (_hasChanges())
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    border: Border.all(
                      color: AppTheme.primaryTeal.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppTheme.primaryTeal,
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Text(
                            'Profile Changes',
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryTeal,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: AppTheme.spacingS),
                      
                      Text(
                        'Your affirmations will be updated to match your new preferences.',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: AppTheme.spacingXL),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _hasChanges() && !_isLoading ? _saveProfile : null,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Text('Save Changes'),
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingM),
              
              // Reset Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _resetChanges,
                  child: const Text('Reset Changes'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _hasChanges() {
    final userProvider = context.read<UserProvider>();
    if (!userProvider.hasProfile) return false;
    
    final profile = userProvider.userProfile!;
    return _selectedAgeGroup != profile.ageGroup ||
           _selectedGender != profile.gender ||
           !_listsEqual(_selectedFocusAreas, profile.focusAreas);
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!b.contains(a[i])) return false;
    }
    return true;
  }

  void _resetChanges() {
    _loadCurrentProfile();
  }

  Future<void> _saveProfile() async {
    if (_selectedAgeGroup == null || 
        _selectedGender == null || 
        _selectedFocusAreas.isEmpty) {
      _showErrorDialog('Please complete all fields');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final affirmationProvider = context.read<AffirmationProvider>();
      
      final success = await userProvider.updateUserProfile(
        ageGroup: _selectedAgeGroup,
        gender: _selectedGender,
        focusAreas: _selectedFocusAreas,
      );

      if (success) {
        // Reload affirmations with new profile
        await affirmationProvider.loadAffirmations(userProvider.userProfile);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
            ),
          );
          context.pop();
        }
      } else {
        if (mounted) {
          _showErrorDialog('Failed to update profile');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('An error occurred while updating your profile');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
