import 'package:app/core/models/venue.dart';

class Itinerary {
  const Itinerary({
    required this.destination,
    required this.durationDays,
    required this.days,
    required this.costSummary,
    required this.generatedAt,
    this.isDegraded = false,
    this.degradationReason,
  });

  final String destination;
  final int durationDays;
  final List<DayPlan> days;
  final CostSummary costSummary;
  final String generatedAt;

  /// Whether the itinerary was generated in degraded mode
  /// (Tavily unavailable, venues are AI-suggested and unverified).
  final bool isDegraded;

  /// The reason for degradation, e.g. "tavily_unavailable", or null if not degraded.
  final String? degradationReason;

  factory Itinerary.fromJson(Map<String, Object?> json) {
    return Itinerary(
      destination: (json['destination'] as String?) ?? '',
      durationDays: _asInt(json['duration_days']) ?? 0,
      days: (json['days'] as List<Object?>? ?? const <Object?>[])
          .whereType<Map<String, Object?>>()
          .map(DayPlan.fromJson)
          .toList(growable: false),
      costSummary: CostSummary.fromJson(
        (json['cost_summary'] as Map<Object?, Object?>?)
                ?.cast<String, Object?>() ??
            <String, Object?>{},
      ),
      generatedAt: (json['generated_at'] as String?) ?? '',
      isDegraded: (json['degraded'] as bool?) ?? false,
      degradationReason: json['degradation_reason'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    final map = <String, Object?>{
      'destination': destination,
      'duration_days': durationDays,
      'days': days.map((day) => day.toJson()).toList(growable: false),
      'cost_summary': costSummary.toJson(),
      'generated_at': generatedAt,
    };
    if (isDegraded) {
      map['degraded'] = isDegraded;
    }
    if (degradationReason != null) {
      map['degradation_reason'] = degradationReason;
    }
    return map;
  }

  Itinerary copyWith({
    String? destination,
    int? durationDays,
    List<DayPlan>? days,
    CostSummary? costSummary,
    String? generatedAt,
    bool? isDegraded,
    String? degradationReason,
  }) {
    return Itinerary(
      destination: destination ?? this.destination,
      durationDays: durationDays ?? this.durationDays,
      days: days ?? this.days,
      costSummary: costSummary ?? this.costSummary,
      generatedAt: generatedAt ?? this.generatedAt,
      isDegraded: isDegraded ?? this.isDegraded,
      degradationReason: degradationReason ?? this.degradationReason,
    );
  }
}

class DayPlan {
  const DayPlan({
    required this.dayNumber,
    this.date,
    required this.venues,
    this.estimatedDayCost,
  });

  final int dayNumber;
  final String? date;
  final List<Venue> venues;
  final double? estimatedDayCost;

  factory DayPlan.fromJson(Map<String, Object?> json) {
    return DayPlan(
      dayNumber: _asInt(json['day_number']) ?? 0,
      date: json['date'] as String?,
      venues: (json['venues'] as List<Object?>? ?? const <Object?>[])
          .whereType<Map<String, Object?>>()
          .map(Venue.fromJson)
          .toList(growable: false),
      estimatedDayCost: _asDouble(json['estimated_day_cost']),
    );
  }

  Map<String, Object?> toJson() {
    final map = <String, Object?>{
      'day_number': dayNumber,
      'venues': venues.map((venue) => venue.toJson()).toList(growable: false),
    };
    if (date != null) {
      map['date'] = date;
    }
    if (estimatedDayCost != null) {
      map['estimated_day_cost'] = estimatedDayCost;
    }
    return map;
  }

  DayPlan copyWith({
    int? dayNumber,
    String? date,
    List<Venue>? venues,
    double? estimatedDayCost,
  }) {
    return DayPlan(
      dayNumber: dayNumber ?? this.dayNumber,
      date: date ?? this.date,
      venues: venues ?? this.venues,
      estimatedDayCost: estimatedDayCost ?? this.estimatedDayCost,
    );
  }
}

class CostSummary {
  const CostSummary({
    this.food,
    this.entertainment,
    this.transport,
    required this.total,
  });

  final double? food;
  final double? entertainment;
  final double? transport;
  final double total;

  factory CostSummary.fromJson(Map<String, Object?> json) {
    return CostSummary(
      food: _asDouble(json['food']),
      entertainment: _asDouble(json['entertainment']),
      transport: _asDouble(json['transport']),
      total: _asDouble(json['total']) ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    final map = <String, Object?>{'total': total};
    if (food != null) {
      map['food'] = food;
    }
    if (entertainment != null) {
      map['entertainment'] = entertainment;
    }
    if (transport != null) {
      map['transport'] = transport;
    }
    return map;
  }

  CostSummary copyWith({
    double? food,
    double? entertainment,
    double? transport,
    double? total,
  }) {
    return CostSummary(
      food: food ?? this.food,
      entertainment: entertainment ?? this.entertainment,
      transport: transport ?? this.transport,
      total: total ?? this.total,
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
