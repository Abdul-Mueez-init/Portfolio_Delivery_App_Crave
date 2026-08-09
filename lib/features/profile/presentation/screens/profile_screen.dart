import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/customer_bottom_nav.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../auth/data/models/user_profile_model.dart';

/// Matches profile_updated/code.html: avatar + name/email header, a
/// grouped menu list, Log Out.
///
/// Phase E update (SESSION_HANDOFF_phaseAH_fixes.md): now reads name/
/// email/avatar from currentUserProfileProvider (the real `users` row)
/// instead of Supabase auth's userMetadata, which only Google Sign-In
/// ever populated — email/password accounts previously never showed an
/// avatar even after one was set. The avatar itself is now tappable:
/// pick → preview → upload, same flow as menu_item_form_screen.dart's
/// _ImagePicker, uploading to the shared `shop-images` bucket under an
/// `avatars/` prefix (AuthRepository.uploadAvatarImage).
///
/// FLAGGED SCOPE NOTE: profile_updated's Stitch design shows "Saved
/// Addresses" and "Payment Methods" rows — neither has a backing table
/// or feature yet (not in ERD.md, not in PRD.md's MVP scope). They're
/// shown here as inert rows with a "coming soon" tap response rather
/// than omitted outright, so the screen still visually matches the
/// design reference — but don't mistake them for wired features.
/// "Order History" and "Settings" are both real now.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingAvatar = false;

  Future<void> _pickAndUploadAvatar() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    final Uint8List bytes = await picked.readAsBytes();
    final String fileExt = picked.path.split('.').last;

    setState(() => _isUploadingAvatar = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final url = await repo.uploadAvatarImage(bytes: bytes, fileExt: fileExt);
      await repo.updateAvatarUrl(url);
      // Invalidate so the header rebuilds with the new photo immediately
      // rather than showing the stale cached one until next navigation.
      ref.invalidate(currentUserProfileProvider);
    } catch (e, st) {
      debugPrint('ProfileScreen._pickAndUploadAvatar failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            Expanded(
              child: profileAsync.when(
                loading: () => const LoadingIndicator(),
                error: (error, stack) => ErrorView(
                  message: "We couldn't load your profile. Please try again.",
                  onRetry: () => ref.invalidate(currentUserProfileProvider),
                ),
                data: (profile) {
                  // Shouldn't happen for a signed-in user — Profile is
                  // only reachable with an active session — but fall
                  // back to the display-name-only path rather than a
                  // dead end if the users row is somehow missing.
                  final displayName = profile?.fullName.isNotEmpty == true
                      ? profile!.fullName
                      : ref
                          .read(authRepositoryProvider)
                          .currentUserDisplayNameFallback;
                  final email = profile?.email ?? '';
                  final avatarUrl = profile?.avatarUrl;

                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.marginMain),
                    children: [
                      const SizedBox(height: AppSpacing.stackMd),
                      _AvatarHeader(
                        name: displayName,
                        email: email,
                        avatarUrl: avatarUrl,
                        isUploading: _isUploadingAvatar,
                        onTapAvatar: _pickAndUploadAvatar,
                      ),
                      const SizedBox(height: AppSpacing.stackLg),
                      _MenuGroup(
                        items: [
                          _MenuItemData(
                            icon: Icons.location_on_outlined,
                            label: 'Saved Addresses',
                          ),
                          _MenuItemData(
                            icon: Icons.credit_card_outlined,
                            label: 'Payment Methods',
                          ),
                          _MenuItemData(
                            icon: Icons.receipt_long_outlined,
                            label: 'Order History',
                            // The one real row — jumps to Activity's
                            // Orders tab rather than opening a dead end.
                            onTap: () => context.go(AppRoutes.activity),
                          ),
                          _MenuItemData(
                            icon: Icons.settings_outlined,
                            label: 'Settings',
                            onTap: () => context.push(AppRoutes.settings),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.stackLg * 2),
                      _LogOutButton(
                        onTap: () async {
                          await ref.read(authRepositoryProvider).signOut();
                          // AppRouter's redirect already sends a signed-out
                          // user to /login on the next auth-state tick, but
                          // going explicitly avoids a one-frame flash of
                          // this screen with a null user.
                          if (context.mounted) context.go(AppRoutes.login);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomerBottomNav(currentIndex: 2),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.marginMain,
        vertical: AppSpacing.stackSm,
      ),
      child: Center(
        child: Text('Profile',
            style: AppTextStyles.headlineLgMobile
                .copyWith(color: AppColors.onSurface)),
      ),
    );
  }
}

class _AvatarHeader extends StatelessWidget {
  const _AvatarHeader({
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.isUploading,
    required this.onTapAvatar,
  });

  final String name;
  final String email;
  final String? avatarUrl;
  final bool isUploading;
  final VoidCallback onTapAvatar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: isUploading ? null : onTapAvatar,
          child: Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceVariant,
                  border: Border.all(
                      color: AppColors.surfaceContainerLowest, width: 4),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.onSurface.withValues(alpha: 0.08),
                        blurRadius: 12),
                  ],
                ),
                child: ClipOval(
                  child: (avatarUrl == null || avatarUrl!.isEmpty)
                      ? const Icon(Icons.person,
                          size: 48, color: AppColors.secondary)
                      : Image.network(
                          avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => const Icon(
                              Icons.person,
                              size: 48,
                              color: AppColors.secondary),
                        ),
                ),
              ),
              if (isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black38,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.surfaceContainerLowest, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_outlined,
                        size: 14, color: AppColors.onPrimaryContainer),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.stackMd),
        Text(name, style: AppTextStyles.headlineMd),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(email, style: AppTextStyles.bodySm),
        ],
      ],
    );
  }
}

class _MenuItemData {
  _MenuItemData({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});
  final List<_MenuItemData> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.03),
              blurRadius: 16),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _MenuRow(item: items[i]),
            if (i != items.length - 1)
              const Divider(
                  height: 1, indent: 56, color: AppColors.outlineVariant),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item});
  final _MenuItemData item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap ??
          () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('${item.label} — coming in a later phase')),
              ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.stackMd, vertical: AppSpacing.stackMd),
        child: Row(
          children: [
            Icon(item.icon, size: 22, color: AppColors.tertiary),
            const SizedBox(width: AppSpacing.gutter),
            Expanded(child: Text(item.label, style: AppTextStyles.bodyLg)),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.outline, size: 20),
          ],
        ),
      ),
    );
  }
}

class _LogOutButton extends StatelessWidget {
  const _LogOutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackMd + 2),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Log Out',
                  style: AppTextStyles.headlineMd
                      .copyWith(color: AppColors.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
