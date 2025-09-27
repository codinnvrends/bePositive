import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'providers/user_provider.dart';
import 'providers/affirmation_provider.dart';
import 'providers/notification_provider.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'database/database_helper.dart';
import 'models/notification_settings.dart';
import 'utils/app_theme.dart';
import 'utils/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await _initializeServices();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(const BePositiveApp());
}

Future<void> _initializeServices() async {
  try {
    // Initialize storage service
    await StorageService().initialize();
    
    // Initialize notification service with error handling
    try {
      await NotificationService().initialize();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to initialize notification service: $e');
      }
      // Continue app initialization even if notifications fail
    }

    // If device rebooted, reschedule notifications from persisted settings
    final bootPending = await StorageService().getBool('boot_reschedule_pending') ?? false;
    if (bootPending) {
      try {
        final userId = await StorageService().getUserId() ?? 'default';
        final db = DatabaseHelper();
        final NotificationSettings settings = await db.getNotificationSettings(userId);
        await NotificationService().scheduleAffirmationNotifications(settings);
        await StorageService().setBool('boot_reschedule_pending', false);
        if (kDebugMode) debugPrint('Rescheduled notifications after boot for user: $userId');
      } catch (e) {
        if (kDebugMode) debugPrint('Failed to reschedule after boot: $e');
      }
    }
  } catch (e) {
    debugPrint('Error initializing services: $e');
  }
}

class BePositiveApp extends StatelessWidget {
  const BePositiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => AffirmationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          return MaterialApp.router(
            title: 'BePositive!',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.router,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.noScaling,
                ),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}

class AppLifecycleManager extends StatefulWidget {
  final Widget child;

  const AppLifecycleManager({
    super.key,
    required this.child,
  });

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Check for pending notification actions when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingNotificationAction();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _onAppResumed() async {
    // App came to foreground
    // Check for pending notification actions
    await _handlePendingNotificationAction();
    debugPrint('App resumed');
  }

  Future<void> _handlePendingNotificationAction() async {
    try {
      final pendingAffirmationId = await StorageService().getString('pending_affirmation_id');
      final notificationAction = await StorageService().getString('notification_action');
      
      if (pendingAffirmationId != null && notificationAction != null) {
        // Clear the pending action
        await StorageService().remove('pending_affirmation_id');
        await StorageService().remove('notification_action');
        
        if (mounted && context.mounted) {
          // Add a small delay to ensure the app is fully loaded
          await Future.delayed(const Duration(milliseconds: 500));
          
          if (mounted && context.mounted) {
            try {
              final router = GoRouter.of(context);
              
              if (notificationAction == 'view_all_cards') {
                // Navigate directly to home screen (cards view) for browsing all affirmations
                debugPrint('Navigating to cards view (home)');
                // Navigate to home screen where user can swipe through cards
                router.go('/home');
              } else if (notificationAction == 'show_specific_card') {
                // Navigate to specific notification card screen
                debugPrint('Navigating to specific card: $pendingAffirmationId');
                router.goNamed(
                  'notification-card',
                  queryParameters: {'affirmationId': pendingAffirmationId},
                );
              } else if (notificationAction == 'show_card_only') {
                // Legacy support - navigate to notification card screen
                debugPrint('Navigating to card (legacy): $pendingAffirmationId');
                router.goNamed(
                  'notification-card',
                  queryParameters: {'affirmationId': pendingAffirmationId},
                );
              }
            } catch (e) {
              debugPrint('Error during navigation: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error handling pending notification action: $e');
    }
  }

  void _onAppPaused() {
    // App went to background
    // Save any pending data
    debugPrint('App paused');
  }

  void _onAppDetached() {
    // App is being terminated
    // Clean up resources
    debugPrint('App detached');
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// Error handling widget
class AppErrorWidget extends StatelessWidget {
  final FlutterErrorDetails errorDetails;

  const AppErrorWidget({
    super.key,
    required this.errorDetails,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BePositive! - Error',
      theme: AppTheme.lightTheme,
      home: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.errorRed,
                ),
                
                const SizedBox(height: AppTheme.spacingL),
                
                Text(
                  'Oops! Something went wrong',
                  style: AppTheme.headingMedium.copyWith(
                    color: AppTheme.errorRed,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: AppTheme.spacingM),
                
                Text(
                  'We\'re sorry for the inconvenience. Please restart the app.',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: AppTheme.spacingXL),
                
                ElevatedButton(
                  onPressed: () {
                    // Restart the app
                    SystemNavigator.pop();
                  },
                  child: const Text('Restart App'),
                ),
                
                const SizedBox(height: AppTheme.spacingM),
                
                if (kDebugMode) ...[
                  ExpansionTile(
                    title: const Text('Error Details'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        child: Text(
                          errorDetails.toString(),
                          style: AppTheme.bodySmall.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Global error handler
void setupErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };

  // Handle platform errors in debug mode
  if (kDebugMode) {
    // Platform error handling for debug builds
    debugPrint('Error handling setup complete');
  }
}
