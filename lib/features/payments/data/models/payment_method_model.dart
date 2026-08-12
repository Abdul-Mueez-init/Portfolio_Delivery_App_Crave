/// Card brand detected from the leading digits of a (simulated, never
/// transmitted) card number — same detection ranges Stripe/most
/// processors use. `unknown` is the honest fallback for anything that
/// doesn't match, rather than guessing.
enum CardBrand { visa, mastercard, amex, unknown }

extension CardBrandX on CardBrand {
  String toDb() => name;

  static CardBrand fromDb(String value) {
    return CardBrand.values.firstWhere(
      (b) => b.name == value,
      orElse: () => CardBrand.unknown,
    );
  }

  String get displayName {
    switch (this) {
      case CardBrand.visa:
        return 'Visa';
      case CardBrand.mastercard:
        return 'Mastercard';
      case CardBrand.amex:
        return 'American Express';
      case CardBrand.unknown:
        return 'Card';
    }
  }

  /// Detects brand from a card number's leading digits. Digits-only
  /// input expected (strip spaces before calling). This app's payment
  /// is permanently simulated (rules.md / architecture.md) — this
  /// exists purely so the saved-card UI can show a recognizable brand
  /// mark for a fake number like Stripe's own test cards (4242… ->
  /// Visa), not to validate a real card.
  static CardBrand detect(String digitsOnly) {
    if (digitsOnly.isEmpty) return CardBrand.unknown;
    if (digitsOnly.startsWith('4')) return CardBrand.visa;
    if (RegExp(r'^5[1-5]').hasMatch(digitsOnly) ||
        RegExp(r'^2(2[2-9]|[3-6]\d|7[01]|720)').hasMatch(digitsOnly)) {
      return CardBrand.mastercard;
    }
    if (RegExp(r'^3[47]').hasMatch(digitsOnly)) return CardBrand.amex;
    return CardBrand.unknown;
  }
}

/// Maps 1:1 to the `payment_methods` table added by
/// `supabase/fix_booking_rpcs_saved_addresses_payment_methods.sql`.
///
/// Deliberately stores nothing sensitive — no full card number, no
/// CVV, ever (see the SQL migration's table comment). Only what a
/// real payment processor's tokenized "saved card" API would actually
/// hand back to render a picker: brand, last 4 digits, expiry.
class PaymentMethodModel {
  const PaymentMethodModel({
    required this.id,
    required this.userId,
    required this.brand,
    required this.last4,
    required this.isDefault,
    required this.createdAt,
    this.expiryMonth,
    this.expiryYear,
  });

  final String id;
  final String userId;
  final CardBrand brand;
  final String last4;
  final int? expiryMonth;
  final int? expiryYear;
  final bool isDefault;
  final DateTime createdAt;

  String get maskedLabel => '•••• $last4';

  factory PaymentMethodModel.fromMap(Map<String, dynamic> map) {
    return PaymentMethodModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      brand: CardBrandX.fromDb(map['brand'] as String),
      last4: map['last4'] as String,
      expiryMonth: map['expiry_month'] as int?,
      expiryYear: map['expiry_year'] as int?,
      isDefault: map['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
