@TestOn('vm')
library bwu_docker.test.v1x15_to_v1x19.data_structures;

import 'package:test/test.dart';
import 'package:bwu_docker/bwu_docker_v1x20.dart';

const Map<String, dynamic> json = const <String, dynamic>{
  "PortBindings": const {
    "22/tcp": const [
      const {"HostPort": "11022"}
    ]
  }
};

void main() {
  doCheckSurplusItems = true;
  group('PortBindings', () {
    test(
        'JSON deserialize => serialize JSON result result in same setting values',
        () {
      final HostConfig hc =
          new HostConfig.fromJson(json, RemoteApiVersion.v1x17);
      final Map<String, dynamic> json2 = hc.toJson();
      final HostConfig hc2 =
          new HostConfig.fromJson(json2, RemoteApiVersion.v1x17);

      expect(hc2.portBindings.length, hc.portBindings.length);
      expect(hc2.portBindings.keys.first, hc.portBindings.keys.first);
      expect(hc2.portBindings.values.first[0].hostPort,
          hc.portBindings.values.first[0].hostPort);
      expect(hc2.portBindings.values.first[0].hostIp, isNull);
    });
  });
}
