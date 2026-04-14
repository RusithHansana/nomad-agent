import 'package:flutter/material.dart';

/// Placeholder screen for viewing a single itinerary.
class ItineraryScreen extends StatelessWidget {
  const ItineraryScreen({super.key, required this.id});

  /// The itinerary identifier passed via the `:id` route parameter.
  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Itinerary $id')),
      body: Center(child: Text('Itinerary Screen — id: $id')),
    );
  }
}
