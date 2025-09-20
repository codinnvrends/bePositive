import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_profile.dart';
import '../../utils/app_theme.dart';
import '../../widgets/selection_card.dart';

class AgeSelectionScreen extends StatefulWidget {
  const AgeSelectionScreen({super.key});

  @override
  State<AgeSelectionScreen> createState() => _AgeSelectionScreenState();
}

class _AgeSelectionScreenState extends State<AgeSelectionScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedAgeGroup;
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

  void _onAgeGroupSelected(String ageGroup) {
    setState(() {
      _selectedAgeGroup = ageGroup;
    });
  }

  void _onNext() {
    if (_selectedAgeGroup != null) {
      context.go('/gender-selection', extra: _selectedAgeGroup);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        title: const Text('Tell us about you'),
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
                  value: 0.25,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                ),
                
                const SizedBox(height: AppTheme.spacingXL),
                
                // Title
                Text(
                  'First, your age group',
                  style: AppTheme.headingMedium,
                ),
                
                const SizedBox(height: AppTheme.spacingS),
                
                Text(
                  'This helps us personalize your affirmations',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textLight,
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingXL),
                
                // Age group options
                Expanded(
                  child: ListView(
                    children: AgeGroup.values.map((ageGroup) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
                        child: SelectionCard(
                          title: ageGroup.displayName,
                          isSelected: _selectedAgeGroup == ageGroup.displayName,
                          onTap: () => _onAgeGroupSelected(ageGroup.displayName),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                // Next button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _selectedAgeGroup != null ? _onNext : null,
                    child: const Text('Next'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
