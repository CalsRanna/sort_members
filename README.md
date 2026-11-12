# sort_members

Sorts Dart and Flutter class members using the Dart analysis server — the exact
same operation as the **Sort Members** code action in Zed, VS Code, IntelliJ,
and other editors.

Imports are sorted, fields move before constructors, instance methods come
before static methods, and members are alphabetical within each group. The
sorting rules come from the analysis server shipped with the Dart SDK you use,
so the result matches your IDE. Formatting is otherwise untouched.

## Usage

Add the package as a dev dependency:

```bash
dart pub add dev:sort_members
```

Then, from the project root:

```bash
dart run sort_members              # sort every Dart file in the project
dart run sort_members lib test     # sort specific files or directories
dart run sort_members --check      # CI mode: do not write, fail if changes are needed
```

Flutter projects work the same way:

```bash
flutter pub add dev:sort_members
dart run sort_members
```

## Options

| Option | Description |
| --- | --- |
| `--check`, `-c` | Report files that would change instead of writing them. Exits with code 1 when changes are needed. |
| `--root <dir>` | Analysis root. Defaults to the nearest ancestor directory containing `.dart_tool/package_config.json`. |
| `--help`, `-h` | Show usage. |

## What gets skipped

When scanning directories, the tool ignores:

- `.dart_tool/`, `build/`, `.git/`
- generated files: `*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.mocks.dart`, `*.gen.dart`

Files passed explicitly on the command line are always processed.

Files with syntax errors are skipped and reported; the exit code is 1.

## Requirements

`sort_members` runs the analysis server bundled with the Dart SDK used to start
it. Dart and Flutter SDKs ship that server at
`bin/snapshots/analysis_server.dart.snapshot`. Because the sorter comes from
the SDK, the exact ordering rules can evolve with the SDK version.

## Library API

```dart
import 'package:sort_members/sort_members.dart';

final result = await sortMembers(
  ['lib'],
  write: false, // dry run
);
print(result.changedFiles);
print(result.skippedFiles);
```

`sortMembers` returns the files that changed (or would change) and the files
that were skipped, with a reason. `collectDartFiles` exposes the same file
selection rules, and `findAnalysisRoot` the analysis-root lookup.

## How it works

The package starts the Dart analysis server, sends one `edit.sortMembers`
request per file, and applies the returned source edits. It does not
reimplement the sorting logic.
