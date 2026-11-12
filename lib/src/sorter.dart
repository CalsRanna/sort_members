import 'dart:io';

import 'package:analysis_server_lib/analysis_server_lib.dart';
import 'package:path/path.dart' as p;

import 'file_set.dart';

/// The server can answer FILE_NOT_ANALYZED while it is still creating
/// analysis contexts, and CONTENT_MODIFIED when a file changes mid-request.
/// Both are transient in a batch run, so retry briefly.
const _retryableCodes = {'FILE_NOT_ANALYZED', 'CONTENT_MODIFIED'};

/// Returns the closest ancestor of [directory] that contains a
/// `.dart_tool/package_config.json`, or [directory] itself if there is none.
String findAnalysisRoot(String directory) {
  final start = Directory(directory).absolute.path;
  var dir = Directory(start);
  while (true) {
    if (File(p.join(dir.path, '.dart_tool', 'package_config.json'))
        .existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return start;
    dir = parent;
  }
}

/// Sorts the members of every Dart file under [targets] using the Dart
/// analysis server's `edit.sortMembers` request.
///
/// [targets] may contain files and directories. When [write] is false no file
/// is modified; [SortResult.changedFiles] then lists the files that would
/// change.
///
/// [analysisRoot] must be a directory the analysis server can analyze. It
/// defaults to the [findAnalysisRoot] of the current directory.
Future<SortResult> sortMembers(
  Iterable<String> targets, {
  String? analysisRoot,
  bool write = true,
}) async {
  final files = collectDartFiles(targets);
  if (files.isEmpty) {
    return SortResult(changedFiles: const [], skippedFiles: const {});
  }

  final root = analysisRoot ?? findAnalysisRoot(Directory.current.path);
  if (!Directory(root).existsSync()) {
    throw SortMembersException('Analysis root does not exist: $root');
  }

  final AnalysisServer server;
  try {
    server = await AnalysisServer.create();
  } catch (error) {
    throw SortMembersException(
      'Unable to start the Dart analysis server: $error\n'
      'sort_members requires a Dart SDK that includes '
      'bin/snapshots/analysis_server.dart.snapshot.',
    );
  }

  final changed = <String>[];
  final skipped = <String, String>{};
  try {
    try {
      await server.analysis.setAnalysisRoots([root], []);
    } on RequestError catch (error) {
      throw SortMembersException(
        'Unable to use $root as an analysis root: ${error.message}',
      );
    }
    for (final file in files) {
      try {
        final result = await _sortMembers(server, file);
        final edits = result.edit.edits;
        if (edits.isEmpty) continue;
        changed.add(file);
        if (write) await _applyEdits(file, edits);
      } on RequestError catch (error) {
        skipped[file] = '${error.code}: ${error.message}';
      }
    }
  } finally {
    await _close(server);
  }
  return SortResult(changedFiles: changed, skippedFiles: skipped);
}

/// SourceEdit offsets count UTF-16 code units, which matches Dart's String
/// indices. Apply from the end so earlier offsets stay valid.
Future<void> _applyEdits(String path, List<SourceEdit> edits) async {
  final file = File(path);
  var content = await file.readAsString();
  for (final edit in edits.toList()
    ..sort((a, b) => b.offset.compareTo(a.offset))) {
    content = content.replaceRange(
      edit.offset,
      edit.offset + edit.length,
      edit.replacement,
    );
  }
  await file.writeAsString(content);
}

Future<void> _close(AnalysisServer server) async {
  try {
    await server.server.shutdown().timeout(const Duration(seconds: 5));
  } catch (_) {
    // The server may already be gone; killing it below is enough.
  } finally {
    server.dispose();
  }
}

Future<SortMembersResult> _sortMembers(
  AnalysisServer server,
  String path,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (true) {
    try {
      return await server.edit.sortMembers(path);
    } on RequestError catch (error) {
      if (!_retryableCodes.contains(error.code) ||
          DateTime.now().isAfter(deadline)) {
        rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
}

/// Thrown when the analysis server cannot be started or used.
class SortMembersException implements Exception {
  final String message;

  SortMembersException(this.message);

  @override
  String toString() => message;
}

/// The outcome of a [sortMembers] run.
class SortResult {
  /// Files whose content changed, or — when running with `write: false` —
  /// files that would change.
  final List<String> changedFiles;

  /// Files that could not be sorted, mapped to a human-readable reason.
  final Map<String, String> skippedFiles;

  SortResult({
    required List<String> changedFiles,
    required Map<String, String> skippedFiles,
  })  : changedFiles = List.unmodifiable(changedFiles),
        skippedFiles = Map.unmodifiable(skippedFiles);
}
