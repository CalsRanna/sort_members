import 'dart:io';

import 'package:path/path.dart' as p;

/// Directory names that are never scanned.
const skippedDirectoryNames = {'.dart_tool', 'build', '.git'};

/// Files produced by code generators; sorting them is pointless because the
/// next build overwrites them.
final _generatedFile = RegExp(r'\.(g|freezed|gr|mocks|gen)\.dart$');

/// Expands [targets] into a sorted, de-duplicated list of Dart files.
///
/// Directories are scanned recursively, skipping [skippedDirectoryNames] and
/// generated files. Files passed explicitly are always included, generated or
/// not, because the caller asked for them by name.
List<String> collectDartFiles(Iterable<String> targets) {
  final files = <String>{};
  for (final target in targets) {
    final absolute = p.normalize(p.absolute(target));
    switch (FileSystemEntity.typeSync(absolute)) {
      case FileSystemEntityType.file:
        if (absolute.endsWith('.dart')) files.add(absolute);
      case FileSystemEntityType.directory:
        for (final entity in Directory(absolute).listSync(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File) continue;
          final path = p.normalize(entity.path);
          if (!path.endsWith('.dart') || _generatedFile.hasMatch(path)) {
            continue;
          }
          final segments = p.split(p.relative(path, from: absolute));
          if (segments.any(skippedDirectoryNames.contains)) continue;
          files.add(path);
        }
      default:
        stderr.writeln('Ignoring missing path: $target');
    }
  }
  return files.toList()..sort();
}
