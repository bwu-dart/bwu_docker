library bwu_docker.test.all;

import 'package:test/test.dart';
import 'shared/all.dart' as shared;
import 'v1x15_to_v1x19/all.dart' as v1x15_to_v1x19;
import 'v1x20/all.dart' as v1x20;

void main() {
  group('', () => shared.main());
  group('', () => v1x15_to_v1x19.main());
  group('', () => v1x20.main());
}
