import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/user_provider.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));

    _animationController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize storage service
      await StorageService().initialize();
      
      // Load user profile
      if (mounted) {
        await context.read<UserProvider>().loadUserProfile();
      }

      // Wait for animation to complete
      await Future.delayed(const Duration(milliseconds: 2500));

      if (mounted) {
        final storageService = StorageService();
        final isFirstLaunch = await storageService.isFirstLaunch();
        final userProvider = context.read<UserProvider>();

        if (isFirstLaunch || !userProvider.hasProfile) {
          context.go('/welcome');
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        // Handle error - show error dialog or go to welcome screen
        context.go('/welcome');
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 60,
                          color: AppTheme.primaryTeal,
                        ),
                      ),
                      
                      const SizedBox(height: AppTheme.spacingXL),
                      
                      // App Name
                      Text(
                        'BePositive!',
                        style: AppTheme.headingLarge.copyWith(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: AppTheme.spacingS),
                      
                      // Tagline
                      Text(
                        'Your daily source of personalized\nmotivation & positivity',
                        textAlign: TextAlign.center,
                        style: AppTheme.bodyLarge.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),
                      
                      const SizedBox(height: AppTheme.spacingXXL),
                      
                      // Loading indicator
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.8),
                          ),
                          strokeWidth: 3,
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
