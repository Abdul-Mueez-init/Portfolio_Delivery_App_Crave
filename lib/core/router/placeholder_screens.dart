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
