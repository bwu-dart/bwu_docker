library bwu_docker.tool.grind;

import 'dart:async' show Future;
import 'dart:io' as io;
import 'package:bwu_docker/bwu_docker.dart';
export 'package:bwu_utils_dev/grinder/default_tasks.dart' hide main, testWeb;
import 'package:bwu_utils_dev/grinder/default_tasks.dart'
    show doInstallContentShell, grind, testTask;
import 'package:grinder/grinder.dart';
import 'package:http/http.dart' as http;

const dindPort = 3375;

main(List<String> args) {
  doInstallContentShell = false;
  testTask = ([_]) => _testTaskImpl();
  grind(args);
}

Container _dindRemoteApiTest;
Container _dindTasksTest;

Uri _uriUpdatePort(Uri uri, int port) {
  final result = new Uri(
      scheme: uri.scheme, userInfo: uri.userInfo, host: uri.host, port: port);
  print('${result}');
  return result;
}

_testTaskImpl() async {
  final dockerHostStr = io.Platform.environment[dockerHostFromEnvironment];
  assert(dockerHostStr != null && dockerHostStr.isNotEmpty);
  final dockerHost = Uri.parse(dockerHostStr);

  DockerConnection docker = new DockerConnection(
      Uri.parse(io.Platform.environment[dockerHostFromEnvironment]),
      new http.Client());
  await docker.init();
  try {
    await _dindStartForTest(docker);
    try {
//      Pub.downgrade();
      new PubApp.local('test').run(['-rexpanded'],
          runOptions: new RunOptions(
              environment: {
        dockerHostFromEnvironment:
            _uriUpdatePort(dockerHost, dindPort).toString()
      }));
    } catch (_) {
      rethrow;
    } finally {
//      Pub.upgrade();
    }
    new PubApp.local('test').run(['-rexpanded'],
        runOptions: new RunOptions(
            environment: {
      dockerHostFromEnvironment: _uriUpdatePort(dockerHost, dindPort).toString()
    }));
  } catch (_) {
    rethrow;
  } finally {
    await _dindCleanupAfterTest(docker);
  }
}

/// Prepare Docker-in-Docker instances for running tests.
Future _dindStartForTest(DockerConnection docker) {
  return Future.wait([
    _dindCreateContainer(docker, dindPort)
        .then((container) => _dindRemoteApiTest = container),
    _dindCreateContainer(docker, dindPort + 1)
        .then((container) => _dindTasksTest = container),
  ]);
}

/// Create and start a Docker-in-Docker container.
Future<Container> _dindCreateContainer(
    DockerConnection docker, int port) async {
  try {
    await docker.image(new Image('jpetazzo/dind'));
  } on DockerRemoteApiError {
    await docker.createImage('jpetazzo/dind');
//    for (var e in createResponse) {
//      print('${e.status} - ${e.progressDetail}');
//    }
  }
  final hostConfig = new HostConfigRequest()
    ..privileged = true
    ..publishAllPorts = false
    ..portBindings = [
      new PortBindingRequest()
        ..port = '${port}/tcp'
        ..hostPorts = [new HostPort('${port}')]
    ];
  return docker.createContainer(new CreateContainerRequest()
    ..hostName = 'remote_api_test'
    ..image = 'jpetazzo/dind'
    ..exposedPorts = {'${port}/tcp': {}}
    ..env = {'PORT': '${port}'}
    ..attachStdin = false
    ..attachStdout = false
    ..attachStderr = false
    ..tty = false
    ..openStdin = false
    ..stdinOnce = false
    ..hostConfig = hostConfig).then((response) {
    return docker
        .start(response.container, hostConfig: hostConfig)
        .then((_) => response.container);
//'''
//{"Privileged":true,"PortBindings":{"1234/tcp":[{"HostIp":"","HostPort":"1234"}]},"PublishAllPorts":false,"NetworkMode":"bridge"}
//{"Binds":null,"ContainerIDFile":"","LxcConf":[],"Privileged":true,"PortBindings":{"1234/tcp":[{"HostIp":"","HostPort":"1234"}]},"Links":null,"PublishAllPorts":false,"Dns":null,"DnsSearch":null,"ExtraHosts":null,"VolumesFrom":null,"Devices":[],"NetworkMode":"bridge","CapAdd":null,"CapDrop":null,"RestartPolicy":{"Name":"","MaximumRetryCount":0},"SecurityOpt":null}
//'''
  });
}

/// Remove Docker-in-Docker container after tests are done.
Future _dindCleanupAfterTest(DockerConnection docker) {
  return Future.wait([
    _dindRemoveContainer(docker, _dindRemoteApiTest),
    _dindRemoveContainer(docker, _dindTasksTest)
  ]);
}

/// Stop and remove a Docker-in-Docker container.
Future _dindRemoveContainer(
    DockerConnection docker, Container container) async {
  if (container == null) {
    return;
  }
  try {
    await docker.stop(container);
    await docker.removeContainer(container);
    await docker.removeImage(new Image(container.image));
  } catch (_) {}
}
