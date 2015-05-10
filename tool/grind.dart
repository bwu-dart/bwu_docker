library bwu_docker.tool.grind;

import 'dart:io' as io;
import 'package:http/http.dart' as http;
import 'package:grinder/grinder.dart';
import 'package:bwu_docker/bwu_docker.dart';
import 'dart:async' show Future;

const sourceDirs = const ['bin', 'lib', 'tool', 'test', 'example'];
const dindPort = 3375;

main(List<String> args) => grind(args);

@Task('Run analyzer')
analyze() => _analyze();

@Task('Runn all tests')
test() => _test();

@Task('Check everything')
@Depends(analyze, /*checkFormat,*/ lint, test)
check() => _check();

// TODO(zoechi) fix when it's possible the check the outcome
//@Task('Check source code format')
//checkFormat() => checkFormatTask(['.']);

/// format-all - fix all formatting issues
@Task('Fix all source format issues')
formatAll() => _formatAll();

@Task('Run lint checks')
lint() => _lint();

_analyze() => new PubApp.global('tuneup').run(['check']);

Container _dindRemoteApiTest;
Container _dindTasksTest;

Uri _uriUpdatePort(Uri uri, int port) {
  final result = new Uri(
      scheme: uri.scheme, userInfo: uri.userInfo, host: uri.host, port: port);
  print('${result}');
  return result;
}

_test() async {
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
      Pub.downgrade();
      new PubApp.local('test').run(['-rexpanded'],
          environment: {
        dockerHostFromEnvironment:
            _uriUpdatePort(dockerHost, dindPort).toString()
      });
    } catch (_) {
      rethrow;
    } finally {
      Pub.upgrade();
    }
    new PubApp.local('test').run(['-rexpanded'],
        environment: {
      dockerHostFromEnvironment: _uriUpdatePort(dockerHost, dindPort).toString()
    });
  } catch (_) {
    rethrow;
  } finally {
    await _dindCleanupAfterTest(docker);
  }
}

_check() => run('pub', arguments: ['publish', '-n']);

_formatAll() => new PubApp.global('dart_style').run(['-w']..addAll(sourceDirs),
    script: 'format');

_lint() => new PubApp.global('linter')
    .run(['--stats', '-ctool/lintcfg.yaml']..addAll(sourceDirs));

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
