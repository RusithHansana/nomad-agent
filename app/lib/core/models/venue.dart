class Venue {
  const Venue({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.openingHours,
    this.rating,
    this.priceLevel,
    this.estimatedCost,
    this.sourceUrl,
    required this.isVerified,
    this.verificationNote,
  });

  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final List<String>? openingHours;
  final double? rating;
  final int? priceLevel;
  final double? estimatedCost;
  final String? sourceUrl;
  final bool isVerified;
  final String? verificationNote;

  factory Venue.fromJson(Map<String, Object?> json) {
    return Venue(
      name: (json['name'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      latitude: _asDouble(json['latitude']) ?? 0,
      longitude: _asDouble(json['longitude']) ?? 0,
      openingHours: (json['opening_hours'] as List<Object?>?)
          ?.whereType<String>()
          .toList(growable: false),
      rating: _asDouble(json['rating']),
      priceLevel: _asInt(json['price_level']),
      estimatedCost: _asDouble(json['estimated_cost']),
      sourceUrl: json['source_url'] as String?,
      isVerified: (json['is_verified'] as bool?) ?? false,
      verificationNote: json['verification_note'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    final map = <String, Object?>{
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'is_verified': isVerified,
    };
    if (openingHours != null) {
      map['opening_hours'] = openingHours;
    }
    if (rating != null) {
      map['rating'] = rating;
    }
    if (priceLevel != null) {
      map['price_level'] = priceLevel;
    }
    if (estimatedCost != null) {
      map['estimated_cost'] = estimatedCost;
    }
    if (sourceUrl != null) {
      map['source_url'] = sourceUrl;
    }
    if (verificationNote != null) {
      map['verification_note'] = verificationNote;
    }
    return map;
  }

  Venue copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    List<String>? openingHours,
    double? rating,
    int? priceLevel,
    double? estimatedCost,
    String? sourceUrl,
    bool? isVerified,
    String? verificationNote,
  }) {
    return Venue(
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      openingHours: openingHours ?? this.openingHours,
      rating: rating ?? this.rating,
      priceLevel: priceLevel ?? this.priceLevel,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      isVerified: isVerified ?? this.isVerified,
      verificationNote: verificationNote ?? this.verificationNote,
    );
  }
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    final asDouble = value.toDouble();
    if (asDouble % 1 != 0) {
      return null;
    }
    return asDouble.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
