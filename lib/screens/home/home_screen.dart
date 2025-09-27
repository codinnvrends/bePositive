import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/affirmation_provider.dart';
import '../../services/storage_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/affirmation_card.dart';
import '../../widgets/focus_areas_chips.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeDataWithTimeout();
  }

  Future<void> _initializeDataWithTimeout() async {
    try {
      await _initializeData().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) print('Home initialization timed out');
          // Force providers to stop loading
          final userProvider = context.read<UserProvider>();
          final affirmationProvider = context.read<AffirmationProvider>();
          
          if (userProvider.isLoading) {
            userProvider.forceStopLoading();
          }
          if (affirmationProvider.isLoading) {
            affirmationProvider.forceStopLoading();
          }
        },
      );
    } catch (e) {
      if (kDebugMode) print('Home initialization failed: $e');
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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

    _animationController.forward();
  }

  Future<void> _initializeData() async {
    try {
      final userProvider = context.read<UserProvider>();
      final affirmationProvider = context.read<AffirmationProvider>();
      
      if (!userProvider.hasProfile && !userProvider.isLoading) {
        if (kDebugMode) print('Home: Loading user profile because no profile found');
        await userProvider.loadUserProfile();
      } else if (kDebugMode) {
        print('Home: Skipping user profile load - hasProfile: ${userProvider.hasProfile}, isLoading: ${userProvider.isLoading}');
      }
      
      if (!affirmationProvider.hasAffirmations) {
        await affirmationProvider.initialize(userProvider.userProfile);
      }

      // If launched/tapped from a notification, show that exact affirmation
      try {
        final pendingId = await StorageService().getString('pending_affirmation_id');
        if (pendingId != null && pendingId.isNotEmpty) {
          await affirmationProvider.setCurrentAffirmationById(
            pendingId,
            user: userProvider.userProfile,
          );
          await StorageService().remove('pending_affirmation_id');
        }
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing home data: $e');
      }
      // Force providers to stop loading state
      final userProvider = context.read<UserProvider>();
      final affirmationProvider = context.read<AffirmationProvider>();
      
      if (userProvider.isLoading) {
        userProvider.forceStopLoading();
      }
      if (affirmationProvider.isLoading) {
        affirmationProvider.forceStopLoading();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer2<UserProvider, AffirmationProvider>(
          builder: (context, userProvider, affirmationProvider, child) {
            if (userProvider.isLoading || affirmationProvider.isLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading your affirmations...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (!userProvider.hasProfile) {
              return const Center(
                child: Text('No user profile found'),
              );
            }

            if (affirmationProvider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      affirmationProvider.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        affirmationProvider.clearError();
                        await affirmationProvider.initialize(userProvider.userProfile);
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              );
            }

            return AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: CustomScrollView(
                      slivers: [
                        // App Bar
                        SliverAppBar(
                          floating: true,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          expandedHeight: 80,
                          flexibleSpace: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingL,
                              vertical: AppTheme.spacingL,
                            ),
                            child: Row(
                              children: [
                                // App logo and name
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingM),
                                Text(
                                  'Affirm!',
                                  style: AppTheme.headingMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                                
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                        
                        // Content
                        SliverPadding(
                          padding: const EdgeInsets.all(AppTheme.spacingL),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              // Focus areas
                              FocusAreasChips(
                                focusAreas: userProvider.displayFocusAreas,
                              ),
                              
                              const SizedBox(height: AppTheme.spacingXL),
                              
                              // Main affirmation card with swipe gestures
                              if (affirmationProvider.currentAffirmation != null)
                                GestureDetector(
                                  onPanEnd: (details) {
                                    // Swipe right (positive velocity) = Previous
                                    // Swipe left (negative velocity) = Next
                                    const double swipeThreshold = 300.0;
                                    
                                    if (details.velocity.pixelsPerSecond.dx > swipeThreshold) {
                                      // Swipe right - Previous affirmation
                                      if (kDebugMode) print('Swiped right - Previous affirmation');
                                      _showPreviousAffirmation();
                                    } else if (details.velocity.pixelsPerSecond.dx < -swipeThreshold) {
                                      // Swipe left - Next affirmation
                                      if (kDebugMode) print('Swiped left - Next affirmation');
                                      affirmationProvider.getNextAffirmation();
                                    }
                                  },
                                  child: AffirmationCard(
                                    affirmation: affirmationProvider.currentAffirmation!,
                                    onNext: () => affirmationProvider.getNextAffirmation(),
                                    onFavorite: () => _toggleFavorite(
                                      userProvider.userProfile!.id,
                                      affirmationProvider.currentAffirmation!,
                                    ),
                                    isFavorite: _isFavorite(
                                      affirmationProvider.currentAffirmation!,
                                      affirmationProvider.favoriteAffirmations,
                                    ),
                                  ),
                                )
                              else
                                _buildEmptyState(),
                              
                              // Swipe hint
                              if (affirmationProvider.currentAffirmation != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: AppTheme.spacingM),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.swipe_left,
                                        size: 16,
                                        color: AppTheme.textLight,
                                      ),
                                      const SizedBox(width: AppTheme.spacingXS),
                                      Text(
                                        'Swipe left for next, right for previous',
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
                                ),
                              
                              const SizedBox(height: AppTheme.spacingXL),
                              
                              // Stats section
                              _buildStatsSection(affirmationProvider),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          const Icon(
            Icons.sentiment_satisfied_alt,
            size: 64,
            color: AppTheme.textLight,
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'No affirmations available',
            style: AppTheme.headingSmall.copyWith(
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Check your internet connection or try again later.',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(AffirmationProvider affirmationProvider) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Progress',
            style: AppTheme.headingSmall,
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Affirmations',
                  '${affirmationProvider.totalAffirmations}',
                  Icons.auto_awesome,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Favorites',
                  '${affirmationProvider.totalFavorites}',
                  Icons.favorite,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Daily Streak',
                  '${affirmationProvider.dailyStreak}',
                  Icons.local_fire_department,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryTeal,
          size: 32,
        ),
        const SizedBox(height: AppTheme.spacingS),
        Text(
          value,
          style: AppTheme.headingMedium.copyWith(
            color: AppTheme.primaryTeal,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  bool _isFavorite(dynamic affirmation, List<dynamic> favorites) {
    return favorites.any((fav) => fav.id == affirmation.id);
  }

  Future<void> _toggleFavorite(String userId, dynamic affirmation) async {
    final affirmationProvider = context.read<AffirmationProvider>();
    await affirmationProvider.toggleFavorite(userId, affirmation);
  }

  void _showPreviousAffirmation() {
    // For now, just get next affirmation
    // In a full implementation, you'd maintain a history
    context.read<AffirmationProvider>().getNextAffirmation();
  }
}
