import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Service for file picker and file I/O operations.
///
/// Provides methods to open, save, and manage `.fg` grade files using the
/// `file_picker` package for cross-platform file dialogs.
///
/// Note: On web, returns file bytes instead of paths since web doesn't have
/// direct file system access.
class FileService {
  /// Picks a file (either .fg or .json) and returns its bytes.
  ///
  /// Accepts both binary .fg files and JSON export files.
  /// On desktop platforms, reads the file at the returned path and returns bytes.
  /// On web, returns the bytes directly from the picker.
  ///
  /// Returns null if the user cancelled the picker.
  static Future<(Uint8List?, String?, String?)> pickGradeFileBytes() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['fg', 'json', 'xlsx', 'xls'],
        dialogTitle: 'Open FU Grading File (.fg, .json) or Excel (.xlsx)',
        lockParentWindow: !kIsWeb,
      );

      if (result == null) return (null, null, null);

      final fileName = result.files.single.name;

      // On web, bytes are available directly
      if (kIsWeb) {
        return (result.files.single.bytes, fileName, null);
      }

      // On desktop, read from path
      final path = result.files.single.path;
      if (path == null) return (null, null, null);

      final file = File(path);
      final bytes = await file.readAsBytes();
      return (bytes, fileName, path);
    } catch (e) {
      rethrow;
    }
  }

  /// Picks a JSON config file (e.g., `subjectconfig.json`) and returns its bytes.
  ///
  /// Returns a tuple `(bytes, fileName, path)` similar to `pickGradeFileBytes()`.
  static Future<(Uint8List?, String?, String?)> pickConfigFileBytes() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Open subjectconfig.json',
        lockParentWindow: !kIsWeb,
      );

      if (result == null) return (null, null, null);

      final fileName = result.files.single.name;

      if (kIsWeb) {
        return (result.files.single.bytes, fileName, null);
      }

      final path = result.files.single.path;
      if (path == null) return (null, null, null);

      final file = File(path);
      final bytes = await file.readAsBytes();
      return (bytes, fileName, path);
    } catch (e) {
      rethrow;
    }
  }

  /// Picks a .fg file and returns its bytes. (Alias for backward compatibility)
  ///
  /// On desktop platforms, reads the file at the returned path and returns bytes.
  /// On web, returns the bytes directly from the picker.
  ///
  /// Returns null if the user cancelled the picker.
  static Future<Uint8List?> pickFgFileBytes() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['fg'],
        dialogTitle: 'Open FU Grading File',
        lockParentWindow: !kIsWeb,
      );

      if (result == null) return null;

      // On web, bytes are available directly
      if (kIsWeb) {
        return result.files.single.bytes;
      }

      // On desktop, read from path
      final path = result.files.single.path;
      if (path == null) return null;

      final file = File(path);
      return await file.readAsBytes();
    } catch (e) {
      rethrow;
    }
  }

  /// Opens a file picker dialog to select a `.fg` file.
  ///
  /// Returns the file path if a file was selected, or null if the dialog
  /// was cancelled. Only works on desktop platforms.
  ///
  /// Throws an exception if the file picker encounters an error.
  @Deprecated('Use pickFgFileBytes() instead for web compatibility')
  static Future<String?> pickFgFile() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'pickFgFile() is not supported on web. Use pickFgFileBytes() instead.',
      );
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['fg'],
        dialogTitle: 'Open FU Grading File',
        lockParentWindow: true,
      );

      return result?.files.single.path;
    } catch (e) {
      rethrow;
    }
  }

  /// Saves the given [bytes] to a file at the specified [path].
  ///
  /// Creates or overwrites the file at [path] with the contents of [bytes].
  /// Only works on desktop platforms.
  ///
  /// Throws an exception if the file cannot be written.
  static Future<void> saveFgFile(String path, Uint8List bytes) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'saveFgFile() is not supported on web. Use downloadFile() instead.',
      );
    }

    try {
      final file = File(path);
      await file.writeAsBytes(bytes);
    } catch (e) {
      rethrow;
    }
  }

  /// Opens a file picker dialog to select a save location for a `.fg` file.
  ///
  /// Returns the file path if a location was selected, or null if the dialog
  /// was cancelled. The returned path may not have a `.fg` extension, so the
  /// caller should add it if needed.
  ///
  /// Only works on desktop platforms.
  ///
  /// Throws an exception if the file picker encounters an error.
  static Future<String?> pickSavePath() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'pickSavePath() is not supported on web. Use downloadFile() instead.',
      );
    }

    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save FU Grading File',
        fileName: 'grades.fg',
        type: FileType.custom,
        allowedExtensions: ['fg'],
        lockParentWindow: true,
      );

      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Opens a file picker dialog to select a save location for an Excel file.
  ///
  /// Returns the file path if a location was selected, or null if the dialog
  /// was cancelled. Only works on desktop platforms.
  ///
  /// Throws an exception if the file picker encounters an error.
  static Future<String?> pickExcelSavePath() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'pickExcelSavePath() is not supported on web. Use downloadFile() instead.',
      );
    }

    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export to Excel',
        fileName: 'grades.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        lockParentWindow: true,
      );

      return result;
    } catch (e) {
      rethrow;
    }
  }
}
