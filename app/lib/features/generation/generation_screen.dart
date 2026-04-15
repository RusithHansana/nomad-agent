import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';

/// Placeholder screen shown while the AI agent is generating an itinerary.
class GenerationScreen extends StatelessWidget {
  const GenerationScreen({required this.prompt, super.key});

  final String prompt;

  @override
  Widget build(BuildContext context) {
    final hasPrompt = prompt.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Generating…')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            hasPrompt
                ? 'Prompt: $prompt'
                : 'No prompt received yet. Start from Home to generate your trip.',
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
