library bwu_docker.test.shared.all;

import 'package:test/test.dart';
import 'demux_test.dart' as demux;
import 'version_test.dart' as version;

void main() {
  group('', () => demux.main());
  group('', () => version.main());
}
