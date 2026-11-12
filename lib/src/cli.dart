import 'dart:io';

import 'package:args/args.dart';

import 'sorter.dart';

/// Runs the command-line interface and returns the process exit code.
Future<int> runCli(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag(
      'check',
      abbr: 'c',
      negatable: false,
      help: 'Report files that would change instead of writing them. '
          'Exits with code 1 when changes are needed.',
    )
    ..addOption(
      'root',
      help: 'Analysis root. Defaults to the nearest ancestor directory '
          'containing .dart_tool/package_config.json.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln();
    stderr.writeln(parser.usage);
    return 64;
  }

  if (results.flag('help')) {
    stdout.writeln('Sort Dart class members with the Dart analysis server.');
    stdout.writeln();
    stdout.writeln(parser.usage);
    return 0;
  }

  final check = results.flag('check');
  final targets = results.rest.isEmpty ? ['.'] : results.rest;
  try {
    final result = await sortMembers(
      targets,
      analysisRoot: results.option('root'),
      write: !check,
    );

    for (final file in result.changedFiles) {
      stdout.writeln('${check ? 'Would sort' : 'Sorted'} $file');
    }
    if (result.changedFiles.isEmpty && result.skippedFiles.isEmpty) {
      stdout.writeln('All Dart files are already sorted.');
      return 0;
    }

    final action = check ? 'need sorting' : 'sorted';
    stdout.writeln(
      '${result.changedFiles.length} file(s) $action, '
      '${result.skippedFiles.length} skipped.',
    );
    if (result.skippedFiles.isNotEmpty) {
      stdout.writeln('Skipped files:');
      result.skippedFiles.forEach(
        (path, reason) => stdout.writeln('  $path\n    $reason'),
      );
      return 1;
    }
    if (check && result.changedFiles.isNotEmpty) return 1;
    return 0;
  } on SortMembersException catch (error) {
    stderr.writeln(error.message);
    return 1;
  }
}
