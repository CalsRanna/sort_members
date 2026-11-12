import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sort_members/sort_members.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('sort_members_test_');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  File write(String name, String contents) {
    final file = File(p.join(temp.path, name));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
    return file;
  }

  Future<SortResult> sort({bool write = true, List<String>? targets}) {
    return sortMembers(
      targets ?? [temp.path],
      analysisRoot: temp.path,
      write: write,
    );
  }

  test('sorts imports and class members', () async {
    final file = write('sample.dart', _unsorted);
    final result = await sort();
    expect(result.skippedFiles, isEmpty);
    expect(result.changedFiles, [file.path]);
    expect(file.readAsStringSync(), _sorted);
  });

  test('is idempotent', () async {
    write('sample.dart', 'class A {\n  void b() {}\n\n  void a() {}\n}\n');
    final first = await sort();
    expect(first.changedFiles, hasLength(1));
    final second = await sort();
    expect(second.changedFiles, isEmpty);
  });

  test('skips files with syntax errors', () async {
    final file = write('broken.dart', 'class Broken {\n');
    final result = await sort();
    expect(result.changedFiles, isEmpty);
    expect(result.skippedFiles.keys, [file.path]);
    expect(
      result.skippedFiles.values.single,
      contains('SORT_MEMBERS_PARSE_ERRORS'),
    );
  });

  test('does not write in check mode', () async {
    final file = write('sample.dart', _unsorted);
    final result = await sort(write: false);
    expect(result.changedFiles, [file.path]);
    expect(file.readAsStringSync(), _unsorted);
  });

  test('skips generated files and build directories when scanning', () {
    final kept = write('lib/kept.dart', 'class Kept {}\n');
    write('lib/kept.g.dart', 'class Generated {}\n');
    write('lib/kept.freezed.dart', 'class Generated {}\n');
    write('build/ignored.dart', 'class Ignored {}\n');
    write('.dart_tool/ignored.dart', 'class Ignored {}\n');

    expect(collectDartFiles([temp.path]), [kept.path]);
  });

  test('processes explicitly passed generated files', () async {
    final file = write(
      'lib/thing.g.dart',
      'class Generated {\n  void b() {}\n\n  void a() {}\n}\n',
    );
    final result = await sort(targets: [file.path]);
    expect(result.skippedFiles, isEmpty);
    expect(result.changedFiles, [file.path]);
  });

  test('finds the nearest package_config.json', () {
    final packageRoot = Directory(p.join(temp.path, 'pkg'))..createSync();
    File(p.join(packageRoot.path, '.dart_tool', 'package_config.json'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{}');
    final nested = Directory(p.join(packageRoot.path, 'lib', 'src'))
      ..createSync(recursive: true);

    expect(findAnalysisRoot(nested.path), packageRoot.path);
  });

  test('CLI check mode exits with 1 when changes are needed', () async {
    final file = write('sample.dart', _unsorted);
    final code = await runCli(['--check', '--root', temp.path, temp.path]);
    expect(code, 1);
    expect(file.readAsStringSync(), _unsorted);
  });

  test('CLI check mode exits with 0 when already sorted', () async {
    write('sample.dart', 'class A {\n  void a() {}\n}\n');
    final code = await runCli(['--check', '--root', temp.path, temp.path]);
    expect(code, 0);
  });
}

const _sorted = '''
import 'a.dart';
import 'b.dart';

class Sample {
  static const constant = 1;

  int value = 0;

  Sample();

  void method() {}

  static void z() {}
}
''';

const _unsorted = '''
import 'b.dart';
import 'a.dart';

class Sample {
  static void z() {}

  Sample();

  int value = 0;

  static const constant = 1;

  void method() {}
}
''';
