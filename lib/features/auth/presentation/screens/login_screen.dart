import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/gestures.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../application/auth_provider.dart';
import '../utils/post_auth_navigation.dart';
import '../widgets/google_sign_in_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
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
      // No role picker on Login — never inherit a stale Signup
      // selection. A brand-new account from here lands on
      // RolePickerScreen instead.
      ref.read(pendingSignupRoleProvider.notifier).state = null;
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
              SizedBox(height: AppSpacing.stackLg),
              Text(
                'Crave',
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineLg.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: AppSpacing.stackSm),
              Text(
                'Welcome back',
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineLgMobile
                    .copyWith(color: AppColors.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                'Log in to access your saved cravings.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              SizedBox(height: AppSpacing.stackLg),
              Container(
                padding: EdgeInsets.all(AppSpacing.stackLg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: AppColors.surfaceContainerLow),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 12,
                        offset: Offset(0, 4))
                  ],
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
                        label: 'Email',
                        hintText: 'your@email.com',
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Password',
                              style: AppTextStyles.bodySm
                                  .copyWith(color: AppColors.onSurface)),
                          GestureDetector(
                            onTap: () {
                              // TODO: build forgot-password flow (Supabase resetPasswordForEmail) — not in Phase 3 scope
                            },
                            child: Text(
                              'Forgot?',
                              style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _passwordController,
                        hintText: '••••••••',
                        obscureText: true,
                        prefixIcon: Icons.lock_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Password is required';
                          return null;
                        },
                      ),
                      SizedBox(height: AppSpacing.stackLg),
                      CustomButton(
                        label: 'Log In',
                        isLoading: _isSubmitting,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.stackLg),
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.outlineVariant)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('or continue with',
                        style: AppTextStyles.bodySm
                            .copyWith(color: AppColors.onSurfaceVariant)),
                  ),
                  Expanded(child: Divider(color: AppColors.outlineVariant)),
                ],
              ),
              SizedBox(height: AppSpacing.stackLg),
              GoogleSignInButton(
                  onPressed: _submitGoogle, isLoading: _isGoogleSubmitting),
              SizedBox(height: AppSpacing.stackLg),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                    children: [
                      const TextSpan(text: "Don't have an account? "),
                      TextSpan(
                        text: 'Sign up.',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => context.go(AppRoutes.signup),
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
