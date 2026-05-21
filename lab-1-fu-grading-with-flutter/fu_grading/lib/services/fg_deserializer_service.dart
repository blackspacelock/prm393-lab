import 'dart:io';

import 'package:flutter/foundation.dart';

/// Runs the bundled C# deserializer and returns its JSON output.
class FgDeserializerService {
  static Future<String> deserializeToJson(String filePath) async {
    if (kIsWeb) {
      throw UnsupportedError('C# deserializer is not available on web.');
    }

    final executablePath = _findExecutablePath();
    if (executablePath == null) {
      throw Exception(
        'Unable to locate DeserializeFGFile.exe in the workspace',
      );
    }

    final result = await Process.run(executablePath, [filePath]);
    if (result.exitCode != 0) {
      throw Exception('DeserializeFGFile failed: ${result.stderr}'.trim());
    }

    final stdoutText = result.stdout.toString().trim();
    if (stdoutText.isEmpty) {
      throw Exception('DeserializeFGFile produced no output');
    }

    return stdoutText;
  }

  static String? _findExecutablePath() {
    var current = Directory.current.absolute;

    while (true) {
      final candidate = File(
        _joinPath(
          current.path,
          'DeserializeFGFile',
          'DeserializeFGFile',
          'bin',
          'Debug',
          'net8.0',
          'DeserializeFGFile.exe',
        ),
      );

      if (candidate.existsSync()) {
        return candidate.path;
      }

      final parent = current.parent;
      if (parent.path == current.path) {
        break;
      }
      current = parent;
    }

    return null;
  }

  static String _joinPath(
    String first,
    String second,
    String third,
    String fourth,
    String fifth,
    String sixth,
    String seventh,
  ) {
    return [
      first,
      second,
      third,
      fourth,
      fifth,
      sixth,
      seventh,
    ].join(Platform.pathSeparator);
  }
}
