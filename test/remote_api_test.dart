@TestOn('vm')
library bwu_docker.test.docker;

import 'dart:io' as io;
import 'package:bwu_utils/bwu_utils_server.dart';
import 'package:bwu_utils_dev/testing_server.dart';
import 'package:bwu_docker/src/remote_api.dart';
import 'package:bwu_docker/src/data_structures.dart';

const imageName = 'selenium/standalone-chrome';
const imageVersion = '2.45.0';
const imageNameAndVersion = '${imageName}:${imageVersion}';

void main([List<String> args]) {
  initLogging(args);

  group('containers', () {
    DockerConnection connection;
    setUp(() {
      connection = new DockerConnection('localhost', 2375);
    });

    test('simple', () async {
      // set up
      final createdContainer = await connection
          .create(new CreateContainerRequest()..image = imageNameAndVersion);
      await connection.start(createdContainer.container);

      // exercise
      Iterable<Container> containers = await connection.containers();

      // verification
      expect(containers, isNotEmpty);
      expect(containers.first.image, isNotEmpty);
      expect(containers, anyElement((c) => c.image == imageNameAndVersion));

      // tear down
      // TODO(zeochi) remove createdContainer
    });

    test('all argument', () async {
      // set up
      final createdContainer = await connection
          .create(new CreateContainerRequest()..image = imageNameAndVersion);

      // exercise
      final Iterable<Container> containers =
          await connection.containers(all: true);

      // verification
      expect(containers, isNotEmpty);
      expect(containers.first.image, isNotEmpty);
      expect(containers, anyElement((c) => c.image == imageNameAndVersion));
      // TODO(zeochi) stop container and check if it is still listed

      // tear down
      // TODO(zeochi) remove createdContainer
    });
  });

  group('create', () {
    DockerConnection connection;
    setUp(() {
      connection = new DockerConnection('localhost', 2375);
    });

    test('simple', () async {
      // set up

      // exercise
      final response = await connection
          .create(new CreateContainerRequest()..image = imageNameAndVersion);

      // verification
      expect(response.container, new isInstanceOf<Container>());
      expect(response.container.id, isNotEmpty);

      // tear down
    });

    test('with name', () async {
      // set up
      const containerName = '/dummy_name';
      // exercise
      final CreateResponse createdContainer = await connection.create(
          new CreateContainerRequest()..image = imageNameAndVersion,
          name: 'dummy_name');
      expect(createdContainer.container, new isInstanceOf<Container>());
      expect(createdContainer.container.id, isNotEmpty);

      final Iterable<Container> containers =
          await connection.containers(filters: {'name': [containerName]});
      //print(containers.map((c) => c.toJson()).toList());

      // verification
      expect(containers.length, greaterThan(0));
      containers.forEach((c) => print(c.toJson()));
      expect(containers, everyElement((c) => c.names.contains(containerName)));

      // tear down
    }, skip: 'figure out how to pass a name to `create`.');
  });

  group('container', () {
    DockerConnection connection;
    setUp(() {
      connection = new DockerConnection('localhost', 2375);
    });
    test('simple', () async {
      // set up

      // exercise
      final CreateResponse response = await connection
          .create(new CreateContainerRequest()..image = imageNameAndVersion);
      expect(response.container, new isInstanceOf<Container>());
      expect(response.container.id, isNotEmpty);
      await connection.start(response.container);
      final ContainerInfo container =
          await connection.container(response.container);

      // verification
      expect(container, new isInstanceOf<ContainerInfo>());
      print(container.toJson());
      expect(container.id, response.container.id);
      expect(container.config.cmd, ['/opt/bin/entry_point.sh']);
      expect(container.config.image, imageNameAndVersion);
      expect(container.state.running, isTrue);

      // tear down
    });
  });

  group('start', () {
    DockerConnection connection;
    setUp(() {
      connection = new DockerConnection('localhost', 2375);
    });
    test('simple', () async {
      // set up
      final CreateResponse createdResponse = await connection
          .create(new CreateContainerRequest()..image = imageNameAndVersion);

      // exercise
      final SimpleResponse startedContainer =
          await connection.start(createdResponse.container);

      // verification
      expect(startedContainer, isNotNull);
      final Iterable<Container> containers = await connection.containers(
          filters: {'status': [ContainerStatus.running.toString()]});
      //print(containers.map((c) => c.toJson()).toList());

      expect(
          containers, anyElement((c) => c.id == createdResponse.container.id));

      // tear down
    });
  });

  group('top', () {
    DockerConnection connection;
    setUp(() {
      connection = new DockerConnection('localhost', 2375);
    });
    test('simple', () async {
      // set up
      final CreateResponse createdResponse = await connection
          .create(new CreateContainerRequest()..image = imageNameAndVersion);
      final SimpleResponse startedContainer =
          await connection.start(createdResponse.container);
      expect(startedContainer, isNotNull);

      // exercise
      final TopResponse topResponse =
          await connection.top(createdResponse.container);

      // verification
      const titles = const [
        'UID',
        'PID',
        'PPID',
        'C',
        'STIME',
        'TTY',
        'TIME',
        'CMD'
      ];
      expect(topResponse.titles, orderedEquals(titles));
      expect(topResponse.processes.length, greaterThan(0));
      expect(topResponse.processes, anyElement((e) =>
          e.any((i) => i.contains('/bin/bash /opt/bin/entry_point.sh'))));

      // tear down
    });

    test('with ps_args', () async {
      // set up
      final CreateResponse createdResponse = await connection
          .create(new CreateContainerRequest()..image = imageNameAndVersion);
      final SimpleResponse startedContainer =
          await connection.start(createdResponse.container);
      expect(startedContainer, isNotNull);

      // exercise
      final TopResponse topResponse =
          await connection.top(createdResponse.container, psArgs: 'aux');

      // verification
      const titles = const [
        'USER',
        'PID',
        '%CPU',
        '%MEM',
        'VSZ',
        'RSS',
        'TTY',
        'STAT',
        'START',
        'TIME',
        'COMMAND'
      ];
      expect(topResponse.titles, orderedEquals(titles));
      expect(topResponse.processes.length, greaterThan(0));
      expect(topResponse.processes, anyElement((e) =>
          e.any((i) => i.contains('/bin/bash /opt/bin/entry_point.sh'))));

      // tear down
    });
  });

  group('logs', () {
    DockerConnection connection;
    setUp(() {
      connection = new DockerConnection('localhost', 2375);
    });
    test('xxx', () async {
      // set up
      final CreateResponse createdResponse = await connection.create(
          new CreateContainerRequest()
        ..image = imageNameAndVersion
        ..hostConfig.logConfig = {'Type': 'json-file'});
      final SimpleResponse startedContainer =
          await connection.start(createdResponse.container);
      expect(startedContainer, isNotNull);

      // exercise
      final LogResponse logResponse = await connection.logs(
          createdResponse.container,
          stdout: true, stderr: true, timestamps: true, follow: false, tail: 10);

      print(logResponse);
      // verification
//      expect(topResponse.processes.length, greaterThan(0));
//      expect(topResponse.processes, anyElement((e) =>
//          e.any((i) => i.contains('/bin/bash /opt/bin/entry_point.sh'))));

      // tear down
    }, skip: 'find a way to produce log output, currently the return value is always null');
  });
}
