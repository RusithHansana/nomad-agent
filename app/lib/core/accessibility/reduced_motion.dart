import 'package:flutter/widgets.dart';

class ReducedMotion {
  const ReducedMotion._();

  static bool isEnabled(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return false;
    }
    return mediaQuery.disableAnimations || mediaQuery.accessibleNavigation;
  }
}
