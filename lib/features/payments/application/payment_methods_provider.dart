import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/payment_method_model.dart';
import '../data/repositories/payment_methods_repository.dart';

final paymentMethodsRepositoryProvider =
    Provider<PaymentMethodsRepository>((ref) {
  return PaymentMethodsRepository(Supabase.instance.client);
});

/// autoDispose — same reasoning as savedAddressesProvider. Invalidated
/// manually after add/delete/set-default and after a checkout save.
final paymentMethodsProvider =
    FutureProvider.autoDispose<List<PaymentMethodModel>>((ref) async {
  final repo = ref.watch(paymentMethodsRepositoryProvider);
  return repo.fetchPaymentMethods();
});
