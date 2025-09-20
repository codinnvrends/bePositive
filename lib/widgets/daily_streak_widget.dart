import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class DailyStreakWidget extends StatefulWidget {
  final int streak;

  const DailyStreakWidget({
    super.key,
    required this.streak,
  });

  @override
  State<DailyStreakWidget> createState() => _DailyStreakWidgetState();
}

class _DailyStreakWidgetState extends State<DailyStreakWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: -0.1,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void didUpdateWidget(DailyStreakWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streak != widget.streak && widget.streak > oldWidget.streak) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.warningOrange,
                    AppTheme.warningOrange.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.warningOrange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: AppTheme.spacingXS),
                  Text(
                    'Daily Streak: ${widget.streak}',
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class StreakMilestoneDialog extends StatelessWidget {
  final int streak;
  final VoidCallback onContinue;

  const StreakMilestoneDialog({
    super.key,
    required this.streak,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    String title = 'Great Job!';
    String message = 'You\'re building a positive habit!';
    IconData icon = Icons.celebration;
    Color color = AppTheme.successGreen;

    if (streak >= 30) {
      title = 'Amazing! 30 Day Streak!';
      message = 'You\'ve built an incredible positive habit. Keep it up!';
      icon = Icons.emoji_events;
      color = AppTheme.warningOrange;
    } else if (streak >= 14) {
      title = 'Fantastic! 2 Week Streak!';
      message = 'You\'re well on your way to forming a lasting habit!';
      icon = Icons.star;
      color = AppTheme.secondaryPurple;
    } else if (streak >= 7) {
      title = 'Wonderful! 1 Week Streak!';
      message = 'A full week of positive affirmations. You\'re doing great!';
      icon = Icons.auto_awesome;
      color = AppTheme.primaryTeal;
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                icon,
                size: 40,
                color: color,
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingL),
            
            // Title
            Text(
              title,
              style: AppTheme.headingMedium.copyWith(
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            // Message
            Text(
              message,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textLight,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppTheme.spacingXL),
            
            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                ),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
