import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/router/app_router.dart';
import '../../../shops/data/repositories/shops_repository.dart';
import '../../application/auth_provider.dart';
import '../../data/models/user_role.dart';

/// Phase 8: resolves the TODO this file used to carry — an owner with
/// no shop yet goes to Shop Onboarding, an owner who's already
/// onboarded goes straight to the Dashboard. Reads via ShopsRepository
/// directly (not a Riverpod provider) since this is a one-shot check
/// inside an imperative navigation function, not something a widget
/// subscribes to.
Future<void> navigateAfterAuth(BuildContext context, WidgetRef ref) async {
  final role = await ref.read(authRepositoryProvider).fetchCurrentUserRole();
  if (!context.mounted) return;

  if (role == UserRole.owner) {
    final ownerId = Supabase.instance.client.auth.currentUser!.id;
    final shopsRepo = ShopsRepository(Supabase.instance.client);
    final shop = await shopsRepo.fetchShopByOwnerId(ownerId);
    if (!context.mounted) return;

    context.go(
      shop == null ? AppRoutes.shopOnboarding : AppRoutes.ownerDashboard,
    );
  } else {
    context.go(AppRoutes.customerHome);
  }
}
