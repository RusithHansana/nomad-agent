import 'package:app/core/models/itinerary.dart';
import 'package:app/core/models/venue.dart';

sealed class SSEEvent {
  const SSEEvent({required this.eventType, required this.timestamp});

  final String eventType;
  final String timestamp;

  factory SSEEvent.fromJson(Map<String, Object?> json) {
    final eventType = (json['event_type'] as String?) ?? '';
    final timestamp = (json['timestamp'] as String?) ?? '';
    final data =
        (json['data'] as Map<Object?, Object?>?)?.cast<String, Object?>() ??
        <String, Object?>{};

    switch (eventType) {
      case 'thought_log':
        return ThoughtLogEvent(
          timestamp: timestamp,
          message: (data['message'] as String?) ?? '',
          icon: data['icon'] as String?,
          step: data['step'] as String?,
        );
      case 'venue_verified':
        return VenueVerifiedEvent(
          timestamp: timestamp,
          venue: Venue.fromJson(
            (data['venue'] as Map<Object?, Object?>?)
                    ?.cast<String, Object?>() ??
                <String, Object?>{},
          ),
        );
      case 'self_correction':
        return SelfCorrectionEvent(
          timestamp: timestamp,
          originalQuery: (data['original_query'] as String?) ?? '',
          broadenedQuery: (data['broadened_query'] as String?) ?? '',
          reason: data['reason'] as String?,
        );
      case 'itinerary_complete':
        return ItineraryCompleteEvent(
          timestamp: timestamp,
          itinerary: Itinerary.fromJson(
            (data['itinerary'] as Map<Object?, Object?>?)
                    ?.cast<String, Object?>() ??
                <String, Object?>{},
          ),
        );
      case 'error':
        return ErrorEvent(
          timestamp: timestamp,
          code: (data['code'] as String?) ?? '',
          message: (data['message'] as String?) ?? '',
          details:
              (data['details'] as Map<Object?, Object?>?)
                  ?.cast<String, Object?>() ??
              <String, Object?>{},
        );
      default:
        return UnknownSSEEvent(
          eventType: eventType,
          timestamp: timestamp,
          data: data,
        );
    }
  }

  Map<String, Object?> toJson();
}

class ThoughtLogEvent extends SSEEvent {
  const ThoughtLogEvent({
    required super.timestamp,
    required this.message,
    this.icon,
    this.step,
  }) : super(eventType: 'thought_log');

  final String message;
  final String? icon;
  final String? step;

  @override
  Map<String, Object?> toJson() {
    final data = <String, Object?>{'message': message};
    if (icon != null) {
      data['icon'] = icon;
    }
    if (step != null) {
      data['step'] = step;
    }
    return <String, Object?>{
      'event_type': eventType,
      'timestamp': timestamp,
      'data': data,
    };
  }

  ThoughtLogEvent copyWith({
    String? timestamp,
    String? message,
    String? icon,
    String? step,
  }) {
    return ThoughtLogEvent(
      timestamp: timestamp ?? this.timestamp,
      message: message ?? this.message,
      icon: icon ?? this.icon,
      step: step ?? this.step,
    );
  }
}

class VenueVerifiedEvent extends SSEEvent {
  const VenueVerifiedEvent({required super.timestamp, required this.venue})
    : super(eventType: 'venue_verified');

  final Venue venue;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'event_type': eventType,
      'timestamp': timestamp,
      'data': <String, Object?>{'venue': venue.toJson()},
    };
  }

  VenueVerifiedEvent copyWith({String? timestamp, Venue? venue}) {
    return VenueVerifiedEvent(
      timestamp: timestamp ?? this.timestamp,
      venue: venue ?? this.venue,
    );
  }
}

class SelfCorrectionEvent extends SSEEvent {
  const SelfCorrectionEvent({
    required super.timestamp,
    required this.originalQuery,
    required this.broadenedQuery,
    this.reason,
  }) : super(eventType: 'self_correction');

  final String originalQuery;
  final String broadenedQuery;
  final String? reason;

  @override
  Map<String, Object?> toJson() {
    final data = <String, Object?>{
      'original_query': originalQuery,
      'broadened_query': broadenedQuery,
    };
    if (reason != null) {
      data['reason'] = reason;
    }
    return <String, Object?>{
      'event_type': eventType,
      'timestamp': timestamp,
      'data': data,
    };
  }

  SelfCorrectionEvent copyWith({
    String? timestamp,
    String? originalQuery,
    String? broadenedQuery,
    String? reason,
  }) {
    return SelfCorrectionEvent(
      timestamp: timestamp ?? this.timestamp,
      originalQuery: originalQuery ?? this.originalQuery,
      broadenedQuery: broadenedQuery ?? this.broadenedQuery,
      reason: reason ?? this.reason,
    );
  }
}

class ItineraryCompleteEvent extends SSEEvent {
  const ItineraryCompleteEvent({
    required super.timestamp,
    required this.itinerary,
  }) : super(eventType: 'itinerary_complete');

  final Itinerary itinerary;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'event_type': eventType,
      'timestamp': timestamp,
      'data': <String, Object?>{'itinerary': itinerary.toJson()},
    };
  }

  ItineraryCompleteEvent copyWith({String? timestamp, Itinerary? itinerary}) {
    return ItineraryCompleteEvent(
      timestamp: timestamp ?? this.timestamp,
      itinerary: itinerary ?? this.itinerary,
    );
  }
}

class ErrorEvent extends SSEEvent {
  const ErrorEvent({
    required super.timestamp,
    required this.code,
    required this.message,
    required this.details,
  }) : super(eventType: 'error');

  final String code;
  final String message;
  final Map<String, Object?> details;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'event_type': eventType,
      'timestamp': timestamp,
      'data': <String, Object?>{
        'code': code,
        'message': message,
        'details': details,
      },
    };
  }

  ErrorEvent copyWith({
    String? timestamp,
    String? code,
    String? message,
    Map<String, Object?>? details,
  }) {
    return ErrorEvent(
      timestamp: timestamp ?? this.timestamp,
      code: code ?? this.code,
      message: message ?? this.message,
      details: details ?? this.details,
    );
  }
}

class UnknownSSEEvent extends SSEEvent {
  const UnknownSSEEvent({
    required super.eventType,
    required super.timestamp,
    required this.data,
  });

  final Map<String, Object?> data;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'event_type': eventType,
      'timestamp': timestamp,
      'data': data,
    };
  }

  UnknownSSEEvent copyWith({
    String? eventType,
    String? timestamp,
    Map<String, Object?>? data,
  }) {
    return UnknownSSEEvent(
      eventType: eventType ?? this.eventType,
      timestamp: timestamp ?? this.timestamp,
      data: data ?? this.data,
    );
  }
}
