import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/saved_address_model.dart';
import '../data/repositories/addresses_repository.dart';

final addressesRepositoryProvider = Provider<AddressesRepository>((ref) {
  return AddressesRepository(Supabase.instance.client);
});

/// autoDispose — Saved Addresses is a transient screen, same reasoning
/// as `timeSlotsProvider`/`ownerUpcomingSlotsProvider`. Invalidated
/// manually after add/delete/set-default rather than kept as a stream.
final savedAddressesProvider =
    FutureProvider.autoDispose<List<SavedAddressModel>>((ref) async {
  final repo = ref.watch(addressesRepositoryProvider);
  return repo.fetchAddresses();
});
