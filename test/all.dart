library bwu_docker.test.all;

import 'data_structures_test.dart' as ds;
import 'demux_test.dart' as demux;
import 'remote_api_test.dart' as ra;
import 'tasks_test.dart' as tasks;
import 'version_test.dart' as version;

main() {
  ds.main();
  demux.main();
  ra.main();
  tasks.main();
  version.main();
}
