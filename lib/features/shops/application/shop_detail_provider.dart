import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/shop_model.dart';
import 'shops_provider.dart';

/// One instance per shopId. autoDispose means leaving Shop Detail (and
/// no other widget watching this same shopId) tears the fetch down
/// instead of caching it forever in memory.
final shopDetailProvider =
    FutureProvider.autoDispose.family<ShopModel, String>((ref, shopId) async {
  final repo = ref.watch(shopsRepositoryProvider);
  return repo.fetchShopById(shopId);
});
