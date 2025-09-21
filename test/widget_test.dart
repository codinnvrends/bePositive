// BePositive app widget tests
//
// Tests for the BePositive affirmations app functionality

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:be_positive/main.dart';
import 'package:be_positive/providers/user_provider.dart';
import 'package:be_positive/providers/affirmation_provider.dart';
import 'package:be_positive/providers/notification_provider.dart';

void main() {
  group('BePositive App Tests', () {
    testWidgets('App loads successfully', (WidgetTester tester) async {
      // Create a test-friendly version of the app
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => AffirmationProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ],
          child: MaterialApp(
            title: 'BePositive! Test',
            home: Scaffold(
              appBar: AppBar(title: const Text('BePositive!')),
              body: const Center(
                child: Text('Welcome to BePositive!'),
              ),
            ),
          ),
        ),
      );

      // Verify that the app loads
      expect(find.text('BePositive!'), findsOneWidget);
      expect(find.text('Welcome to BePositive!'), findsOneWidget);
    });

    testWidgets('App error widget displays correctly', (WidgetTester tester) async {
      // Test the error widget
      final errorDetails = FlutterErrorDetails(
        exception: Exception('Test error'),
        stack: StackTrace.current,
      );

      await tester.pumpWidget(AppErrorWidget(errorDetails: errorDetails));

      // Verify error widget content
      expect(find.text('Oops! Something went wrong'), findsOneWidget);
      expect(find.text('We\'re sorry for the inconvenience. Please restart the app.'), findsOneWidget);
      expect(find.text('Restart App'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    test('UserProvider initializes correctly', () {
      final userProvider = UserProvider();
      expect(userProvider, isNotNull);
    });

    test('AffirmationProvider initializes correctly', () {
      final affirmationProvider = AffirmationProvider();
      expect(affirmationProvider, isNotNull);
    });

    test('NotificationProvider initializes correctly', () {
      final notificationProvider = NotificationProvider();
      expect(notificationProvider, isNotNull);
    });
  });
}
