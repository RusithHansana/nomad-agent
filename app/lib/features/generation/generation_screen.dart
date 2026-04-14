import 'package:flutter/material.dart';

/// Placeholder screen shown while the AI agent is generating an itinerary.
class GenerationScreen extends StatelessWidget {
  const GenerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generating…')),
      body: const Center(child: Text('Generation Screen')),
    );
  }
}
