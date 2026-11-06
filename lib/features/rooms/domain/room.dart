class Room {
  const Room({
    required this.id,
    required this.title,
    required this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.price,
    required this.area,
    required this.totalRooms,
    required this.availableRooms,
    required this.electricityPrice,
    required this.waterPrice,
    required this.internetPrice,
    required this.deposit,
    required this.status,
    this.image,
    this.distance,
    this.amenities = const [],
    this.images = const [],
    this.landlordId,
    this.landlordName,
    this.landlordAvatar,
    this.landlordPhone,
    this.isFavorite = false,
  });

  final String id;
  final String title;
  final String description;
  final String address;
  final double? latitude;
  final double? longitude;
  final double price;
  final double area;
  final int totalRooms;
  final int availableRooms;
  final double electricityPrice;
  final double waterPrice;
  final double internetPrice;
  final double deposit;
  final String status;
  final String? image;
  final double? distance;
  final List<String> amenities;
  final List<String> images;
  final String? landlordId;
  final String? landlordName;
  final String? landlordAvatar;
  final String? landlordPhone;
  final bool isFavorite;

  factory Room.fromJson(Map<String, dynamic> json) {
    final landlord = json['landlord'];
    final rawImages = json['images'];
    final imageList = rawImages is List
        ? rawImages
              .whereType<Map<String, dynamic>>()
              .map((image) => image['imageUrl'] as String)
              .toList()
        : <String>[];
    return Room(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      address: json['address'] as String,
      latitude: _nullableDouble(json['latitude']),
      longitude: _nullableDouble(json['longitude']),
      price: _double(json['price']),
      area: _double(json['area']),
      totalRooms: (json['totalRooms'] as num).toInt(),
      availableRooms: (json['availableRooms'] as num).toInt(),
      electricityPrice: _double(json['electricityPrice']),
      waterPrice: _double(json['waterPrice']),
      internetPrice: _double(json['internetPrice']),
      deposit: _double(json['deposit']),
      status: json['status'] as String? ?? 'AVAILABLE',
      image:
          json['image'] as String? ??
          (imageList.isEmpty ? null : imageList.first),
      distance: json['distance'] == null ? null : _double(json['distance']),
      amenities: (json['amenities'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      images: imageList,
      landlordId: landlord is Map<String, dynamic>
          ? landlord['id'] as String?
          : null,
      landlordName: landlord is Map<String, dynamic>
          ? landlord['fullName'] as String?
          : null,
      landlordAvatar: landlord is Map<String, dynamic>
          ? landlord['avatarUrl'] as String?
          : null,
      landlordPhone: landlord is Map<String, dynamic>
          ? landlord['phone'] as String?
          : null,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  static double _double(Object? value) => (value as num).toDouble();

  static double? _nullableDouble(Object? value) =>
      value == null ? null : _double(value);
}
