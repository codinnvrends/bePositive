import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
import '../../providers/affirmation_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/focus_areas_chips.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
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
                            'Settings',
                            style: AppTheme.headingMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Content
                  SliverPadding(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Profile & Preferences Section
                        _buildSectionHeader('Profile & Preferences'),
                        const SizedBox(height: AppTheme.spacingM),
                        
                        _buildProfileCard(userProvider),
                        
                        const SizedBox(height: AppTheme.spacingXL),
                        
                        // Notifications moved to dedicated Notifications screen
                        // (see /notification-settings). Removed from Settings page.
                        const SizedBox(height: AppTheme.spacingXL),
                        
                        // Add New Affirmations Section
                        _buildSectionHeader('Add New Affirmations'),
                        const SizedBox(height: AppTheme.spacingM),
                        
                        _buildAddAffirmationCard(),
                        
                        const SizedBox(height: AppTheme.spacingM),
                        
                        _buildManualAffirmationsCard(affirmationProvider),
                        
                        const SizedBox(height: AppTheme.spacingXL),
                        
                        // App Information Section
                        _buildSectionHeader('About'),
                        const SizedBox(height: AppTheme.spacingM),
                        
                        _buildAboutCard(),
                      ]),
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTheme.headingSmall.copyWith(
        color: AppTheme.textDark,
      ),
    );
  }

  Widget _buildProfileCard(UserProvider userProvider) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Age Group: ${userProvider.displayAgeGroup}',
                style: AppTheme.bodyMedium,
              ),
              const Spacer(),
              IconButton(
                onPressed: () => context.push('/profile-settings'),
                icon: const Icon(Icons.edit),
                iconSize: 20,
                color: AppTheme.textLight,
              ),
            ],
          ),
          
          Text(
            'Gender: ${userProvider.displayGender}',
            style: AppTheme.bodyMedium,
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          Text(
            'Focus Areas',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingS),
          
          FocusAreasChips(
            focusAreas: userProvider.displayFocusAreas,
            showAll: true,
          ),
        ],
      ),
    );
  }

  // Notification card removed from Settings; configuration now lives under
  // the dedicated Notifications tab/screen.

  Widget _buildAddAffirmationCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.secondaryPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.add,
              color: AppTheme.secondaryPurple,
              size: 24,
            ),
          ),
          
          const SizedBox(width: AppTheme.spacingM),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add New Affirmation',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Create your own personalized affirmations',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          
          const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppTheme.textLight,
          ),
        ],
      ),
    );
  }

  Widget _buildManualAffirmationsCard(AffirmationProvider affirmationProvider) {
    // Get custom affirmations
    final customAffirmations = affirmationProvider.affirmations
        .where((a) => a.isCustom)
        .take(2)
        .toList();

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manual Affirmations',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          if (customAffirmations.isEmpty)
            Text(
              'No custom affirmations yet. Tap the + button above to add your first one.',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textLight,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...customAffirmations.map((affirmation) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
              child: Row(
                children: [
                  const Icon(
                    Icons.format_quote,
                    size: 16,
                    color: AppTheme.textLight,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      affirmation.content,
                      style: AppTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Edit affirmation
                    },
                    icon: const Icon(Icons.edit),
                    iconSize: 16,
                    color: AppTheme.textLight,
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: AppTheme.spacingM),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BePositive!',
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Version 1.0.0',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          Text(
            'Your daily source of personalized motivation and positivity. All data is stored locally on your device for complete privacy.',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textLight,
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Show privacy policy
                  },
                  child: const Text('Privacy Policy'),
                ),
              ),
              
              const SizedBox(width: AppTheme.spacingM),
              
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Show about dialog
                  },
                  child: const Text('About'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
