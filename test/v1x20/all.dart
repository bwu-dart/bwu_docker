library bwu_docker.test.v1x20.all;

import 'package:test/test.dart';
import 'data_structures_test.dart' as ds;
import 'remote_api_test.dart' as ra;
import 'tasks_test.dart' as tasks;

void main() {
  group('', () => ds.main());
  group('', () => ra.main());
  group('', () => tasks.main());
}
