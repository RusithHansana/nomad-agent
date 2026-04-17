import 'dart:convert';

/// Parses an SSE byte stream and yields message payload strings from `data:`.
///
/// Handles chunk boundaries, blank-line message delimiters, and multi-line
/// data fields concatenated with newlines.
Stream<String> parseSseMessages(
  Stream<List<int>> byteStream, {
  int maxBufferedChars = 64 * 1024,
}) async* {
  final dataLines = <String>[];
  var bufferedChars = 0;

  void resetMessage() {
    dataLines.clear();
    bufferedChars = 0;
  }

  String? buildMessage() {
    if (dataLines.isEmpty) {
      return null;
    }
    final message = dataLines.join('\n');
    return message.trim().isEmpty ? null : message;
  }

  await for (final line
      in utf8.decoder.bind(byteStream).transform(const LineSplitter())) {
    if (line.isEmpty) {
      final message = buildMessage();
      if (message != null) {
        yield message;
      }
      resetMessage();
      continue;
    }

    if (line.startsWith(':')) {
      continue;
    }

    if (line.startsWith('data:')) {
      final payload = line.substring(5).trimLeft();
      bufferedChars += payload.length;
      if (bufferedChars > maxBufferedChars) {
        throw StateError(
          'SSE message exceeded maxBufferedChars ($maxBufferedChars).',
        );
      }
      dataLines.add(payload);
    }
  }

  final trailingMessage = buildMessage();
  if (trailingMessage != null) {
    yield trailingMessage;
  }
}
