import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/auth_provider.dart';
import '../utils/post_auth_navigation.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decideDestination());
  }

  // find the whole method and replace with:
  Future<void> _decideDestination() async {
    await Future.delayed(const Duration(milliseconds: 900)); // brand beat
    if (!mounted) return;

    final authRepo = ref.read(authRepositoryProvider);

    if (authRepo.currentSession == null) {
      context.go(AppRoutes.onboarding);
      return;
    }

    final role = await authRepo.fetchCurrentUserRole();
    if (!mounted) return;

    if (role == null) {
      // No `users` row yet — only happens for a brand-new Google
      // sign-in (email signup writes the row synchronously). If a role
      // was picked on Signup before tapping Google, use it now.
      final pendingRole = ref.read(pendingSignupRoleProvider);
      if (pendingRole == null) {
        context.go(AppRoutes.chooseRole);
        return;
      }
      await authRepo.ensureProfileWithRole(
        fullName: authRepo.currentUserDisplayNameFallback,
        role: pendingRole,
      );
      ref.read(pendingSignupRoleProvider.notifier).state = null;
    }

    if (!mounted) return;
    await navigateAfterAuth(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.surfaceContainerHigh),
              ),
              child: Image.asset('assets/images/crave_logo.png',
                  fit: BoxFit.contain),
            ),
            const SizedBox(height: 24),
            Text(
              'Crave',
              style: AppTextStyles.headlineLg.copyWith(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
