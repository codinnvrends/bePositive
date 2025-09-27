import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/affirmation.dart';
import '../../providers/affirmation_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/affirmation_card.dart';

class NotificationCardScreen extends StatefulWidget {
  final String? affirmationId;
  
  const NotificationCardScreen({
    super.key,
    this.affirmationId,
  });

  @override
  State<NotificationCardScreen> createState() => _NotificationCardScreenState();
}

class _NotificationCardScreenState extends State<NotificationCardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Affirmation? _currentAffirmation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadAffirmation();
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
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));
  }

  Future<void> _loadAffirmation() async {
    try {
      final affirmationProvider = context.read<AffirmationProvider>();
      final userProvider = context.read<UserProvider>();
      
      // Ensure user profile is loaded
      if (!userProvider.hasProfile) {
        await userProvider.loadUserProfile();
      }
      
      // Load affirmations if not already loaded
      if (!affirmationProvider.hasAffirmations) {
        await affirmationProvider.loadAffirmations(userProvider.userProfile);
      }
      
      // Find specific affirmation or get current one
      if (widget.affirmationId != null) {
        await affirmationProvider.setCurrentAffirmationById(
          widget.affirmationId!,
          user: userProvider.userProfile,
        );
        _currentAffirmation = affirmationProvider.currentAffirmation;
      } else {
        _currentAffirmation = affirmationProvider.currentAffirmation;
      }
      
      setState(() {
        _isLoading = false;
      });
      
      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentAffirmation == null) return;
    
    final userProvider = context.read<UserProvider>();
    final affirmationProvider = context.read<AffirmationProvider>();
    
    if (userProvider.userProfile != null) {
      await affirmationProvider.toggleFavorite(
        userProvider.userProfile!.id,
        _currentAffirmation!,
      );
      
      // Provide haptic feedback
      HapticFeedback.lightImpact();
    }
  }

  void _getNextAffirmation() {
    final affirmationProvider = context.read<AffirmationProvider>();
    affirmationProvider.getNextAffirmation();
    
    setState(() {
      _currentAffirmation = affirmationProvider.currentAffirmation;
    });
    
    // Reset and replay animation
    _animationController.reset();
    _animationController.forward();
    
    HapticFeedback.selectionClick();
  }

  void _getPreviousAffirmation() {
    // For now, just get next affirmation
    // In a full implementation, you'd maintain a history
    _getNextAffirmation();
  }

  bool _isFavorite() {
    if (_currentAffirmation == null) return false;
    
    final affirmationProvider = context.read<AffirmationProvider>();
    return affirmationProvider.favoriteAffirmations
        .any((fav) => fav.id == _currentAffirmation!.id);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Daily Affirmation',
          style: AppTheme.headingSmall.copyWith(
            color: AppTheme.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryTeal,
              ),
            )
          : _currentAffirmation == null
              ? _buildErrorState()
              : _buildCardView(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.sentiment_dissatisfied,
            size: 64,
            color: AppTheme.textLight,
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'No affirmation available',
            style: AppTheme.headingSmall.copyWith(
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Please try again later.',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildCardView() {
    return Consumer2<UserProvider, AffirmationProvider>(
      builder: (context, userProvider, affirmationProvider, child) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              children: [
                // Main card with swipe gestures
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: GestureDetector(
                        onPanEnd: (details) {
                          const double swipeThreshold = 300.0;
                          
                          if (details.velocity.pixelsPerSecond.dx > swipeThreshold) {
                            // Swipe right - Previous affirmation
                            _getPreviousAffirmation();
                          } else if (details.velocity.pixelsPerSecond.dx < -swipeThreshold) {
                            // Swipe left - Next affirmation
                            _getNextAffirmation();
                          }
                        },
                        child: AffirmationCard(
                          affirmation: _currentAffirmation!,
                          onNext: _getNextAffirmation,
                          onFavorite: _toggleFavorite,
                          isFavorite: _isFavorite(),
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingM),
                
                // Swipe hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.swipe_left,
                      size: 16,
                      color: AppTheme.textLight,
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                    Text(
                      'Swipe for more affirmations',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textLight,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                    const Icon(
                      Icons.swipe_right,
                      size: 16,
                      color: AppTheme.textLight,
                    ),
                  ],
                ),
                
                const SizedBox(height: AppTheme.spacingL),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _getPreviousAffirmation,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.arrow_back_ios, size: 16),
                        label: const Text('Previous'),
                      ),
                    ),
                    
                    const SizedBox(width: AppTheme.spacingM),
                    
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _getNextAffirmation,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.arrow_forward_ios, size: 16),
                        label: const Text('Next Affirmation'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
