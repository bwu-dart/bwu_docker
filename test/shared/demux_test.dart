@TestOn('vm')
library bwu_docker.test.demux;

import 'dart:async' show Future, StreamController, StreamSubscription;
import 'package:collection/collection.dart' show ListEquality;
import 'package:test/test.dart';
import 'package:bwu_docker/src/shared/remote_api.dart';

final List<int> sampleString = 'abcdefghij'.codeUnits;
final Function eq = const ListEquality().equals;

void main() {
  StreamController<List<int>> sc;
  DeMux mux;

  setUp(() {
    sc = new StreamController<List<int>>();
    mux = new DeMux(sc.stream);
  });

  test('should receive simple chunk as sent', () async {
    final Function expectDataReceived = expectAsync(() {}, count: 2);
    final StreamSubscription subscription = mux.stdout.listen((List<int> e) {
      if (eq(e, sampleString)) {
        expectDataReceived();
      }
    });

    new Future.delayed(const Duration(milliseconds: 200), () {
      sc.add(<int>[1, 0, 0, 0, 0, 0, 0, sampleString.length]
        ..addAll(sampleString));
      sc.add(<int>[1, 0, 0, 0, 0, 0, 0, sampleString.length]
        ..addAll(sampleString));
      sc.close();
    });

    await subscription.asFuture();
  });

  test('should forward chunks belonging together to the same output stream',
      () async {
    final Function expectDataReceived = expectAsync(() {}, count: 4);

    final StreamSubscription<List<int>> subscription =
        mux.stderr.listen((List<int> e) {
      if (eq(e, sampleString)) {
        expectDataReceived();
      }
    });

    new Future.delayed(const Duration(milliseconds: 200), () {
      sc.add(<int>[2, 0, 0, 0, 0, 0, 0, sampleString.length]
        ..addAll(sampleString));
      sc.add(<int>[2, 0, 0, 0, 0, 0, 0, sampleString.length * 3]
        ..addAll(sampleString));
      sc.add(sampleString);
      sc.add(sampleString);
      sc.close();
    });

    await subscription.asFuture();
  });

  test('should split chunks that contain data for more than one output stream',
      () async {
    final Function expectDataReceived = expectAsync(() {});
    final Function expectChunkedDataReceived = expectAsync(() {});

    final StreamSubscription<List<int>> subscription =
        mux.stderr.listen((List<int> e) {
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
      sc.add(<int>[2, 0, 0, 0, 0, 0, 0, sampleString.length]
        ..addAll(sampleString));

      final List<int> data = <int>[2, 0, 0, 0, 0, 0, 0, sampleString.length * 3]
        ..addAll(sampleString)
        ..addAll(sampleString)
        ..addAll(sampleString)
        ..addAll(<int>[1, 0, 0, 0, 0, 0, 0, sampleString.length * 3])
        ..addAll(sampleString)
        ..addAll(sampleString)
        ..addAll(sampleString);
      sc.add(data);
      sc.close();
    });

    await subscription.asFuture();
  });
}
