import 'dart:typed_data';
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

  /// Used by Shop Detail to fetch a single shop by id.
  Future<ShopModel> fetchShopById(String shopId) async {
    final row = await _client.from('shops').select().eq('id', shopId).single();
    return ShopModel.fromMap(row);
  }

  /// Owner-side: fetches this owner's shop, or null if they haven't
  /// onboarded yet. post_auth_navigation.dart uses this to decide
  /// Shop Onboarding vs Dashboard on login (architecture.md §3).
  Future<ShopModel?> fetchShopByOwnerId(String ownerId) async {
    final row = await _client
        .from('shops')
        .select()
        .eq('owner_id', ownerId)
        .maybeSingle();
    if (row == null) return null;
    return ShopModel.fromMap(row);
  }

  /// Shop Onboarding (design.md screen 20) — real insert tied to
  /// auth.uid(). is_open defaults true so a newly onboarded shop is
  /// immediately live/browsable — MVP has no draft state.
  Future<ShopModel> createShop({
    required String ownerId,
    required String name,
    required String description,
    required String address,
    required String category,
    required bool acceptsDelivery,
    required bool acceptsBooking,
    String coverImageUrl = '',
  }) async {
    final row = await _client
        .from('shops')
        .insert({
          'owner_id': ownerId,
          'name': name,
          'description': description,
          'address': address,
          'category': category,
          'accepts_delivery': acceptsDelivery,
          'accepts_booking': acceptsBooking,
          'cover_image_url': coverImageUrl,
          'is_open': true,
        })
        .select()
        .single();
    return ShopModel.fromMap(row);
  }

  /// Shop Settings (design.md screen 21) — edits anything captured at
  /// onboarding, after the fact. Partial update: only non-null fields
  /// in the argument list are written, so callers don't have to resend
  /// the whole shop every time (e.g. just flipping `is_open`).
  Future<ShopModel> updateShop({
    required String shopId,
    String? name,
    String? description,
    String? address,
    String? category,
    bool? acceptsDelivery,
    bool? acceptsBooking,
    bool? isOpen,
    String? coverImageUrl,
  }) async {
    final updates = <String, dynamic>{
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (address != null) 'address': address,
      if (category != null) 'category': category,
      if (acceptsDelivery != null) 'accepts_delivery': acceptsDelivery,
      if (acceptsBooking != null) 'accepts_booking': acceptsBooking,
      if (isOpen != null) 'is_open': isOpen,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
    };
    final row = await _client
        .from('shops')
        .update(updates)
        .eq('id', shopId)
        .select()
        .single();
    return ShopModel.fromMap(row);
  }

  /// Uploads a shop cover photo to the `shop-images` Storage bucket
  /// (public bucket — one-time console setup, see the Menu Management
  /// batch for exact steps) and returns its public URL. Path is stable
  /// per shop (not timestamped) so re-uploading a cover overwrites the
  /// old file instead of leaking orphaned storage objects.
  Future<String> uploadShopCoverImage({
    required String shopId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    final path = 'covers/$shopId.$fileExt';
    await _client.storage.from('shop-images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('shop-images').getPublicUrl(path);
  }
}
