import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shop_model.dart';

/// Follows the same pattern as AuthRepository: plain class wrapping
/// SupabaseClient, throws on failure (no Result wrapper), constructed
/// with the client injected rather than reaching for a singleton inside
/// methods — makes it trivially testable later (Phase 10).
class ShopsRepository {
  ShopsRepository(this._client);
  final SupabaseClient _client;

  /// Fetches every shop in the marketplace — customers browse the full
  /// list, including closed shops (shown with a "Closed" badge per
  /// design.md screen 4), so there's no `is_open` filter here.
  ///
  /// No category/search filter at the query level: MVP shop counts are
  /// small enough that filtering client-side (see shops_provider.dart)
  /// avoids a network round-trip on every chip tap or keystroke. If the
  /// seed data grows large, this is the first place to revisit.
  Future<List<ShopModel>> fetchAllShops() async {
    final rows =
        await _client.from('shops').select().order('name', ascending: true);
    return (rows as List)
        .map((row) => ShopModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Used by Shop Detail (next batch) to fetch a single shop by id.
  Future<ShopModel> fetchShopById(String shopId) async {
    final row = await _client.from('shops').select().eq('id', shopId).single();
    return ShopModel.fromMap(row);
  }
}
