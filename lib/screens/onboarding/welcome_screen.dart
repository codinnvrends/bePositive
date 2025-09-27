import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../services/storage_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkUserState();
  }

  Future<void> _checkUserState() async {
    try {
      // Initialize storage service
      await StorageService().initialize();
      
      // Load user profile
      if (mounted) {
        await context.read<UserProvider>().loadUserProfile();
      }

      if (mounted) {
        final storageService = StorageService();
        final isFirstLaunch = await storageService.isFirstLaunch();
        final userProvider = context.read<UserProvider>();

        // If not first launch and user has profile, redirect to home
        if (!isFirstLaunch && userProvider.hasProfile) {
          context.go('/home');
        }
      }
    } catch (e) {
      // On error, stay on welcome screen (which is the current screen)
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo with growth animation
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                gradient: AppTheme.cardGradient,
                                borderRadius: BorderRadius.circular(40),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryTeal.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.trending_up,
                                size: 80,
                                color: Colors.white,
                              ),
                            ),
                            
                            const SizedBox(height: AppTheme.spacingXL),
                            
                            // Welcome text
                            Text(
                              'Welcome to Affirm!',
                              style: AppTheme.headingLarge.copyWith(
                                fontSize: 32,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            const SizedBox(height: AppTheme.spacingM),
                            
                            // Description
                            Text(
                              'Your daily source of personalized\nmotivation & positivity',
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.textLight,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      // Get Started Button
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: Container(
                                decoration: AppTheme.buttonGradientDecoration,
                                child: ElevatedButton(
                                  onPressed: () => context.push('/age-selection'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                                    ),
                                  ),
                                  child: Text(
                                    'Get Started',
                                    style: AppTheme.buttonText.copyWith(
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: AppTheme.spacingL),
                            
                            // Privacy note
                            Text(
                              'All your data stays on your device.\nWe respect your privacy.',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textLight,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
