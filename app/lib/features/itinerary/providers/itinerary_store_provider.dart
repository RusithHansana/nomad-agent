import 'package:app/core/models/itinerary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final itineraryStoreProvider =
    NotifierProvider<ItineraryStoreNotifier, Map<String, Itinerary>>(
      ItineraryStoreNotifier.new,
    );

class ItineraryStoreNotifier extends Notifier<Map<String, Itinerary>> {
  @override
  Map<String, Itinerary> build() {
    return <String, Itinerary>{};
  }

  void upsert(Itinerary itinerary) {
    final key = itinerary.generatedAt;
    if (key.isEmpty) {
      return;
    }
    state = <String, Itinerary>{...state, key: itinerary};
  }

  Itinerary? getById(String id) {
    return state[id];
  }
}

typedef SourceUrlLauncher = Future<bool> Function(String sourceUrl);

final sourceUrlLauncherProvider = Provider<SourceUrlLauncher>((ref) {
  return (String sourceUrl) async {
    final trimmed = sourceUrl.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return false;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return false;
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  };
});
