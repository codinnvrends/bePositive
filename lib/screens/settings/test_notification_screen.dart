import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/notification_service.dart';
import '../../providers/affirmation_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/app_theme.dart';

class TestNotificationScreen extends StatelessWidget {
  const TestNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Rich Notifications'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Test Rich Notification Features',
              style: AppTheme.headingMedium,
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppTheme.spacingXL),
            
            _buildTestCard(
              context,
              title: 'Rich Notification with Lock Screen',
              description: 'Shows full affirmation content with lock screen visibility',
              buttonText: 'Test Rich Notification',
              onPressed: () => _testRichNotification(context, showOnLockScreen: true),
            ),
            
            const SizedBox(height: AppTheme.spacingL),
            
            _buildTestCard(
              context,
              title: 'Private Notification',
              description: 'Shows notification but hides content on lock screen',
              buttonText: 'Test Private Notification',
              onPressed: () => _testRichNotification(context, showOnLockScreen: false),
            ),
            
            const SizedBox(height: AppTheme.spacingL),
            
            _buildTestCard(
              context,
              title: 'Instant Rich Notification',
              description: 'Shows immediate rich notification with current affirmation',
              buttonText: 'Show Now',
              onPressed: () => _testInstantNotification(context),
            ),
            
            const SizedBox(height: AppTheme.spacingL),
            
            _buildTestCard(
              context,
              title: 'Test 1-Minute Frequency',
              description: 'Debug 1-minute frequency scheduling with detailed logging',
              buttonText: 'Test 1-Min Frequency',
              onPressed: () => _testOneMinuteFrequency(context),
            ),
            
            const SizedBox(height: AppTheme.spacingL),
            
            _buildTestCard(
              context,
              title: 'Verify Background Notifications',
              description: 'Comprehensive test to ensure notifications work when app is closed',
              buttonText: 'Verify Background',
              onPressed: () => _verifyBackgroundNotifications(context),
            ),
            
            const SizedBox(height: AppTheme.spacingL),
            
            _buildTestCard(
              context,
              title: 'Test Sound Fix',
              description: 'Test immediate notification without sound errors (30 seconds)',
              buttonText: 'Test Sound Fix',
              onPressed: () => _testSoundFix(context),
            ),
            
            const SizedBox(height: AppTheme.spacingL),
            
            _buildTestCard(
              context,
              title: 'Debug Notification IDs',
              description: 'Check for ID collisions and show all pending notifications',
              buttonText: 'Debug IDs',
              onPressed: () => _debugNotificationIds(context),
            ),
            
            const SizedBox(height: AppTheme.spacingL),
            
            _buildTestCard(
              context,
              title: 'Test Enhanced Styling',
              description: 'Test enhanced styled notification with teal colors (15 seconds)',
              buttonText: 'Test Enhanced Style',
              onPressed: () => _testEnhancedNotification(context),
            ),
            
            const SizedBox(height: AppTheme.spacingL),
            
            _buildTestCard(
              context,
              title: 'Test Expanded Notification',
              description: 'Test notification that appears in full expanded size (10 seconds)',
              buttonText: 'Test Expanded',
              onPressed: () => _testExpandedNotification(context),
            ),
            
            const Spacer(),
            
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryTeal,
                    size: 24,
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    'Rich notifications include:\n• Full affirmation text\n• Category information\n• Action buttons\n• Lock screen visibility options\n• Brand colors and styling',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryTeal,
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
  }

  Widget _buildTestCard(
    BuildContext context, {
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.headingSmall,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            description,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testRichNotification(BuildContext context, {required bool showOnLockScreen}) async {
    try {
      final affirmationProvider = context.read<AffirmationProvider>();
      final userProvider = context.read<UserProvider>();
      
      // Ensure we have an affirmation to show
      if (affirmationProvider.currentAffirmation == null) {
        if (!affirmationProvider.hasAffirmations) {
          await affirmationProvider.loadAffirmations(userProvider.userProfile);
        }
        if (affirmationProvider.currentAffirmation == null) {
          await affirmationProvider.getNextAffirmation();
        }
      }
      
      final affirmation = affirmationProvider.currentAffirmation;
      if (affirmation == null) {
        _showError(context, 'No affirmation available to test');
        return;
      }
      
      await NotificationService().showRichAffirmationNotification(
        affirmationId: affirmation.id,
        title: 'Test Rich Notification',
        content: affirmation.content,
        category: affirmation.category,
        showOnLockScreen: showOnLockScreen,
      );
      
      _showSuccess(context, showOnLockScreen 
          ? 'Rich notification sent! Check your notification panel and lock screen.'
          : 'Private notification sent! Content will be hidden on lock screen.');
          
    } catch (e) {
      _showError(context, 'Failed to send notification: $e');
    }
  }

  Future<void> _testInstantNotification(BuildContext context) async {
    try {
      final affirmationProvider = context.read<AffirmationProvider>();
      final userProvider = context.read<UserProvider>();
      
      // Ensure we have an affirmation to show
      if (affirmationProvider.currentAffirmation == null) {
        if (!affirmationProvider.hasAffirmations) {
          await affirmationProvider.loadAffirmations(userProvider.userProfile);
        }
        if (affirmationProvider.currentAffirmation == null) {
          await affirmationProvider.getNextAffirmation();
        }
      }
      
      final affirmation = affirmationProvider.currentAffirmation;
      if (affirmation == null) {
        _showError(context, 'No affirmation available to test');
        return;
      }
      
      await NotificationService().showRichAffirmationNotification(
        affirmationId: affirmation.id,
        title: 'Daily Affirmation',
        content: affirmation.content,
        category: affirmation.category,
        showOnLockScreen: true,
      );
      
      _showSuccess(context, 'Instant rich notification sent! Tap it to open the card view.');
      
    } catch (e) {
      _showError(context, 'Failed to send instant notification: $e');
    }
  }

  Future<void> _testOneMinuteFrequency(BuildContext context) async {
    try {
      await NotificationService().testOneMinuteFrequency();
      
      final pendingCount = await NotificationService().getPendingCount();
      _showSuccess(context, 'Debug test completed! Check console logs. Scheduled $pendingCount notifications.');
      
    } catch (e) {
      _showError(context, 'Failed to test 1-minute frequency: $e');
    }
  }

  Future<void> _verifyBackgroundNotifications(BuildContext context) async {
    try {
      final results = await NotificationService().verifyBackgroundNotifications();
      
      final isReady = results['background_ready'] as bool? ?? false;
      final pendingCount = results['pending_notifications'] as int? ?? 0;
      
      if (isReady) {
        _showSuccess(context, '🎉 Background notifications ready! Test notification scheduled. Close app and wait 30 seconds. ($pendingCount pending)');
      } else {
        final issues = <String>[];
        if (results['permission_granted'] != true) issues.add('Permission denied');
        if (results['initialized'] != true) issues.add('Not initialized');
        if (results['timezone_working'] != true) issues.add('Timezone error');
        
        _showError(context, '⚠️ Issues found: ${issues.join(', ')}. Check console logs for details.');
      }
      
    } catch (e) {
      _showError(context, 'Verification failed: $e');
    }
  }

  Future<void> _testSoundFix(BuildContext context) async {
    try {
      await NotificationService().testImmediateNotification();
      _showSuccess(context, '✅ Sound fix test scheduled! Wait 30 seconds for notification. Check console for details.');
      
    } catch (e) {
      _showError(context, '❌ Sound fix test failed: $e');
    }
  }

  Future<void> _debugNotificationIds(BuildContext context) async {
    try {
      // First schedule some test notifications
      await NotificationService().testOneMinuteFrequency();
      _showSuccess(context, '🔍 Debug info logged to console. Check for ID collisions and pending notifications.');
      
    } catch (e) {
      _showError(context, '❌ Debug failed: $e');
    }
  }

  Future<void> _testEnhancedNotification(BuildContext context) async {
    try {
      await NotificationService().testRichNotification();
      _showSuccess(context, '🎨 Enhanced notification scheduled! Wait 15 seconds to see improved styling with teal colors.');
      
    } catch (e) {
      _showError(context, '❌ Enhanced notification test failed: $e');
    }
  }

  Future<void> _testExpandedNotification(BuildContext context) async {
    try {
      await NotificationService().testExpandedNotification();
      _showSuccess(context, '📱 Expanded notification scheduled! Wait 10 seconds to see full-size notification.');
      
    } catch (e) {
      _showError(context, '❌ Expanded notification test failed: $e');
    }
  }

  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
