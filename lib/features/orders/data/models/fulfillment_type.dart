/// Maps to orders.fulfillment_type enum('pickup','delivery') — ERD.md §2.
enum FulfillmentType { pickup, delivery }

extension FulfillmentTypeX on FulfillmentType {
  String toDb() => name;

  static FulfillmentType fromDb(String value) {
    return value == 'delivery'
        ? FulfillmentType.delivery
        : FulfillmentType.pickup;
  }
}
