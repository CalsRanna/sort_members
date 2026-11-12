/// Sorts Dart source files using the Dart analysis server's `edit.sortMembers`
/// request — the same operation as the "Sort Members" action in IDEs.
library;

export 'src/cli.dart' show runCli;
export 'src/file_set.dart' show collectDartFiles;
export 'src/sorter.dart'
    show SortMembersException, SortResult, findAnalysisRoot, sortMembers;
