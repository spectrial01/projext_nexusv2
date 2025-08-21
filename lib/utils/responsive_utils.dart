// utils/responsive_utils.dart
import 'package:flutter/material.dart';

class ResponsiveUtils {
  static const double _baseWidth = 375.0; // iPhone SE width as base
  static const double _baseHeight = 667.0; // iPhone SE height as base
  
  // Screen breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1440;

  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static double scaleWidth(BuildContext context, double size) {
    return size * (screenWidth(context) / _baseWidth);
  }

  static double scaleHeight(BuildContext context, double size) {
    return size * (screenHeight(context) / _baseHeight);
  }

  static double scaleFactor(BuildContext context) {
    final width = screenWidth(context);
    final height = screenHeight(context);
    return ((width + height) / (_baseWidth + _baseHeight)) * 0.5;
  }

  static double responsiveSize(BuildContext context, double size) {
    return size * scaleFactor(context);
  }

  static double responsiveFontSize(BuildContext context, double fontSize) {
    final factor = scaleFactor(context);
    return (fontSize * factor).clamp(fontSize * 0.7, fontSize * 1.3);
  }

  static EdgeInsets responsivePadding(BuildContext context, EdgeInsets padding) {
    final factor = scaleFactor(context);
    return EdgeInsets.only(
      left: padding.left * factor,
      top: padding.top * factor,
      right: padding.right * factor,
      bottom: padding.bottom * factor,
    );
  }

  static bool isMobile(BuildContext context) {
    return screenWidth(context) < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = screenWidth(context);
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return screenWidth(context) >= tabletBreakpoint;
  }

  static bool isSmallScreen(BuildContext context) {
    return screenWidth(context) < 360 || screenHeight(context) < 640;
  }

  static bool isVerySmallScreen(BuildContext context) {
    return screenWidth(context) < 320 || screenHeight(context) < 568;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  // Get appropriate spacing based on screen size
  static double getSpacing(BuildContext context, SpacingSize size) {
    final factor = scaleFactor(context);
    switch (size) {
      case SpacingSize.xs:
        return 4.0 * factor;
      case SpacingSize.sm:
        return 8.0 * factor;
      case SpacingSize.md:
        return 16.0 * factor;
      case SpacingSize.lg:
        return 24.0 * factor;
      case SpacingSize.xl:
        return 32.0 * factor;
      case SpacingSize.xxl:
        return 48.0 * factor;
    }
  }

  // Get appropriate icon size based on screen
  static double getIconSize(BuildContext context, IconSize size) {
    final factor = scaleFactor(context);
    switch (size) {
      case IconSize.xs:
        return 12.0 * factor;
      case IconSize.sm:
        return 16.0 * factor;
      case IconSize.md:
        return 24.0 * factor;
      case IconSize.lg:
        return 32.0 * factor;
      case IconSize.xl:
        return 48.0 * factor;
    }
  }

  // Adaptive column count for grids
  static int getColumnCount(BuildContext context) {
    final width = screenWidth(context);
    if (width < 600) return 1;
    if (width < 900) return 2;
    if (width < 1200) return 3;
    return 4;
  }

  // Adaptive text scale based on accessibility settings
  static double getAdaptiveTextScale(BuildContext context) {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    return (textScaleFactor * scaleFactor(context)).clamp(0.8, 2.0);
  }

  // Safe area adjustments
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  // Keyboard height
  static double getKeyboardHeight(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }
}

enum SpacingSize { xs, sm, md, lg, xl, xxl }
enum IconSize { xs, sm, md, lg, xl }

// Extension methods for easier usage
extension ResponsiveExtension on num {
  double w(BuildContext context) => ResponsiveUtils.scaleWidth(context, toDouble());
  double h(BuildContext context) => ResponsiveUtils.scaleHeight(context, toDouble());
  double r(BuildContext context) => ResponsiveUtils.responsiveSize(context, toDouble());
  double sp(BuildContext context) => ResponsiveUtils.responsiveFontSize(context, toDouble());
}

extension ResponsiveWidget on Widget {
  Widget responsive(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return this;
      },
    );
  }
}

// Responsive text styles
class ResponsiveTextStyles {
  static TextStyle getHeading1(BuildContext context) {
    return TextStyle(
      fontSize: 32.sp(context),
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    );
  }

  static TextStyle getHeading2(BuildContext context) {
    return TextStyle(
      fontSize: 24.sp(context),
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    );
  }

  static TextStyle getHeading3(BuildContext context) {
    return TextStyle(
      fontSize: 20.sp(context),
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    );
  }

  static TextStyle getBodyLarge(BuildContext context) {
    return TextStyle(
      fontSize: 16.sp(context),
      fontWeight: FontWeight.normal,
      height: 1.5,
    );
  }

  static TextStyle getBodyMedium(BuildContext context) {
    return TextStyle(
      fontSize: 14.sp(context),
      fontWeight: FontWeight.normal,
      height: 1.4,
    );
  }

  static TextStyle getBodySmall(BuildContext context) {
    return TextStyle(
      fontSize: 12.sp(context),
      fontWeight: FontWeight.normal,
      height: 1.3,
    );
  }

  static TextStyle getCaption(BuildContext context) {
    return TextStyle(
      fontSize: 10.sp(context),
      fontWeight: FontWeight.w500,
      letterSpacing: 1.0,
    );
  }
}