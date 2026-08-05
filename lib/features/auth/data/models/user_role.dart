/// Maps 1:1 to the `role` enum on the `users` table (ERD.md).
enum UserRole { customer, owner }

extension UserRoleX on UserRole {
  String toDb() => this == UserRole.owner ? 'owner' : 'customer';

  static UserRole fromDb(String value) =>
      value == 'owner' ? UserRole.owner : UserRole.customer;
}
