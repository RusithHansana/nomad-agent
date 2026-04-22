import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/sse_event.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/sse_parser.dart';
import '../../itinerary/providers/itinerary_store_provider.dart';

typedef GenerationStreamFactory =
    Stream<SSEEvent> Function(String prompt, CancelToken cancelToken);

enum GenerationPhase { streaming, complete, error }

class ThoughtLogEntry {
  const ThoughtLogEntry({
    required this.id,
    required this.icon,
    required this.message,
    required this.timestamp,
  });

  final String id;
  final String icon;
  final String message;
  final String timestamp;
}

    required this.elapsedSeconds,
    required this.errorMessage,
    required this.itineraryId,
    required this.hasAttemptedReconnect,
    this.currentStep,
  });

  factory GenerationViewState.initial({required String destinationDisplay}) {
    return GenerationViewState(
      destinationDisplay: destinationDisplay,
      entries: const <ThoughtLogEntry>[],
      phase: GenerationPhase.streaming,
      firstEventReceived: false,
      showColdStartOverlay: false,
      elapsedSeconds: 0,
      errorMessage: null,
      itineraryId: null,
      hasAttemptedReconnect: false,
      currentStep: null,
    );
  }

  final String destinationDisplay;
  final List<ThoughtLogEntry> entries;
  final GenerationPhase phase;
  final bool firstEventReceived;
  final bool showColdStartOverlay;
  final int elapsedSeconds;
  final String? errorMessage;
  final String? itineraryId;
  final bool hasAttemptedReconnect;
  final String? currentStep;

  bool get isStreaming => phase == GenerationPhase.streaming;

  static const Object _noChange = Object();

    Object? errorMessage = _noChange,
    String? itineraryId,
    bool? hasAttemptedReconnect,
    String? currentStep,
  }) {
    return GenerationViewState(
      destinationDisplay: destinationDisplay ?? this.destinationDisplay,
      entries: entries ?? this.entries,
      phase: phase ?? this.phase,
      firstEventReceived: firstEventReceived ?? this.firstEventReceived,
      showColdStartOverlay: showColdStartOverlay ?? this.showColdStartOverlay,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      errorMessage: identical(errorMessage, _noChange)
          ? this.errorMessage
          : errorMessage as String?,
      itineraryId: itineraryId ?? this.itineraryId,
      hasAttemptedReconnect:
          hasAttemptedReconnect ?? this.hasAttemptedReconnect,
      currentStep: currentStep ?? this.currentStep,
    );
  }
}

final dioProvider = Provider<Dio>((ref) => ApiClient.instance);

final generationStreamProvider = StreamProvider.family
    .autoDispose<SSEEvent, String>((ref, prompt) {
      final dio = ref.watch(dioProvider);
      final cancelToken = CancelToken();
      ref.onDispose(cancelToken.cancel);

      return openGenerationStream(
        dio: dio,
        prompt: prompt,
        cancelToken: cancelToken,
      );
    });

Stream<SSEEvent> openGenerationStream({
  required Dio dio,
  required String prompt,
  CancelToken? cancelToken,
}) async* {
  try {
    final response = await dio.post<ResponseBody>(
      '/api/v1/generate',
      data: <String, Object?>{'prompt': prompt},
      options: Options(responseType: ResponseType.stream),
      cancelToken: cancelToken,
    );

    final responseBody = response.data;
    if (responseBody == null) {
      throw StateError('Generation stream returned an empty body.');
    }

    await for (final message in parseSseMessages(responseBody.stream)) {
      final Map<String, Object?> decoded;
      try {
        final rawDecoded = jsonDecode(message);
        if (rawDecoded is! Map<String, Object?>) {
          continue;
        }
        decoded = rawDecoded;
      } on FormatException {
        continue;
      }
      yield SSEEvent.fromJson(decoded);
    }
  } on DioException catch (error) {
    if (CancelToken.isCancel(error)) {
      return;
    }
    rethrow;
  }
}

final generationStreamFactoryProvider = Provider<GenerationStreamFactory>((
  ref,
) {
  final dio = ref.watch(dioProvider);
  return (prompt, cancelToken) =>
      openGenerationStream(dio: dio, prompt: prompt, cancelToken: cancelToken);
});

final generationControllerProvider =
    AutoDisposeNotifierProviderFamily<
      GenerationController,
      GenerationViewState,
      String
    >(GenerationController.new);

class GenerationController
    extends AutoDisposeFamilyNotifier<GenerationViewState, String> {
  StreamSubscription<SSEEvent>? _subscription;
  Timer? _elapsedTimer;
  Timer? _coldStartTimer;
  CancelToken? _cancelToken;

  bool _isTerminal = false;
  bool _dropHandledForCurrentSubscription = false;

  @override
  GenerationViewState build(String prompt) {
    final initial = GenerationViewState.initial(
      destinationDisplay: deriveDestination(prompt),
    );

    Future<void>.microtask(_start);

    ref.onDispose(() {
      _cancelToken?.cancel();
      _subscription?.cancel();
      _elapsedTimer?.cancel();
      _coldStartTimer?.cancel();
    });

    return initial;
  }

  void retry() {
    _cancelToken?.cancel();
    _subscription?.cancel();
    _elapsedTimer?.cancel();
    _coldStartTimer?.cancel();

    _isTerminal = false;
    state = GenerationViewState.initial(
      destinationDisplay: deriveDestination(arg),
    );

    _start();
  }

  void _start() {
    _startTimers();
    _subscribeToStream();
  }

  void _startTimers() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isTerminal) {
        return;
      }
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });

    _coldStartTimer?.cancel();
    _coldStartTimer = Timer(const Duration(seconds: 3), () {
      if (_isTerminal || state.firstEventReceived) {
        return;
      }
      state = state.copyWith(showColdStartOverlay: true);
    });
  }

  void _subscribeToStream() {
    _cancelToken?.cancel();
    _subscription?.cancel();
    _cancelToken = CancelToken();
    _dropHandledForCurrentSubscription = false;

    final streamFactory = ref.read(generationStreamFactoryProvider);
    final stream = streamFactory(arg, _cancelToken!);

    _subscription = stream.listen(
      _handleEvent,
      onError: (Object error, StackTrace stackTrace) {
        if (_dropHandledForCurrentSubscription) {
          return;
        }
        _dropHandledForCurrentSubscription = true;
        _handleDroppedStream();
      },
      onDone: () {
        if (_dropHandledForCurrentSubscription) {
          return;
        }
        _dropHandledForCurrentSubscription = true;
        _handleDroppedStream();
      },
      cancelOnError: false,
    );
  }

  void _handleEvent(SSEEvent event) {
    if (!state.firstEventReceived) {
      state = state.copyWith(
        firstEventReceived: true,
        showColdStartOverlay: false,
      );
    }

    if (event is ThoughtLogEvent) {
      _appendEntry(
        icon: event.icon ?? '🔍',
        message: event.message,
        timestamp: event.timestamp,
      );
      if (event.step != null) {
        state = state.copyWith(currentStep: event.step);
      }
      return;
    }

    if (event is SelfCorrectionEvent) {
      _appendEntry(
        icon: '🔄',
        message: 'Broadened query: ${event.broadenedQuery}',
        timestamp: event.timestamp,
      );
      return;
    }

    if (event is VenueVerifiedEvent) {
      _appendEntry(
        icon: '✅',
        message: 'Verified: ${event.venue.name}',
        timestamp: event.timestamp,
      );
      return;
    }

    if (event is ItineraryCompleteEvent) {
      _appendEntry(
        icon: '🎉',
        message: '✅ Itinerary complete!',
        timestamp: event.timestamp,
      );
      ref.read(itineraryStoreProvider.notifier).upsert(event.itinerary);
      _isTerminal = true;
      _elapsedTimer?.cancel();
      _coldStartTimer?.cancel();
      _cancelActiveStream();
      state = state.copyWith(
        phase: GenerationPhase.complete,
        itineraryId: _buildItineraryId(event),
      );
      return;
    }

    if (event is ErrorEvent) {
      _appendEntry(
        icon: '❌',
        message: event.message,
        timestamp: event.timestamp,
      );
      _isTerminal = true;
      _elapsedTimer?.cancel();
      _coldStartTimer?.cancel();
      _cancelActiveStream();
      state = state.copyWith(
        phase: GenerationPhase.error,
        errorMessage: event.message,
      );
      return;
    }
  }

  void _handleDroppedStream() {
    if (_isTerminal) {
      return;
    }

    if (!state.hasAttemptedReconnect) {
      state = state.copyWith(hasAttemptedReconnect: true);
      _subscribeToStream();
      return;
    }

    _isTerminal = true;
    _elapsedTimer?.cancel();
    _coldStartTimer?.cancel();
    _cancelActiveStream();
    state = state.copyWith(
      phase: GenerationPhase.error,
      errorMessage:
          'Connection lost while generating your itinerary. Please try again.',
      showColdStartOverlay: false,
    );
  }

  void _cancelActiveStream() {
    _cancelToken?.cancel();
    _subscription?.cancel();
    _cancelToken = null;
    _subscription = null;
  }

  void _appendEntry({
    required String icon,
    required String message,
    required String timestamp,
  }) {
    final entry = ThoughtLogEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}_${state.entries.length}',
      icon: icon,
      message: message,
      timestamp: timestamp,
    );

    state = state.copyWith(entries: <ThoughtLogEntry>[...state.entries, entry]);
  }

  String _buildItineraryId(ItineraryCompleteEvent event) {
    final generatedAt = event.itinerary.generatedAt;
    if (generatedAt.isNotEmpty) {
      return generatedAt;
    }
    return DateTime.now().toIso8601String();
  }
}

String deriveDestination(String prompt) {
  final normalized = prompt.trim();
  if (normalized.isEmpty) {
    return 'your destination';
  }

  final inMatch = RegExp(
    r'\bin\s+([A-Za-z][A-Za-z\s\-]{1,40})',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (inMatch != null) {
    return inMatch.group(1)!.trim();
  }

  final toMatch = RegExp(
    r'\bto\s+([A-Za-z][A-Za-z\s\-]{1,40})',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (toMatch != null) {
    return toMatch.group(1)!.trim();
  }

  final commas = normalized.split(',');
  if (commas.isNotEmpty) {
    final firstPart = commas.first.trim();
    if (firstPart.isNotEmpty) {
      return firstPart;
    }
  }

  return 'your destination';
}
