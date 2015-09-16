@TestOn('vm')
library bwu_docker.test.version;

import 'package:test/test.dart';
import 'package:bwu_docker/src/data_structures.dart';

main() {
  group('version', () {
    test('create', () {
      final v1 = new Version.fromString('1.2.3');
      expect(v1.major, 1);
      expect(v1.minor, 2);
      expect(v1.patch, 3);

      final v2 = new Version.fromString('10.20.30');
      expect(v2.major, 10);
      expect(v2.minor, 20);
      expect(v2.patch, 30);

      final v3 = new Version.fromString('1.2');
      expect(v3.major, 1);
      expect(v3.minor, 2);
      expect(v3.patch, null);
    });

    test('create invalid should throw', () {
      expect(() => new Version.fromString('1'), throws);
      expect(() => new Version.fromString('.2'), throws);
      expect(() => new Version.fromString('..2'), throws);
      expect(() => new Version.fromString('1..2'), throws);
      expect(() => new Version.fromString('1..'), throws);
      expect(() => new Version.fromString('.'), throws);
      expect(() => new Version.fromString('..'), throws);
      expect(() => new Version.fromString('...'), throws);
      expect(() => new Version.fromString('0.1.-1'), throws);
      expect(() => new Version.fromString('1.2.3.4'), throws);
      expect(() => new Version.fromString('1.2.a'), throws);
      expect(() => new Version.fromString('1.2.3a'), throws);
      expect(() => new Version.fromString('1.2.3-a'), throws);
    });

    test('two instances created with same version should be equal', () {
      expect(new Version.fromString('1.1.1') == new Version.fromString('1.1.1'),
          true);
      expect(new Version.fromString('1.2.3') == new Version.fromString('1.2.3'),
          true);
      expect(new Version.fromString('3.2.1') == new Version.fromString('3.2.1'),
          true);
      expect(new Version.fromString('0.1.2') == new Version.fromString('0.1.2'),
          true);
      expect(new Version.fromString('0.0.1') == new Version.fromString('0.0.1'),
          true);
      expect(new Version.fromString('0.0.0') == new Version.fromString('0.0.0'),
          true);
      expect(
          new Version.fromString('10.20.30') ==
              new Version.fromString('10.20.30'),
          true);
      expect(
          new Version.fromString('1.1') == new Version.fromString('1.1'), true);
      expect(
          new Version.fromString('1.2') == new Version.fromString('1.2'), true);
      expect(
          new Version.fromString('2.1') == new Version.fromString('2.1'), true);
      expect(
          new Version.fromString('0.1') == new Version.fromString('0.1'), true);
      expect(
          new Version.fromString('0.0') == new Version.fromString('0.0'), true);
    });

    test('two instances created with different version should not be equal',
        () {
      expect(new Version.fromString('1.2.3') == new Version.fromString('0.0.0'),
          false);
      expect(new Version.fromString('0.0.0') == new Version.fromString('1.2.3'),
          false);
      expect(new Version.fromString('1.2') == new Version.fromString('0.0'),
          false);
      expect(new Version.fromString('0.0.0') == new Version.fromString('0.0'),
          false);
    });

    test('bigger > smaller version should be true', () {
      expect(new Version.fromString('0.0.1') > new Version.fromString('0.0.0'),
          true);
      expect(new Version.fromString('0.1.0') > new Version.fromString('0.0.1'),
          true);
      expect(new Version.fromString('1.0.0') > new Version.fromString('0.0.1'),
          true);
      expect(new Version.fromString('10.0.0') > new Version.fromString('9.0.0'),
          true);
      expect(new Version.fromString('0.10.0') > new Version.fromString('0.9.0'),
          true);
      expect(
          new Version.fromString('10.0') > new Version.fromString('9.0'), true);
      expect(
          new Version.fromString('0.10') > new Version.fromString('0.9'), true);
    });

    test('smaller > bigger version should be false', () {
      expect(new Version.fromString('0.0.0') > new Version.fromString('0.0.1'),
          false);
      expect(new Version.fromString('0.0.1') > new Version.fromString('0.1.0'),
          false);
      expect(new Version.fromString('0.0.1') > new Version.fromString('1.0.0'),
          false);
      expect(new Version.fromString('9.0.0') > new Version.fromString('10.0.0'),
          false);
      expect(new Version.fromString('0.9.0') > new Version.fromString('0.10.0'),
          false);
      expect(new Version.fromString('0.0.9') > new Version.fromString('0.0.10'),
          false);
      expect(new Version.fromString('9.0') > new Version.fromString('10.0'),
          false);
      expect(new Version.fromString('0.9') > new Version.fromString('0.10'),
          false);
    });

    test('smaller < bigger version should be true', () {
      expect(new Version.fromString('0.0.0') < new Version.fromString('0.0.1'),
          true);
      expect(new Version.fromString('0.0.1') < new Version.fromString('0.1.0'),
          true);
      expect(new Version.fromString('0.0.1') < new Version.fromString('1.0.0'),
          true);
      expect(new Version.fromString('9.0.0') < new Version.fromString('10.0.0'),
          true);
      expect(new Version.fromString('0.9.0') < new Version.fromString('0.10.0'),
          true);
      expect(new Version.fromString('0.0.9') < new Version.fromString('0.0.10'),
          true);
      expect(
          new Version.fromString('9.0') < new Version.fromString('10.0'), true);
      expect(
          new Version.fromString('0.9') < new Version.fromString('0.10'), true);
    });

    test('bigger < smaller version should be false', () {
      expect(new Version.fromString('0.0.1') < new Version.fromString('0.0.0'),
          false);
      expect(new Version.fromString('0.1.0') < new Version.fromString('0.0.1'),
          false);
      expect(new Version.fromString('1.0.0') < new Version.fromString('0.0.1'),
          false);
      expect(new Version.fromString('10.0.0') < new Version.fromString('9.0.0'),
          false);
      expect(new Version.fromString('0.10.0') < new Version.fromString('0.9.0'),
          false);
      expect(new Version.fromString('10.0') < new Version.fromString('9.0'),
          false);
      expect(new Version.fromString('0.10') < new Version.fromString('0.9'),
          false);
    });
  });
}
