import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../application/auth_provider.dart';
import '../../data/models/user_role.dart';
import '../utils/post_auth_navigation.dart';
import '../widgets/role_option_card.dart';

/// One-time landing for a brand-new Google sign-in with no role chosen
/// beforehand (i.e. they tapped Google from Login, not Signup). Once a
/// `users` row exists, Splash routes straight past this screen forever.
class RolePickerScreen extends ConsumerStatefulWidget {
  const RolePickerScreen({super.key});

  @override
  ConsumerState<RolePickerScreen> createState() => _RolePickerScreenState();
}

class _RolePickerScreenState extends ConsumerState<RolePickerScreen> {
  UserRole _selectedRole = UserRole.customer;
  bool _isSubmitting = false;

  Future<void> _confirm() async {
    setState(() => _isSubmitting = true);
    final authRepo = ref.read(authRepositoryProvider);
    await authRepo.ensureProfileWithRole(
      fullName: authRepo.currentUserDisplayNameFallback,
      role: _selectedRole,
    );
    if (!mounted) return;
    await navigateAfterAuth(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.marginMain),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'One last thing',
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineLgMobile
                    .copyWith(color: AppColors.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                'What are you here to do?',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              SizedBox(height: AppSpacing.stackLg),
              Row(
                children: [
                  RoleOptionCard(
                    role: UserRole.customer,
                    title: 'Order & Book',
                    subtitle: 'Find shops nearby',
                    icon: Icons.shopping_bag_outlined,
                    selected: _selectedRole == UserRole.customer,
                    onTap: () =>
                        setState(() => _selectedRole = UserRole.customer),
                  ),
                  SizedBox(width: AppSpacing.gutter),
                  RoleOptionCard(
                    role: UserRole.owner,
                    title: 'Manage a Shop',
                    subtitle: 'List your business',
                    icon: Icons.storefront_outlined,
                    selected: _selectedRole == UserRole.owner,
                    onTap: () => setState(() => _selectedRole = UserRole.owner),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.stackLg),
              CustomButton(
                  label: 'Continue',
                  isLoading: _isSubmitting,
                  onPressed: _confirm),
            ],
          ),
        ),
      ),
    );
  }
}
