import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/onboarding_flag_store.dart';

final onboardingOverlayControllerProvider =
    AutoDisposeAsyncNotifierProvider<OnboardingOverlayController, bool>(
      OnboardingOverlayController.new,
    );

class OnboardingOverlayController extends AutoDisposeAsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final hasSeen = await ref
        .watch(onboardingFlagStoreProvider)
        .getHasSeenThoughtLogOnboarding();
    return !hasSeen;
  }

  Future<void> dismiss() async {
    await ref
        .read(onboardingFlagStoreProvider)
        .setHasSeenThoughtLogOnboarding();
    state = const AsyncValue<bool>.data(false);
  }
}
