import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/payment_method_model.dart';

/// Follows the same pattern as AddressesRepository/BookingsRepository:
/// plain class wrapping SupabaseClient, throws on failure.
///
/// Backs the Payment Methods screen (previously a "coming in a later
/// phase" placeholder row on Profile). Only ever writes brand/last4/
/// expiry — see PaymentMethodModel's doc comment on why nothing more
/// sensitive is stored, and checkout_screen.dart's _FakeCardSection
/// doc comment on why this stays permanently simulated.
class PaymentMethodsRepository {
  PaymentMethodsRepository(this._client);

  final SupabaseClient _client;

  Future<List<PaymentMethodModel>> fetchPaymentMethods() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('fetchPaymentMethods called with no signed-in user.');
    }

    final rows = await _client
        .from('payment_methods')
        .select()
        .eq('user_id', userId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => PaymentMethodModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<PaymentMethodModel> addPaymentMethod({
    required CardBrand brand,
    required String last4,
    int? expiryMonth,
    int? expiryYear,
    bool isDefault = false,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('addPaymentMethod called with no signed-in user.');
    }

    final row = await _client
        .from('payment_methods')
        .insert({
          'user_id': userId,
          'brand': brand.toDb(),
          'last4': last4,
          'expiry_month': expiryMonth,
          'expiry_year': expiryYear,
          'is_default': isDefault,
        })
        .select()
        .single();

    return PaymentMethodModel.fromMap(row);
  }

  Future<PaymentMethodModel> setDefault(String paymentMethodId) async {
    final row = await _client
        .from('payment_methods')
        .update({'is_default': true})
        .eq('id', paymentMethodId)
        .select()
        .single();
    return PaymentMethodModel.fromMap(row);
  }

  Future<void> deletePaymentMethod(String paymentMethodId) async {
    await _client.from('payment_methods').delete().eq('id', paymentMethodId);
  }
}
