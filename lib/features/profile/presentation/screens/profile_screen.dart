import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/customer_bottom_nav.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/application/auth_provider.dart';

/// Matches profile_updated/code.html: avatar + name/email header, a
/// grouped menu list, Log Out.
///
/// FLAGGED SCOPE NOTE: profile_updated's Stitch design shows "Saved
/// Addresses", "Payment Methods", and "Settings" rows — none of these
/// have a backing table or feature yet (not in ERD.md, not in PRD.md's
/// MVP scope, PRD.md §6 doesn't list them either). They're shown here
/// as inert rows with a "coming soon" tap response rather than omitted
/// outright, so the screen still visually matches the design reference
/// — but don't mistake them for wired features. "Order History" is
/// the one row that's real: it just switches Activity to the Orders
/// tab, no separate screen needed.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final displayName =
        ref.read(authRepositoryProvider).currentUserDisplayNameFallback;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.marginMain),
                children: [
                  const SizedBox(height: AppSpacing.stackMd),
                  _AvatarHeader(
                    name: displayName,
                    email: email,
                    avatarUrl: user?.userMetadata?['avatar_url'] as String?,
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
  });

  final String name;
  final String email;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceVariant,
            border: Border.all(color: AppColors.surfaceContainerLowest, width: 4),
            boxShadow: [
              BoxShadow(
                  color: AppColors.onSurface.withValues(alpha: 0.08),
                  blurRadius: 12),
            ],
          ),
          child: ClipOval(
            child: (avatarUrl == null || avatarUrl!.isEmpty)
                ? const Icon(Icons.person, size: 48, color: AppColors.secondary)
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
              const Divider(height: 1, indent: 56, color: AppColors.outlineVariant),
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
                SnackBar(content: Text('${item.label} — coming in a later phase')),
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
              const Icon(Icons.logout_rounded, size: 20, color: AppColors.primary),
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
