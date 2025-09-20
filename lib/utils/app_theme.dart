import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color palette based on design specifications
  static const Color primaryTeal = Color(0xFF6BB6A5);
  static const Color secondaryPurple = Color(0xFF9B8CC7);
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF2D3748);
  static const Color textLight = Color(0xFF718096);
  static const Color successGreen = Color(0xFF48BB78);
  static const Color warningOrange = Color(0xFFED8936);
  static const Color errorRed = Color(0xFFE53E3E);

  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryTeal, secondaryPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFA8E6CF), Color(0xFF88D8C0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Text styles with fallback to system fonts
  static TextStyle get headingLarge => _getTextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textDark,
      );

  static TextStyle get headingMedium => _getTextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textDark,
      );

  static TextStyle get headingSmall => _getTextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textDark,
      );

  static TextStyle get bodyLarge => _getTextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: textDark,
      );

  static TextStyle get bodyMedium => _getTextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: textDark,
      );

  static TextStyle get bodySmall => _getTextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: textLight,
      );

  static TextStyle get buttonText => _getTextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  static TextStyle get captionText => _getTextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: textLight,
      );

  static TextStyle get affirmationText => _getTextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: textDark,
        height: 1.4,
      );

  // Use system fonts to avoid network dependency
  static TextStyle _getTextStyle({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? height,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFamily: 'system-ui', // Use system default
      height: height,
    );
  }

  // Light theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: headingMedium,
        iconTheme: const IconThemeData(color: textDark),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryTeal,
          side: const BorderSide(color: primaryTeal, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: buttonText.copyWith(color: primaryTeal),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryTeal,
          textStyle: bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: primaryTeal,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryTeal;
          }
          return Colors.grey[400];
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryTeal.withOpacity(0.3);
          }
          return Colors.grey[300];
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryTeal,
        unselectedItemColor: textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryTeal, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  // Dark theme (for future implementation)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF1A202C),
      // Add dark theme configurations here
    );
  }

  // Custom decorations
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  static BoxDecoration get affirmationCardDecoration => BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryTeal.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration get buttonGradientDecoration => BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryTeal.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  // Spacing constants
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // Border radius constants
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 20.0;
}
