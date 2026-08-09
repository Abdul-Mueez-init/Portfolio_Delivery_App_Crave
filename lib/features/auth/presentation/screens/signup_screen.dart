import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../application/auth_provider.dart';
import '../../data/models/user_role.dart';
import '../utils/post_auth_navigation.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/role_option_card.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  UserRole _selectedRole = UserRole.customer;
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).signUpWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            role: _selectedRole,
          );
      if (!mounted) return;
      await navigateAfterAuth(context, ref);
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _isGoogleSubmitting = true;
      _errorMessage = null;
    });
    try {
      // Stash the chosen role so Splash can write it once the OAuth
      // redirect lands back in the app and a session actually exists.
      ref.read(pendingSignupRoleProvider.notifier).state = _selectedRole;
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMain, vertical: AppSpacing.stackLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      shape: BoxShape.circle),
                  child: Icon(Icons.restaurant,
                      color: AppColors.primary, size: 28),
                ),
              ),
              SizedBox(height: AppSpacing.stackMd),
              Text(
                'Create your account',
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineLgMobile
                    .copyWith(color: AppColors.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                'Join Crave to explore delicious menus.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              SizedBox(height: AppSpacing.stackLg),

              // --- Role picker: not in the Stitch export, added per design.md
              // screen 3 / PLAN.md Phase 3 — this is what go_router's
              // redirect logic depends on downstream.
              Text('I want to...',
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant)),
              SizedBox(height: AppSpacing.stackSm),
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

              Container(
                padding: EdgeInsets.all(AppSpacing.stackLg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: AppTextStyles.bodySm
                                .copyWith(color: AppColors.onErrorContainer),
                          ),
                        ),
                        SizedBox(height: AppSpacing.stackMd),
                      ],
                      CustomTextField(
                        label: 'Full Name',
                        hintText: 'Jane Doe',
                        controller: _nameController,
                        prefixIcon: Icons.person_outline,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Full name is required'
                                : null,
                      ),
                      SizedBox(height: AppSpacing.stackMd),
                      CustomTextField(
                        label: 'Phone Number',
                        hintText: '+92 300 1234567',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                      ),
                      SizedBox(height: AppSpacing.stackMd),
                      CustomTextField(
                        label: 'Email Address',
                        hintText: 'jane@example.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.mail_outline,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Email is required';
                          if (!value.contains('@'))
                            return 'Enter a valid email';
                          return null;
                        },
                      ),
                      SizedBox(height: AppSpacing.stackMd),
                      CustomTextField(
                        label: 'Password',
                        hintText: '••••••••',
                        controller: _passwordController,
                        obscureText: true,
                        prefixIcon: Icons.lock_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Password is required';
                          if (value.length < 6)
                            return 'Use at least 6 characters';
                          return null;
                        },
                      ),
                      SizedBox(height: AppSpacing.stackLg),
                      CustomButton(
                        label: 'Sign Up',
                        isLoading: _isSubmitting,
                        onPressed: _submit,
                      ),
                      SizedBox(height: AppSpacing.stackMd),
                      Row(
                        children: [
                          Expanded(
                              child: Divider(color: AppColors.outlineVariant)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('OR',
                                style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.onSurfaceVariant)),
                          ),
                          Expanded(
                              child: Divider(color: AppColors.outlineVariant)),
                        ],
                      ),
                      SizedBox(height: AppSpacing.stackMd),
                      GoogleSignInButton(
                          onPressed: _submitGoogle,
                          isLoading: _isGoogleSubmitting),
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.stackLg),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Log in.',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => context.go(AppRoutes.login),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
