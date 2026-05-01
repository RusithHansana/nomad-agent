class CachedItinerarySummary {
  const CachedItinerarySummary({
    required this.id,
    required this.destination,
    required this.durationDays,
    required this.generatedAt,
    required this.venueCount,
  });

  final String id;
  final String destination;
  final int durationDays;
  final String generatedAt;
  final int venueCount;
}
