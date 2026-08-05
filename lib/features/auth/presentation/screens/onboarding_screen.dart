import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/custom_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    child: Image.asset(
                      'assets/images/onboarding_hero.jpg', // export from onboarding_screen/screen.png
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 24,
                    left: 0,
                    right: 0,
                    child: Text(
                      'Crave',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineMd
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: AppSpacing.marginMain),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Order ahead or book a table — no calling required.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineMd
                          .copyWith(color: AppColors.onSurface),
                    ),
                    SizedBox(height: AppSpacing.stackSm),
                    Text(
                      'Discover local spots and skip the wait with just a few taps.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyLg
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                    const Spacer(),
                    CustomButton(
                      label: 'Get Started',
                      icon: Icons.arrow_forward,
                      onPressed: () => context.go(AppRoutes.login),
                    ),
                    SizedBox(height: AppSpacing.stackMd),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
