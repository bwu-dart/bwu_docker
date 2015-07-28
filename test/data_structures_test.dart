@TestOn('vm')
library bwu_docker.test.data_structures;

import 'package:test/test.dart';
import 'package:bwu_docker/bwu_docker.dart';

const json = const {
  "PortBindings": const {"22/tcp": const [const {"HostPort": "11022"}]}
};

main() {
  group('PortBindings', () {
    test(
        'JSON deserialize => serialize JSON result result in same setting values',
        () {
      final hc = new HostConfig.fromJson(json, ApiVersion.v1_17);
      final json2 = hc.toJson();
      final hc2 = new HostConfig.fromJson(json2, ApiVersion.v1_17);

      expect(hc2.portBindings.length, hc.portBindings.length);
      expect(hc2.portBindings.keys.first, hc.portBindings.keys.first);
      expect(hc2.portBindings.values.first[0].hostPort,
          hc.portBindings.values.first[0].hostPort);
      expect(hc2.portBindings.values.first[0].hostIp, isNull);
    });
  });
}
