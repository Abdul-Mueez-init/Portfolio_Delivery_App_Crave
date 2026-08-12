import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/saved_address_model.dart';

/// Follows the same pattern as BookingsRepository/AuthRepository: plain
/// class wrapping SupabaseClient, throws on failure, client injected
/// rather than reached for as a singleton inside methods.
///
/// Backs the Saved Addresses screen (previously a "coming in a later
/// phase" placeholder row on Profile). The 4-address cap and
/// single-default enforcement both live in the database (see the SQL
/// migration's triggers), not just here — same "enforce it for real"
/// pattern as the booking capacity RPCs.
class AddressesRepository {
  AddressesRepository(this._client);

  final SupabaseClient _client;

  Future<List<SavedAddressModel>> fetchAddresses() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('fetchAddresses called with no signed-in user.');
    }

    final rows = await _client
        .from('saved_addresses')
        .select()
        .eq('user_id', userId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => SavedAddressModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<SavedAddressModel> addAddress({
    String? label,
    required String address,
    double? lat,
    double? lng,
    bool isDefault = false,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('addAddress called with no signed-in user.');
    }

    final row = await _client
        .from('saved_addresses')
        .insert({
          'user_id': userId,
          'label': label,
          'address': address,
          'lat': lat,
          'lng': lng,
          'is_default': isDefault,
        })
        .select()
        .single();

    return SavedAddressModel.fromMap(row);
  }

  Future<SavedAddressModel> setDefault(String addressId) async {
    final row = await _client
        .from('saved_addresses')
        .update({'is_default': true})
        .eq('id', addressId)
        .select()
        .single();
    return SavedAddressModel.fromMap(row);
  }

  Future<void> deleteAddress(String addressId) async {
    await _client.from('saved_addresses').delete().eq('id', addressId);
  }
}
