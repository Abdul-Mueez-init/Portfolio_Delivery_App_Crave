import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/menu_item_model.dart';

/// Same shape as ShopsRepository: plain class wrapping SupabaseClient,
/// throws on failure, client injected rather than a singleton lookup.
class MenuRepository {
  MenuRepository(this._client);
  final SupabaseClient _client;

  /// Fetches every menu item for a shop, including unavailable ones —
  /// rules.md §5 says unavailable items can't be *added to cart*, not
  /// that they must be hidden. MenuTab decides how to render is_available
  /// == false (greyed out + "Sold Out"), this just returns the real data.
  Future<List<MenuItemModel>> fetchMenuForShop(String shopId) async {
    final rows = await _client
        .from('menu_items')
        .select()
        .eq('shop_id', shopId)
        .order('category', ascending: true);
    return (rows as List)
        .map((row) => MenuItemModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }
}
