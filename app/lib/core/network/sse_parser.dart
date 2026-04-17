import 'dart:convert';

/// Parses an SSE byte stream and yields message payload strings from `data:`.
///
/// Handles chunk boundaries, blank-line message delimiters, and multi-line
/// data fields concatenated with newlines.
Stream<String> parseSseMessages(Stream<List<int>> byteStream) async* {
  final decoder = utf8.decoder;
  var buffer = '';

  await for (final chunk in byteStream) {
    buffer += decoder.convert(chunk);

    var separatorIndex = buffer.indexOf('\n\n');
    while (separatorIndex != -1) {
      final rawMessage = buffer
          .substring(0, separatorIndex)
          .replaceAll('\r', '');
      buffer = buffer.substring(separatorIndex + 2);

      final dataLines = <String>[];
      for (final line in const LineSplitter().convert(rawMessage)) {
        if (line.startsWith(':')) {
          continue;
        }
        if (line.startsWith('data:')) {
          dataLines.add(line.substring(5).trimLeft());
        }
      }

      final message = dataLines.join('\n');
      if (message.trim().isNotEmpty) {
        yield message;
      }

      separatorIndex = buffer.indexOf('\n\n');
    }
  }

  if (buffer.trim().isNotEmpty) {
    final rawMessage = buffer.replaceAll('\r', '');
    final dataLines = <String>[];
    for (final line in const LineSplitter().convert(rawMessage)) {
      if (line.startsWith(':')) {
        continue;
      }
      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }

    final message = dataLines.join('\n');
    if (message.trim().isNotEmpty) {
      yield message;
    }
  }
}
