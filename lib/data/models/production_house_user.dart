class ProductionHouseUser {
  final String id;
  final String email;
  final String companyName;
  final bool isVerified;

  const ProductionHouseUser({
    required this.id,
    required this.email,
    required this.companyName,
    required this.isVerified,
  });

  factory ProductionHouseUser.fromJson(Map<String, dynamic> json) {
    return ProductionHouseUser(
      id: json['id'] as String,
      email: json['email'] as String,
      companyName: json['company_name'] as String,
      isVerified: json['is_verified'] as bool,
    );
  }
}