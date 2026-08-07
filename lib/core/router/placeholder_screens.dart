import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_provider.dart';

class _PlaceholderScaffold extends ConsumerWidget {
  const _PlaceholderScaffold({required this.title});
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$title — coming in a later phase'),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: const Text('Sign out (dev only)'),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerHomePlaceholder extends StatelessWidget {
  const CustomerHomePlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const _PlaceholderScaffold(title: 'Customer Home');
}

class OwnerDashboardPlaceholder extends StatelessWidget {
  const OwnerDashboardPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const _PlaceholderScaffold(title: 'Owner Dashboard');
}

class ShopOnboardingPlaceholder extends StatelessWidget {
  const ShopOnboardingPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const _PlaceholderScaffold(title: 'Shop Onboarding');
}

/// Temporary — replaced by the real Order Queue screen in the next
/// batch. Kept (not deleted) so this batch's router/nav wiring has
/// somewhere real to land in the meantime.
class OrderQueuePlaceholder extends StatelessWidget {
  const OrderQueuePlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const _PlaceholderScaffold(title: 'Order Queue');
}

/// Temporary — replaced by the real Booking Calendar screen next batch.
class BookingCalendarPlaceholder extends StatelessWidget {
  const BookingCalendarPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const _PlaceholderScaffold(title: 'Booking Calendar');
}

/// Temporary — replaced by the real Menu Management screen next batch.
class MenuManagementPlaceholder extends StatelessWidget {
  const MenuManagementPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const _PlaceholderScaffold(title: 'Menu Management');
}
