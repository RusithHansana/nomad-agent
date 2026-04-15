import 'package:flutter/material.dart';

/// Placeholder screen shown while the AI agent is generating an itinerary.
class GenerationScreen extends StatelessWidget {
  const GenerationScreen({
    required this.prompt,
    super.key,
  });

  final String prompt;

  @override
  Widget build(BuildContext context) {
    final hasPrompt = prompt.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Generating…')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            hasPrompt
                ? 'Prompt: $prompt'
                : 'No prompt received yet. Start from Home to generate your trip.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
