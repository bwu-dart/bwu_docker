library bwu_utils.tool.grind;

import 'dart:io' as io;
import 'dart:async' show Future, Stream;
import 'package:grinder/grinder.dart';
import 'package:bwu_utils_dev/grinder.dart';
import 'package:bwu_utils_dev/testing_server.dart';

const sourceDirs = const ['bin', 'lib', 'tool', 'test'];

// TODO(zoechi) check if version was incremented
// TODO(zoechi) check if CHANGELOG.md contains version

main(List<String> args) => grind(args);

//@Task('Delete build directory')
//void clean() => defaultClean(context);

@Task('Run analyzer')
analyze() => analyzerTask(files: [], directories: sourceDirs);

@Task('Runn all tests')
test() => _test(
    ['vm', /*'dartium', 'chrome', 'phantomjs', 'firefox', content-shell*/],
    runPubServe: false, runSelenium: false);

@Task('Run all VM tests')
testIo() => _test(['vm']);

@Task('Run all browser tests')
testHtml() => _test(['content-shell'], runPubServe: true);

Future _test(List<String> platforms,
    {bool runPubServe: false, bool runSelenium: false}) async {
  final seleniumJar =
      '/usr/local/apps/webdriver/selenium-server-standalone-2.45.0.jar';

  final pubServe = new PubServe();
  final selenium = new SeleniumStandaloneServer();
  final servers = <Future<RunProcess>>[];

  try {
    if (runPubServe) {
      print('start pub serve');
      servers.add(pubServe.start(directories: const ['test']));
    }
    if (runSelenium) {
      print('start Selenium standalone server');
      servers.add(selenium.start(seleniumJar, args: []));
    }

    await Future.wait(servers);

    if (runPubServe) {
      pubServe.stdout.listen((e) => io.stdout.add(e));
      pubServe.stderr.listen((e) => io.stderr.add(e));
    }
    if (runSelenium) {
      selenium.stdout.listen((e) => io.stdout.add(e));
      selenium.stderr.listen((e) => io.stderr.add(e));
    }

    if (runPubServe) {
      new PubApp.local('test')
        ..run(['--pub-serve=${pubServe.directoryPorts['test']}']
          ..addAll(platforms.map((p) => '-p${p}')));
    } else {
      new PubApp.local('test').run(platforms.map((p) => '-p${p}').toList());
    }
  } finally {
    pubServe.stop();
    selenium.stop();
  }
}

//  final chromeBin = '-Dwebdriver.chrome.bin=/usr/bin/google-chrome';
//  final chromeDriverBin = '-Dwebdriver.chrome.driver=/usr/local/apps/webdriver/chromedriver/2.15/chromedriver_linux64/chromedriver';

@Task('Check everything')
@Depends(analyze, checkFormat, lint, test)
check() {}

@Task('Check source code format')
checkFormat() => checkFormatTask(['.']);

/// format-all - fix all formatting issues
@Task('Fix all source format issues')
formatAll() => new PubApp.global('dart_style').run(['-w']..addAll(sourceDirs),
    script: 'format');

@Task('Run lint checks')
lint() => new PubApp.global('linter')
    .run(['--stats', '-ctool/lintcfg.yaml']..addAll(sourceDirs));
