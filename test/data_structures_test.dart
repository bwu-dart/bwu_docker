@TestOn('vm')
library bwu_docker.test.data_structures;

import 'package:test/test.dart';
import 'package:bwu_docker/bwu_docker.dart';

const Map<String,dynamic> json = const <String,dynamic>{
  "PortBindings": const {
    "22/tcp": const [
      const {"HostPort": "11022"}
    ]
  }
};

void main() {
  group('PortBindings', () {
    test(
        'JSON deserialize => serialize JSON result result in same setting values',
        () {
      final HostConfig hc = new HostConfig.fromJson(json, RemoteApiVersion.v1_17);
      final Map<String,dynamic> json2 = hc.toJson();
      final HostConfig hc2 = new HostConfig.fromJson(json2, RemoteApiVersion.v1_17);

      expect(hc2.portBindings.length, hc.portBindings.length);
      expect(hc2.portBindings.keys.first, hc.portBindings.keys.first);
      expect(hc2.portBindings.values.first[0].hostPort,
          hc.portBindings.values.first[0].hostPort);
      expect(hc2.portBindings.values.first[0].hostIp, isNull);
    });
  });
}
