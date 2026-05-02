import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/features/settings/providers/theme_provider.dart';
import 'package:app/core/storage/itinerary_cache.dart';

/// Settings screen providing Dark Mode toggle, About info, and Clear History.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showClearHistoryDialog(BuildContext context, WidgetRef ref) async {
    // Capture cache reference before the async gap to avoid using ref after
    // the widget may have been unmounted.
    final cache = ref.read(itineraryCacheProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text(
          'This will permanently delete all saved itineraries. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await cache.clearAll();
      if (context.mounted) {
        ref.invalidate(cachedItinerariesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('History cleared'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            subtitle: const Text('Toggle between light and dark themes'),
            value: themeMode == ThemeMode.dark,
            onChanged: (value) {
              ref.read(themeModeProvider.notifier).setMode(
                value ? ThemeMode.dark : ThemeMode.light,
              );
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('App version'),
            subtitle: Text('0.1.0'),
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Credits'),
            subtitle: Text('Built with Flutter & AI'),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Clear History',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('Delete all saved itineraries'),
            onTap: () => _showClearHistoryDialog(context, ref),
          ),
        ],
      ),
    );
  }
}
