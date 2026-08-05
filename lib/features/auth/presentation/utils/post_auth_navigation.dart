import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../application/auth_provider.dart';
import '../../data/models/user_role.dart';

Future<void> navigateAfterAuth(BuildContext context, WidgetRef ref) async {
  final role = await ref.read(authRepositoryProvider).fetchCurrentUserRole();
  if (!context.mounted) return;

  if (role == UserRole.owner) {
    // TODO Phase 8: branch to AppRoutes.shopOnboarding if this owner has no shop yet.
    context.go(AppRoutes.ownerDashboard);
  } else {
    context.go(AppRoutes.customerHome);
  }
}
