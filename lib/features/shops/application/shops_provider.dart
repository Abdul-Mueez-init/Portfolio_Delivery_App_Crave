import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/shop_model.dart';
import '../data/repositories/shops_repository.dart';

final shopsRepositoryProvider = Provider<ShopsRepository>((ref) {
  return ShopsRepository(Supabase.instance.client);
});

/// Full, unfiltered shop list. `pull-to-refresh` on Home should call
/// `ref.invalidate(shopsListProvider)`, not add a separate refresh method.
final shopsListProvider = FutureProvider<List<ShopModel>>((ref) async {
  final repo = ref.watch(shopsRepositoryProvider);
  return repo.fetchAllShops();
});

/// Currently selected category chip. 'All' = no filter.
final selectedCategoryProvider = StateProvider<String>((ref) => 'All');

/// Live search bar text. Debouncing (if wanted) belongs in the widget,
/// not here — this provider just holds the current value.
final shopSearchQueryProvider = StateProvider<String>((ref) => '');

/// Fixed browse-category chips from design.md screen 4. These are the
/// marketplace's static taxonomy, not fetched from `shops.category`
/// (which is free text set per-shop by the owner at onboarding) — see
/// the category-matching note in _categoriesMatch below.
const List<String> shopCategoryChips = [
  'All',
  'Coffee',
  'Restaurants',
  'Healthy',
  'Fast Food',
];

/// Client-side filtered + searched view of shopsListProvider. Kept as a
/// derived Provider (not another FutureProvider) so changing the chip or
/// typing in search never re-hits the network.
final filteredShopsProvider = Provider<AsyncValue<List<ShopModel>>>((ref) {
  final shopsAsync = ref.watch(shopsListProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final query = ref.watch(shopSearchQueryProvider).trim().toLowerCase();

  return shopsAsync.whenData((shops) {
    return shops.where((shop) {
      final matchesCategory = selectedCategory == 'All' ||
          _categoriesMatch(shop.category, selectedCategory);
      final matchesQuery = query.isEmpty ||
          shop.name.toLowerCase().contains(query) ||
          shop.category.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  });
});

/// FLAGGED ASSUMPTION: ERD's `shops.category` is free text (e.g.
/// "Coffee Shop", "Restaurant"), but the chip labels above are a fixed
/// plural-ish taxonomy ("Coffee", "Restaurants"). This normalizes both
/// sides (lowercase, strip a trailing "s") and matches if either
/// contains the other, so "Coffee Shop" ~ "Coffee" and "Restaurant" ~
/// "Restaurants". Revisit if seed.sql picks category values this
/// doesn't cleanly cover (e.g. "Fast Food" needs an exact-ish match,
/// which it gets here since neither side ends in "s").
bool _categoriesMatch(String shopCategory, String chipLabel) {
  String normalize(String s) {
    final lower = s.toLowerCase().trim();
    return lower.endsWith('s') ? lower.substring(0, lower.length - 1) : lower;
  }

  final normalizedShop = normalize(shopCategory);
  final normalizedChip = normalize(chipLabel);
  return normalizedShop.contains(normalizedChip) ||
      normalizedChip.contains(normalizedShop);
}
