library bwu_docker.tool.grind;

import 'dart:async' show Future;
import 'dart:io' as io;
import 'package:bwu_docker/bwu_docker.dart';
//import 'package:bwu_docker/tasks.dart' as task;
export 'package:bwu_grinder_tasks/bwu_grinder_tasks.dart' hide main, testWeb;
import 'package:bwu_grinder_tasks/bwu_grinder_tasks.dart'
    show
        doInstallContentShell,
        grind,
        coverageTask,
        testTask,
        travisPrepareTask;
import 'package:grinder/grinder.dart';
import 'package:http/http.dart' as http;
//import 'package:stack_trace/stack_trace.dart';

// _dindPort2 is `_dindPort1 + 1`
const int _dindPort1 = 3375;
const String _dindImageName = 'docker'; // https://hub.docker.com/_/docker/

void main(List<String> args) {
  doInstallContentShell = false;
  testTask = ([_]) => _testTaskImpl();
  // Disable test when run on Travis
  travisPrepareTask = () => testTask = ([_]) {};
  grind(args);
}

DockerConnection _dockerConnection;

// TODO(zoechi) attempt to use the `run` task but it misses some features
//@Task('Start Docker (DIND)')
//startDocker() async {
//  _dockerConnection = new DockerConnection(
//      Uri.parse(io.Platform.environment[dockerHostFromEnvironment]),
//      new http.Client());
//  await _dockerConnection.init();
//  await task.run(_dockerConnection, _dindImageName,
//        name: 'remote_api_test',
//        hostName: 'remote_api_test',
//        publish: const ['${_dindPort1}:${_dindPort1}'],
//        privileged: true,
//        rm: true);
//
//  await task.run(_dockerConnection, _dindImageName,
//        name: 'task_test',
//        hostName: 'task_test',
//        publish: const ['${_dindPort1 + 1}:${_dindPort1 + 1}'],
//        privileged: true,
//        rm: true);
//
//}

@Task('Start Docker(DIND)')
dynamic startDocker() async {
  final Uri dockerHost = _dockerHost();
  print(dockerHost);
  DockerConnection docker = new DockerConnection(dockerHost, new http.Client());
  await docker.init();
  await _dindStartForTest(docker);
}

Container _dindRemoteApiTest;
Container _dindTasksTest;

/// Copy the [uri] and replace the port with [port].
Uri _uriUpdatePort(Uri uri, int port) {
  final Uri result = new Uri(
      scheme: uri.scheme, userInfo: uri.userInfo, host: uri.host, port: port);
  print('${result}');
  return result;
}

Uri _dockerHost() {
  final String dockerHostStr =
      io.Platform.environment[dockerHostFromEnvironment];
  if (dockerHostStr == null || dockerHostStr.isEmpty) {
    fail(
        'To run the tests the environment variable "${dockerHostFromEnvironment}" '
        'must point to a Docker instance which exposes an HTTP port. \n'
        'For example "export DOCKER_HOST_REMOTE_API=http://localhost:2375".');
  }
  return Uri.parse(dockerHostStr);
}

dynamic _testTaskImpl() async {
  final Uri dockerHost = _dockerHost();

  DockerConnection docker = new DockerConnection(dockerHost, new http.Client());
  await docker.init();
  try {
    await _dindStartForTest(docker);
    new PubApp.local('test').run(['-rexpanded', '-j1'],
        runOptions: new RunOptions(environment: {
          dockerHostFromEnvironment:
              _uriUpdatePort(dockerHost, _dindPort1).toString()
        }));
  } catch (_) {
    rethrow;
  } finally {
    await _dindCleanupAfterTest(docker);
  }
}

/// Prepare Docker-in-Docker instances for running tests.
Future _dindStartForTest(DockerConnection docker) async {
  await _dindCreateContainer(docker, _dindPort1).then /*<Container>*/ (
      (dynamic container) => _dindRemoteApiTest = container);
  await _dindCreateContainer(docker, _dindPort1 + 1)
      .then /*<Container>*/ ((dynamic container) => _dindTasksTest = container);
}

/// Create and start a Docker-in-Docker container.
Future<Container> _dindCreateContainer(
    DockerConnection docker, int port) async {
  try {
    await docker.image(new Image(_dindImageName));
  } on DockerRemoteApiError {
    await docker.createImage(_dindImageName);
//    for (var e in createResponse) {
//      print('${e.status} - ${e.progressDetail}');
//    }
  }
  final HostConfigRequest hostConfig = new HostConfigRequest()
    ..privileged = true
    ..publishAllPorts = false
    ..portBindings = {
      '${port}/tcp': [new PortBindingRequest()..hostPort = '${port}']
    };

  CreateResponse response =
      await docker.createContainer(new CreateContainerRequest()
        ..hostName = 'remote_api_test'
        ..image = _dindImageName
        ..exposedPorts = {'${port}/tcp': {}}
        ..env = {'PORT': '${port}'}
        ..attachStdin = true
        ..attachStdout = false
        ..attachStderr = false
        ..tty = true
        ..openStdin = false
        ..stdinOnce = false
        ..hostConfig = hostConfig);

  // try several times to work around https://github.com/jpetazzo/dind/issues/19
  bool isRunning = false;
  int tryStartCount = 5;
  ContainerInfo containerInfo;
  while (!isRunning && tryStartCount > 0) {
    await docker.start(response.container, hostConfig: hostConfig);
    await new Future.delayed(const Duration(milliseconds: 2000));
    containerInfo = await docker.container(response.container);
    isRunning = containerInfo.state.running == true;
//    print('tryStartCount $tryStartCount - isRunning: $isRunning');
    if (!isRunning) {
      await new Future.delayed(const Duration(seconds: 3));
      tryStartCount--;
    }
  }
  if (!isRunning) {
    throw 'Docker container didn\'t start - message: "${(await docker.logs(response.container, stdout: true, stderr: true)).toList()}" - exitcode "${containerInfo.state.exitCode}".';
  }
  return response.container;

// Wire-log from `docker run`
//'''
//{"Privileged":true,"PortBindings":{"1234/tcp":[{"HostIp":"","HostPort":"1234"}]},"PublishAllPorts":false,"NetworkMode":"bridge"}
//{"Binds":null,"ContainerIDFile":"","LxcConf":[],"Privileged":true,"PortBindings":{"1234/tcp":[{"HostIp":"","HostPort":"1234"}]},"Links":null,"PublishAllPorts":false,"Dns":null,"DnsSearch":null,"ExtraHosts":null,"VolumesFrom":null,"Devices":[],"NetworkMode":"bridge","CapAdd":null,"CapDrop":null,"RestartPolicy":{"Name":"","MaximumRetryCount":0},"SecurityOpt":null}
//'''
}

/// Remove Docker-in-Docker containers after tests are done.
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
