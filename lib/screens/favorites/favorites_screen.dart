import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/affirmation_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/affirmation_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadFavorites();
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

  Future<void> _loadFavorites() async {
    final userProvider = context.read<UserProvider>();
    final affirmationProvider = context.read<AffirmationProvider>();
    
    if (userProvider.hasProfile) {
      await affirmationProvider.loadFavorites(userProvider.userProfile!.id);
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
            return FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    floating: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    flexibleSpace: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingL,
                        vertical: AppTheme.spacingM,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Favorites',
                            style: AppTheme.headingMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          
                          const Spacer(),
                          
                          // Favorites count
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingM,
                              vertical: AppTheme.spacingS,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.favorite,
                                  color: AppTheme.primaryTeal,
                                  size: 16,
                                ),
                                const SizedBox(width: AppTheme.spacingXS),
                                Text(
                                  '${affirmationProvider.totalFavorites}',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.primaryTeal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Content
                  if (affirmationProvider.isLoading)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (affirmationProvider.favoriteAffirmations.isEmpty)
                    SliverFillRemaining(
                      child: _buildEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(AppTheme.spacingL),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final affirmation = affirmationProvider.favoriteAffirmations[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppTheme.spacingL),
                              child: FavoriteAffirmationCard(
                                affirmation: affirmation,
                                onRemove: () => _removeFavorite(
                                  userProvider.userProfile!.id,
                                  affirmation,
                                ),
                                onShare: () => _shareAffirmation(affirmation),
                              ),
                            );
                          },
                          childCount: affirmationProvider.favoriteAffirmations.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.favorite_outline,
              size: 60,
              color: AppTheme.primaryTeal,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          Text(
            'No favorites yet',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.textLight,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          Text(
            'Start adding affirmations to your favorites by tapping the heart icon on any affirmation.',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textLight,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to home screen
              DefaultTabController.of(context)?.animateTo(0);
            },
            icon: const Icon(Icons.home),
            label: const Text('Browse Affirmations'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFavorite(String userId, dynamic affirmation) async {
    final affirmationProvider = context.read<AffirmationProvider>();
    await affirmationProvider.toggleFavorite(userId, affirmation);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Removed from favorites'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              affirmationProvider.toggleFavorite(userId, affirmation);
            },
          ),
        ),
      );
    }
  }

  void _shareAffirmation(dynamic affirmation) {
    // Implement share functionality
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon!'),
      ),
    );
  }
}

class FavoriteAffirmationCard extends StatelessWidget {
  final dynamic affirmation;
  final VoidCallback onRemove;
  final VoidCallback onShare;

  const FavoriteAffirmationCard({
    super.key,
    required this.affirmation,
    required this.onRemove,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with actions
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingS,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  affirmation.category,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryTeal,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Share button
              IconButton(
                onPressed: onShare,
                icon: const Icon(Icons.share),
                iconSize: 20,
                color: AppTheme.textLight,
              ),
              
              // Remove button
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.favorite),
                iconSize: 20,
                color: AppTheme.errorRed,
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          // Affirmation text
          Text(
            affirmation.content,
            style: AppTheme.affirmationText.copyWith(
              fontSize: 18,
            ),
          ),
          
        ],
      ),
    );
  }
}
