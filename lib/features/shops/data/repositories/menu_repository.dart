import 'dart:typed_data';

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

  /// Owner's "+ Add Item" (design.md screen 19) — real insert into
  /// menu_items, scoped by shop_id (RLS also enforces
  /// shop.owner_id = auth.uid() on the write — ERD.md §3).
  Future<MenuItemModel> createMenuItem({
    required String shopId,
    required String name,
    required String description,
    required double price,
    required String category,
    String imageUrl = '',
    bool isAvailable = true,
  }) async {
    final row = await _client
        .from('menu_items')
        .insert({
          'shop_id': shopId,
          'name': name,
          'description': description,
          'price': price,
          'category': category,
          'image_url': imageUrl,
          'is_available': isAvailable,
        })
        .select()
        .single();
    return MenuItemModel.fromMap(row);
  }

  /// Owner's item Edit action. Partial update, same pattern as
  /// ShopsRepository.updateShop — only non-null fields are written.
  Future<MenuItemModel> updateMenuItem({
    required String itemId,
    String? name,
    String? description,
    double? price,
    String? category,
    String? imageUrl,
    bool? isAvailable,
  }) async {
    final updates = <String, dynamic>{
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (price != null) 'price': price,
      if (category != null) 'category': category,
      if (imageUrl != null) 'image_url': imageUrl,
      if (isAvailable != null) 'is_available': isAvailable,
    };
    final row = await _client
        .from('menu_items')
        .update(updates)
        .eq('id', itemId)
        .select()
        .single();
    return MenuItemModel.fromMap(row);
  }

  /// Manage Menu's inline "IN STOCK" toggle (design.md screen 19) — a
  /// dedicated method since it's the single most frequent write on that
  /// screen, even though it's just a thin wrapper over updateMenuItem.
  Future<MenuItemModel> setAvailability({
    required String itemId,
    required bool isAvailable,
  }) {
    return updateMenuItem(itemId: itemId, isAvailable: isAvailable);
  }

  /// FLAGGED DECISION (rules.md §5 vs the Stitch design's literal
  /// "Delete" swipe action): rules.md §5 is explicit — menu items are
  /// never hard-deleted, only deactivated, because order_items.menu_item_id
  /// references them and past orders must stay valid. So "Delete" in the
  /// UI is wired to a soft delete here (is_available=false), not a real
  /// row deletion. A true hard-delete would need to check for zero
  /// referencing order_items first — more than this MVP pass needs, and
  /// contradicts the explicit rule anyway.
  Future<MenuItemModel> deleteMenuItem(String itemId) {
    return updateMenuItem(itemId: itemId, isAvailable: false);
  }

  /// Uploads a menu item photo to the `shop-images` bucket — same
  /// bucket as shop covers, different path prefix. Timestamped path
  /// (unlike the shop cover's stable path) since a shop has many items
  /// and each needs its own unique file.
  Future<String> uploadMenuItemImage({
    required String shopId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    final path =
        'menu/$shopId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    await _client.storage.from('shop-images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('shop-images').getPublicUrl(path);
  }
}
