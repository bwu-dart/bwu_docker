@TestOn('vm')
library bwu_docker.test.demux;

import 'dart:async' show Future, StreamController;
import 'package:collection/equality.dart';
import 'package:test/test.dart';
import 'package:bwu_docker/src/remote_api.dart';

final sampleString = 'abcdefghij'.codeUnits;
final eq = const ListEquality().equals;

main() {
  StreamController sc;
  DeMux mux;

  setUp(() {
    sc = new StreamController();
    mux = new DeMux(sc.stream);
  });

  test('should receive simple chunk as sent', () async {
    final expectDataReceived = expectAsync(() {}, count: 2);
    var subscription = mux.stdout.listen((e) {
      if (eq(e, sampleString)) {
        expectDataReceived();
      }
    });

    new Future.delayed(const Duration(milliseconds: 200), () {
      sc.add([1, 0, 0, 0, 0, 0, 0, sampleString.length]..addAll(sampleString));
      sc.add([1, 0, 0, 0, 0, 0, 0, sampleString.length]..addAll(sampleString));
      sc.close();
    });

    await subscription.asFuture();
  });

  test('should forward chunks belonging together to the same output stream',
      () async {
    final expectDataReceived = expectAsync(() {}, count: 4);

    var subscription = mux.stderr.listen((e) {
      if (eq(e, sampleString)) {
        expectDataReceived();
      }
    });

    new Future.delayed(const Duration(milliseconds: 200), () {
      sc.add([2, 0, 0, 0, 0, 0, 0, sampleString.length]..addAll(sampleString));
      sc.add(
          [2, 0, 0, 0, 0, 0, 0, sampleString.length * 3]..addAll(sampleString));
      sc.add(sampleString);
      sc.add(sampleString);
      sc.close();
    });

    await subscription.asFuture();
  });

  test('should split chunks that contain data for more than one output stream',
      () async {
    final expectDataReceived = expectAsync(() {});
    final expectChunkedDataReceived = expectAsync(() {});

    var subscription = mux.stderr.listen((e) {
      if (eq(e, sampleString)) {
        expectDataReceived();
      }

      if (eq(
          e,
          []
            ..addAll(sampleString)
            ..addAll(sampleString)
            ..addAll(sampleString))) {
        expectChunkedDataReceived();
      }
    });

    new Future.delayed(const Duration(milliseconds: 200), () {
      sc.add([2, 0, 0, 0, 0, 0, 0, sampleString.length]..addAll(sampleString));

      var data = [2, 0, 0, 0, 0, 0, 0, sampleString.length * 3]
        ..addAll(sampleString)
        ..addAll(sampleString)
        ..addAll(sampleString)
        ..addAll([1, 0, 0, 0, 0, 0, 0, sampleString.length * 3])
        ..addAll(sampleString)
        ..addAll(sampleString)
        ..addAll(sampleString);
      sc.add(data);
      sc.close();
    });

    await subscription.asFuture();
  });
}
