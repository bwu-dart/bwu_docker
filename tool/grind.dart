library bwu_docker.tool.grind;

import 'package:grinder/grinder.dart';

const sourceDirs = const ['bin', 'lib', 'tool', 'test'];

// TODO(zoechi) check if version was incremented
// TODO(zoechi) check if CHANGELOG.md contains version

main(List<String> args) => grind(args);

//@Task('Delete build directory')
//void clean() => defaultClean(context);

@Task('Run analyzer')
analyze() => new PubApp.global('tuneup')
    .run(['check']); // analyzerTask(files: [], directories: sourceDirs);

@Task('Runn all tests')
test() => new PubApp.local('test').run([]);

@Task('Check everything')
@Depends(analyze, /*checkFormat,*/ lint, test)
check() {
  run('pub', arguments: ['publish', '-n']);
}

//@Task('Check source code format')
//checkFormat() => checkFormatTask(['.']);

/// format-all - fix all formatting issues
@Task('Fix all source format issues')
formatAll() => new PubApp.global('dart_style').run(['-w']..addAll(sourceDirs),
    script: 'format');

@Task('Run lint checks')
lint() => new PubApp.global('linter')
    .run(['--stats', '-ctool/lintcfg.yaml']..addAll(sourceDirs));
