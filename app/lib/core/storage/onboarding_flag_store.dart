import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

const _flagKey = 'has_seen_thought_log_onboarding';

abstract class OnboardingFlagStore {
  Future<bool> getHasSeenThoughtLogOnboarding();
  Future<void> setHasSeenThoughtLogOnboarding();
}

typedef DocumentsDirectoryLoader = Future<Directory> Function();

final onboardingFlagStoreProvider = Provider<OnboardingFlagStore>((ref) {
  return FileOnboardingFlagStore();
});

class FileOnboardingFlagStore implements OnboardingFlagStore {
  FileOnboardingFlagStore({
    DocumentsDirectoryLoader? loadDocumentsDirectory,
    String fileName = 'nomad_flags.json',
  }) : _loadDocumentsDirectory =
           loadDocumentsDirectory ?? getApplicationDocumentsDirectory,
       _fileName = fileName;

  final DocumentsDirectoryLoader _loadDocumentsDirectory;
  final String _fileName;

  @override
  Future<bool> getHasSeenThoughtLogOnboarding() async {
    final file = await _resolveFile();
    if (!await file.exists()) {
      return false;
    }

    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return false;
      }
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }
      final value = decoded[_flagKey];
      return value is bool ? value : false;
    } on FileSystemException {
      return false;
    } on FormatException {
      return false;
    }
  }

  @override
  Future<void> setHasSeenThoughtLogOnboarding() async {
    final file = await _resolveFile();
    final payload = <String, Object>{_flagKey: true};
    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  Future<File> _resolveFile() async {
    final directory = await _loadDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }
}
