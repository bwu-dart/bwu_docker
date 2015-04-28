@TestOn('vm')
library bwu_docker.test.docker;

import 'dart:io' show BytesBuilder;
import 'dart:async' show Future, Stream, StreamSubscription;
import 'package:bwu_utils_dev/testing_server.dart';
import 'package:bwu_docker/src/remote_api.dart';
import 'package:bwu_docker/src/data_structures.dart';

const imageName = 'selenium/standalone-chrome';
const imageVersion = '2.45.0';
const imageNameAndVersion = '${imageName}:${imageVersion}';

void main([List<String> args]) {
  initLogging(args);

  DockerConnection connection;
  setUp(() {
    connection = new DockerConnection('localhost', 2375);
  });

  group('containers', () {
    test('simple', () async {
      // set up
      final CreateResponse createdResponse = await connection
          .create(new CreateContainerRequest()..image = imageNameAndVersion);
      await connection.start(createdResponse.container);

      // exercise
      Iterable<Container> containers = await connection.containers();

      // verification
      expect(containers, isNotEmpty);
      expect(containers.first.image, isNotEmpty);
      expect(containers, anyElement((c) => c.image == imageNameAndVersion));

      // tear down
      return connection.stop(createdResponse.container);
      // TODO(zeochi) remove createdResponse
    });

    test('all argument', () async {
      // set up
      final CreateResponse createdResponse = await connection
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
      return connection.stop(createdResponse.container);
      // TODO(zeochi) remove createdResponse
    });
  });

  group('create', () {
    test('simple', () async {
      // set up

      // exercise
      final CreateResponse createdResponse = await connection
          .create(new CreateContainerRequest()..image = imageNameAndVersion);

      // verification
      expect(createdResponse.container, new isInstanceOf<Container>());
      expect(createdResponse.container.id, isNotEmpty);

      // tear down
      return connection.stop(createdResponse.container);
    });

    test('with name', () async {
      // set up
      const containerName = '/dummy_name';
      // exercise
      final CreateResponse createdResponse = await connection.create(
          new CreateContainerRequest()..image = imageNameAndVersion,
          name: 'dummy_name');
      expect(createdResponse.container, new isInstanceOf<Container>());
      expect(createdResponse.container.id, isNotEmpty);

      final Iterable<Container> containers =
          await connection.containers(filters: {'name': [containerName]});
      //print(containers.map((c) => c.toJson()).toList());

      // verification
      expect(containers.length, greaterThan(0));
      containers.forEach((c) => print(c.toJson()));
      expect(containers, everyElement((c) => c.names.contains(containerName)));

      // tear down
      return connection.stop(createdResponse.container);
    }, skip: 'figure out how to pass a name to `create`.');
  });

  group('container', () {
    test('simple', () async {
      // set up

      final CreateResponse createdResponse = await connection
          .create(new CreateContainerRequest()..image = imageNameAndVersion);
      expect(createdResponse.container, new isInstanceOf<Container>());
      expect(createdResponse.container.id, isNotEmpty);
      await connection.start(createdResponse.container);

      // exercise
      final ContainerInfo container =
          await connection.container(createdResponse.container);

      // verification
      expect(container, new isInstanceOf<ContainerInfo>());
//      print(container.toJson());
      expect(container.id, createdResponse.container.id);
      expect(container.config.cmd, ['/opt/bin/entry_point.sh']);
      expect(container.config.image, imageNameAndVersion);
      expect(container.state.running, isTrue);

      // tear down
      return connection.stop(createdResponse.container);
    });
  });

  group('top', () {
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
      return connection.stop(createdResponse.container);
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
      return connection.stop(createdResponse.container);
    });
  });

  group('logs', () {
    test('simple', () async {
      // set up
      final CreateResponse createdResponse = await connection.create(
          new CreateContainerRequest()
        ..image = imageNameAndVersion
        ..hostConfig.logConfig = {'Type': 'json-file'});
      final SimpleResponse startedContainer =
          await connection.start(createdResponse.container);
      expect(startedContainer, isNotNull);

      // exercise
      Stream log = await connection.logs(createdResponse.container,
          stdout: true,
          stderr: true,
          timestamps: true,
          follow: false,
          tail: 10);
      final buf = new BytesBuilder(copy: false);
      StreamSubscription sub;
      Completer c = new Completer();
      sub = log.listen((data) {
        buf.add(data);
        if (buf.length > 100) {
          sub.cancel();
          c.complete();
        }
      });
      await c.future;

      print(buf.length);
      print(buf.toBytes());

      // verification
      expect(buf, isNotNull);

      // tear down
      return connection.stop(createdResponse.container);
    }, skip: 'find a way to produce log output, currently the returned data is always empty');
  });

  group('changes', () {
    test('simple', () async {
      // set up
      final CreateResponse createdResponse = await connection.create(
          new CreateContainerRequest()
        ..image = imageNameAndVersion
        ..hostConfig.logConfig = {'Type': 'json-file'});
      final SimpleResponse startedContainer =
          await connection.start(createdResponse.container);
      expect(startedContainer, isNotNull);

      await new Future.delayed(const Duration(milliseconds: 100));

      // exercise
      final ChangesResponse changesResponse =
          await connection.changes(createdResponse.container);

      // print(changesResponse.toJson());

      // verification
      // TODO(zoechi) provoke some changes and check the result
      expect(changesResponse.changes.length, greaterThan(0));
      expect(
          changesResponse.changes, everyElement((c) => c.path.startsWith('/')));
      expect(changesResponse.changes, everyElement((c) => c.kind != null));

      // tear down
      return connection.stop(createdResponse.container);
    });
  });

  group('export', () {
    test('simple', () async {
      // set up
      final CreateResponse createdResponse = await connection.create(
          new CreateContainerRequest()
        ..image = imageNameAndVersion
        ..hostConfig.logConfig = {'Type': 'json-file'});
      final SimpleResponse startedContainer =
          await connection.start(createdResponse.container);
      expect(startedContainer, isNotNull);

      // exercise
      final Stream exportResponse =
          await connection.export(createdResponse.container);
      final buf = new BytesBuilder(copy: false);
      StreamSubscription sub;
      Completer c = new Completer();
      sub = exportResponse.listen((data) {
        buf.add(data);
        if (buf.length > 1000000) {
          sub.cancel();
          c.complete();
        }
      });
      await c.future;

      // verification
      expect(buf.length, greaterThan(1000000));

      // tear down
      return connection.stop(createdResponse.container);
    });
  });

  group('stats', () {
    test('simple', () async {
      // set up
      final CreateResponse createdResponse = await connection.create(
          new CreateContainerRequest()
        ..image = imageNameAndVersion
        ..hostConfig.logConfig = {'Type': 'json-file'});
      final SimpleResponse startedContainer =
          await connection.start(createdResponse.container);
      expect(startedContainer, isNotNull);

      //await new Future.delayed(const Duration(milliseconds: 100));

      // exercise
      final StatsResponse statsResponse =
          await connection.stats(createdResponse.container);

      // print(statsResponse.toJson());

      // verification
      // TODO(zoechi)

      // tear down
      return connection.stop(createdResponse.container);
    }, skip: 'check API version and skip the test when version < 1.17 when /info request is implemented');
  });

  group('resize', () {
    test('simple', () async {
      // set up
      final CreateResponse createdResponse = await connection.create(
          new CreateContainerRequest()
        ..image = imageNameAndVersion
        ..hostConfig.logConfig = {'Type': 'json-file'});
      final SimpleResponse startedContainer =
          await connection.start(createdResponse.container);
      expect(startedContainer, isNotNull);

      //await new Future.delayed(const Duration(milliseconds: 100));

      // exercise
      final SimpleResponse resizeResponse =
          await connection.resize(createdResponse.container, 60, 20);

      // TODO(zoechi) restart

      final ContainerInfo containerInfo =
          await connection.container(createdResponse.container);

      // verification
      expect(resizeResponse, isNotNull);

      // tear down
      return connection.stop(createdResponse.container);
    }, skip: 'check result after restart is implemented and when there is a way to check the effect');
  });

  group('start', () {
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
      return connection.stop(createdResponse.container);
    });
  });

  group('stop', () {
    test('simple', () async {
      // set up
      final CreateResponse createdResponse = await connection
          .create(new CreateContainerRequest()..image = imageNameAndVersion);
      final SimpleResponse startedContainer =
          await connection.start(createdResponse.container);
      expect(startedContainer, isNotNull);
      await new Future.delayed(const Duration(milliseconds: 100), () {});
      final ContainerInfo startedStatus =
          await connection.container(createdResponse.container);
      expect(startedStatus.state.running, isNotNull);

      final referenceTime = new DateTime.now().toUtc();

      // exercise
      final SimpleResponse stoppedResponse =
          await connection.stop(createdResponse.container);
      final ContainerInfo stoppedStatus =
          await connection.container(createdResponse.container);

      // verification
      expect(stoppedResponse, isNotNull);
      expect(stoppedStatus.state.running, isFalse);
      expect(stoppedStatus.state.exitCode,
          isNot(0));
      expect(stoppedStatus.state.finishedAt.millisecondsSinceEpoch,
          greaterThan(referenceTime.millisecondsSinceEpoch));
      expect(stoppedStatus.state.finishedAt.millisecondsSinceEpoch,
          lessThan(new DateTime.now().millisecondsSinceEpoch));

      // tear down
      return connection.stop(createdResponse.container);
    });
  });
}
