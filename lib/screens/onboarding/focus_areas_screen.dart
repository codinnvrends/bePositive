import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../providers/user_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/selection_card.dart';

class FocusAreasScreen extends StatefulWidget {
  final String? selectedAgeGroup;
  final String? selectedGender;

  const FocusAreasScreen({
    super.key,
    this.selectedAgeGroup,
    this.selectedGender,
  });

  @override
  State<FocusAreasScreen> createState() => _FocusAreasScreenState();
}

class _FocusAreasScreenState extends State<FocusAreasScreen>
    with SingleTickerProviderStateMixin {
  final Set<String> _selectedFocusAreas = {};
  bool _isLoading = false;
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

  void _onFocusAreaToggled(String focusArea) {
    setState(() {
      if (_selectedFocusAreas.contains(focusArea)) {
        _selectedFocusAreas.remove(focusArea);
      } else {
        _selectedFocusAreas.add(focusArea);
      }
    });
  }

  Future<void> _onFinish() async {
    if (_selectedFocusAreas.isEmpty || 
        widget.selectedAgeGroup == null || 
        widget.selectedGender == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final success = await userProvider.createUserProfile(
        ageGroup: widget.selectedAgeGroup!,
        gender: widget.selectedGender!,
        focusAreas: _selectedFocusAreas.toList(),
      );

      if (success && mounted) {
        context.go('/setup-complete');
      } else if (mounted) {
        _showErrorDialog();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: const Text('Failed to create your profile. Please try again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
        title: const Text('What areas matter most?'),
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
                  value: 0.75,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                ),
                
                const SizedBox(height: AppTheme.spacingXL),
                
                // Title
                Text(
                  'Select one to more',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textLight,
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingXL),
                
                // Focus areas grid
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: AppTheme.spacingM,
                      mainAxisSpacing: AppTheme.spacingM,
                    ),
                    itemCount: FocusArea.values.length,
                    itemBuilder: (context, index) {
                      final focusArea = FocusArea.values[index];
                      final isSelected = _selectedFocusAreas.contains(focusArea.displayName);
                      
                      return MultiSelectCard(
                        title: focusArea.displayName,
                        isSelected: isSelected,
                        onTap: () => _onFocusAreaToggled(focusArea.displayName),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingL),
                
                // Summary
                if (_selectedFocusAreas.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
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
                              Icons.check_circle,
                              color: AppTheme.primaryTeal,
                              size: 20,
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Text(
                              'You\'re All Set!',
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryTeal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          'Journey begins now!',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textLight,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Text(
                          'Age: ${widget.selectedAgeGroup}\n'
                          'Focus: ${_selectedFocusAreas.join(', ')}',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: AppTheme.spacingL),
                ],
                
                // Navigation buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _onBack,
                        child: const Text('Back'),
                      ),
                    ),
                    
                    const SizedBox(width: AppTheme.spacingM),
                    
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _selectedFocusAreas.isNotEmpty && !_isLoading 
                            ? _onFinish 
                            : null,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Start Affirming!'),
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
