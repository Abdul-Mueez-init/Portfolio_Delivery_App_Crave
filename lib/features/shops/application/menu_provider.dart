import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/menu_item_model.dart';
import '../data/repositories/menu_repository.dart';

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(Supabase.instance.client);
});

/// Menu items for one shop, keyed by shopId. `.family` so each
/// ShopDetailScreen instance gets its own cached fetch.
final menuForShopProvider =
    FutureProvider.family<List<MenuItemModel>, String>((ref, shopId) async {
  final repo = ref.watch(menuRepositoryProvider);
  return repo.fetchMenuForShop(shopId);
});

/// Groups a flat menu list into category sections, preserving first-seen
/// category order (menu_repository already sorts by category so this is
/// stable, not alphabetically re-sorted here — avoids double-sorting).
Map<String, List<MenuItemModel>> groupByCategory(List<MenuItemModel> items) {
  final grouped = <String, List<MenuItemModel>>{};
  for (final item in items) {
    grouped.putIfAbsent(item.category, () => []).add(item);
  }
  return grouped;
}
