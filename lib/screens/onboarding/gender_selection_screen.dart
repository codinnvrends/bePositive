import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_profile.dart';
import '../../utils/app_theme.dart';
import '../../widgets/selection_card.dart';

class GenderSelectionScreen extends StatefulWidget {
  final String? selectedAgeGroup;

  const GenderSelectionScreen({
    super.key,
    this.selectedAgeGroup,
  });

  @override
  State<GenderSelectionScreen> createState() => _GenderSelectionScreenState();
}

class _GenderSelectionScreenState extends State<GenderSelectionScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedGender;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onGenderSelected(String gender) {
    setState(() {
      _selectedGender = gender;
    });
  }

  void _onNext() {
    if (_selectedGender != null && widget.selectedAgeGroup != null) {
      context.push('/focus-areas', extra: {
        'ageGroup': widget.selectedAgeGroup!,
        'gender': _selectedGender!,
      });
    }
  }

  void _onBack() {
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: _onBack,
        ),
        title: const Text('And your gender?'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress indicator
                LinearProgressIndicator(
                  value: 0.5,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                ),
                
                const SizedBox(height: AppTheme.spacingXL),
                
                // Title
                Text(
                  'Select one or more',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textLight,
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingXL),
                
                // Gender options
                Expanded(
                  child: ListView(
                    children: Gender.values.map((gender) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
                        child: SelectionCard(
                          title: gender.displayName,
                          isSelected: _selectedGender == gender.displayName,
                          onTap: () => _onGenderSelected(gender.displayName),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                // Navigation buttons
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _onBack,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Back',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: AppTheme.spacingM),
                    
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _selectedGender != null ? _onNext : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
