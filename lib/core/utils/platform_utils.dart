// SentinelX - Platform Utilities
// Detects runtime platform and provides adaptive layout breakpoints.

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

enum SentinelPlatform { windows, android, other }

class PlatformUtils {
  PlatformUtils._();

  static SentinelPlatform get current {
    if (kIsWeb) return SentinelPlatform.other;
    if (Platform.isWindows) return SentinelPlatform.windows;
    if (Platform.isAndroid) return SentinelPlatform.android;
    return SentinelPlatform.other;
  }

  static bool get isDesktop => current == SentinelPlatform.windows;
  static bool get isMobile => current == SentinelPlatform.android;
  static bool get isWindows => current == SentinelPlatform.windows;
  static bool get isAndroid => current == SentinelPlatform.android;
}

class LayoutBreakpoints {
  LayoutBreakpoints._();

  static const double compact = 600;
  static const double medium = 840;
  static const double expanded = 1200;
  static const double ultraWide = 1600;
}
