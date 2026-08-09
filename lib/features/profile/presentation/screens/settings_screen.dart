import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../auth/data/models/user_profile_model.dart';

/// Real Settings screen (replaces profile_screen.dart's "coming in a
/// later phase" placeholder row) — edits `users.full_name` and
/// `users.phone`. Mirrors signup_screen.dart's form layout and
/// shop_settings_screen.dart's save-changes pattern, per the
/// mirroring map in SESSION_HANDOFF_phaseAH_fixes.md §3.
///
/// FLAGGED ASSUMPTION: email is intentionally read-only here — changing
/// it goes through Supabase Auth's own re-verification flow, a
/// separate, bigger feature than this batch scopes for (see
/// SESSION_HANDOFF_phaseAH_fixes.md Phase D).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Settings',
            style:
                AppTextStyles.headlineMd.copyWith(color: AppColors.onSurface)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: profileAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, stack) => ErrorView(
          message: "We couldn't load your profile. Please try again.",
          onRetry: () => ref.invalidate(currentUserProfileProvider),
        ),
        data: (profile) {
          if (profile == null) {
            // Shouldn't happen for a signed-in user — Settings is only
            // reachable from Profile, which requires an active session.
            return const ErrorView(
              title: 'No profile found',
              message: 'Please try logging in again.',
            );
          }
          return _SettingsForm(profile: profile);
        },
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.profile});
  final UserProfileModel profile;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
    _phoneController = TextEditingController(text: widget.profile.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
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
      await ref.read(authRepositoryProvider).updateProfile(
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          );

      // Invalidate so Profile/Fulfillment pick up the change immediately
      // rather than showing stale cached values.
      ref.invalidate(currentUserProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Settings saved.')));
      context.pop();
    } catch (e, st) {
      debugPrint('SettingsScreen._submit failed: $e\n$st');
      setState(() => _errorMessage = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.marginMain),
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
              const SizedBox(height: AppSpacing.stackMd),
            ],
            CustomTextField(
              label: 'Full Name',
              hintText: 'Jane Doe',
              controller: _nameController,
              prefixIcon: Icons.person_outline,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Full name is required'
                  : null,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            CustomTextField(
              label: 'Phone Number',
              hintText: '+92 300 1234567',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              // Optional — users.phone is nullable per ERD.md §2.
            ),
            const SizedBox(height: AppSpacing.stackMd),
            CustomTextField(
              label: 'Email Address',
              hintText: '',
              controller: TextEditingController(text: widget.profile.email),
              enabled: false,
              prefixIcon: Icons.mail_outline,
            ),
            const SizedBox(height: 4),
            Text(
              'Email can\'t be changed here — contact support if you need to update it.',
              style: AppTextStyles.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.stackLg),
            CustomButton(
              label: 'Save Changes',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
