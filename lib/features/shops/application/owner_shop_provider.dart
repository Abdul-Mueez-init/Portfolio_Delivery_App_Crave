import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/shop_model.dart';
import 'shops_provider.dart';

/// Owner-side: this owner's shop, or null if they haven't onboarded
/// yet. Distinct from shopDetailProvider (customer-facing, keyed by an
/// explicit shopId) — this is keyed implicitly by the signed-in user,
/// and shared by Dashboard, Order Queue, Booking Calendar, Menu
/// Management, and Shop Settings so none of them re-derive "my shop"
/// separately. autoDispose: leaving the owner shell (e.g. sign out)
/// tears the fetch down rather than caching a stale shop for whoever
/// signs in next.
final myShopProvider = FutureProvider.autoDispose<ShopModel?>((ref) async {
  final ownerId = Supabase.instance.client.auth.currentUser?.id;
  if (ownerId == null) return null;
  final repo = ref.watch(shopsRepositoryProvider);
  return repo.fetchShopByOwnerId(ownerId);
});
