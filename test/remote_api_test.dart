@TestOn('vm')
library bwu_docker.test.docker;

import 'dart:io' show BytesBuilder;
import 'dart:async' show Future, Stream, StreamSubscription;
import 'dart:convert' show UTF8;
import 'package:bwu_utils_dev/testing_server.dart';
import 'package:bwu_docker/src/remote_api.dart';
import 'package:bwu_docker/src/data_structures.dart';

const imageName = 'selenium/standalone-chrome';
const imageVersion = '2.45.0';
const imageNameAndVersion = '${imageName}:${imageVersion}';

void main([List<String> args]) {
  initLogging(args);

  DockerConnection connection;
  CreateResponse createdResponse;

  final removeContainer = () async {
    if (createdResponse != null) {
      try {
        //print('--- remove --- ${createdResponse.container.id}');
        await connection.kill(createdResponse.container, signal: 'SIGKILL');
        await connection.remove(createdResponse.container, force: true);
      } catch (e) {
        print('--- remove --- ${createdResponse.container.id} failed - ${e}');
      }
    }
  };

  setUp(() {
    connection = new DockerConnection('localhost', 2375);
  });

  tearDown(() async {
    await removeContainer();
  });

  // Needs different setUp()
  group('', () {
    group('create', () {
      test('simple', () async {
        // exercise
        createdResponse = await connection
            .create(new CreateContainerRequest()..image = imageNameAndVersion);

        // verification
        expect(createdResponse.container, new isInstanceOf<Container>());
        expect(createdResponse.container.id, isNotEmpty);
      });

      test('with name', () async {
        // set up
        const containerName = '/dummy_name';

        // exercise
        createdResponse = await connection.create(
            new CreateContainerRequest()..image = imageNameAndVersion,
            name: 'dummy_name');
        expect(createdResponse.container, new isInstanceOf<Container>());
        expect(createdResponse.container.id, isNotEmpty);

        final Iterable<Container> containers =
            await connection.containers(filters: {'name': [containerName]});

        // verification
        expect(containers.length, greaterThan(0));
        expect(
            containers, everyElement((c) => c.names.contains(containerName)));
      }, skip: 'figure out why passing a name to `create` doesn\'t work.');
    });

    group('logs', () {
      test('simple', () async {
        // set up
        createdResponse = await connection.create(new CreateContainerRequest()
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
        }, onDone: () {
          if (!c.isCompleted) {
            c.complete();
          }
        });
        await c.future;

        print(buf.length);
        print(buf.toBytes());

        // verification
        expect(buf, isNotNull);
      }, skip: 'find a way to produce log output, currently the returned data is always empty');
    });

    group('start', () {
      test('simple', () async {
        // set up
        createdResponse = await connection
            .create(new CreateContainerRequest()..image = imageNameAndVersion);

        // exercise
        final SimpleResponse startedContainer =
            await connection.start(createdResponse.container);

        // verification
        expect(startedContainer, isNotNull);
        final Iterable<Container> containers = await connection.containers(
            filters: {'status': [ContainerStatus.running.toString()]});
        //print(containers.map((c) => c.toJson()).toList());

        expect(containers,
            anyElement((c) => c.id == createdResponse.container.id));
      });
    });
  });

  // with container started in setUp
  group('', () {
    setUp(() async {
      createdResponse = await connection
          .create(new CreateContainerRequest()..image = imageNameAndVersion);
      await connection.start(createdResponse.container);
      await new Future.delayed(const Duration(milliseconds: 100));
    });

    group('containers', () {
      test('simple', () async {
        // exercise
        Iterable<Container> containers = await connection.containers();

        // verification
        expect(containers, isNotEmpty);
        expect(containers.first.image, isNotEmpty);
        expect(containers, anyElement((c) => c.image == imageNameAndVersion));
      });

      test('all: true', () async {
        // set up
        String containerId = createdResponse.container.id;
        final Iterable<Container> containers =
            await connection.containers(all: true);
        expect(containers, isNotEmpty);
        expect(containers.first.image, isNotEmpty);
        expect(containers,
            anyElement((c) => c.id == createdResponse.container.id));

        await connection.kill(createdResponse.container, signal: 'SIGKILL');
        await connection.remove(createdResponse.container);
        createdResponse = null; // prevent remove again in tearDown

        // exercise
        final Iterable<Container> updatedContainers =
            await connection.containers(all: true);

        // verification
        expect(
            updatedContainers, isNot(anyElement((c) => c.id == containerId)));
        createdResponse = null;
      });
    });

    group('container', () {
      test('simple', () async {
        // exercise
        final ContainerInfo container =
            await connection.container(createdResponse.container);

        // verification
        expect(container, new isInstanceOf<ContainerInfo>());
        expect(container.id, createdResponse.container.id);
        expect(container.config.cmd, ['/opt/bin/entry_point.sh']);
        expect(container.config.image, imageNameAndVersion);
        expect(container.state.running, isTrue);
      });
    });

    group('top', () {
      test('simple', () async {
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
      });

      test('with ps_args', () async {
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
      });
    });

    group('changes', () {
      test('simple', () async {
        // exercise
        final ChangesResponse changesResponse =
            await connection.changes(createdResponse.container);

        // verification
        // TODO(zoechi) provoke some changes and check the result
        expect(changesResponse.changes.length, greaterThan(0));
        expect(changesResponse.changes,
            everyElement((c) => c.path.startsWith('/')));
        expect(changesResponse.changes, everyElement((c) => c.kind != null));
      });
    });

    group('export', () {
      test('simple', () async {
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
        }, onDone: () {
          if (!c.isCompleted) {
            c.complete();
          }
        });
        await c.future;

        // verification
        expect(buf.length, greaterThan(1000000));
        await new Future.delayed(const Duration(milliseconds: 500));
      });
    });

    group('stats', () {
      test('simple', () async {
        // exercise
        await connection.stats(createdResponse.container);

        // verification
        // TODO(zoechi)
      }, skip: 'check API version and skip the test when version < 1.17 when /info request is implemented');
    });

    group('resize', () {
      test('simple', () async {
        // exercise
        final SimpleResponse resizeResponse =
            await connection.resize(createdResponse.container, 60, 20);

        await connection.restart(createdResponse.container);
        final ContainerInfo containerResponse =
            await connection.container(createdResponse.container);

        // verification
        expect(resizeResponse, isNotNull);
        expect(containerResponse.state.running, isTrue);

        // TODO(zoechi) check the current tty size
      }, skip: 'no way found yet how to check the effect');
    });

    group('stop', () {
      test('simple', () async {
        // set up
        final ContainerInfo startedStatus =
            await connection.container(createdResponse.container);
        expect(startedStatus.state.running, isNotNull);

        final referenceTime = new DateTime.now().toUtc();

        // exercise
        final SimpleResponse stopResponse =
            await connection.stop(createdResponse.container);
        final ContainerInfo stoppedStatus =
            await connection.container(createdResponse.container);

        print(
            'ref: ${referenceTime} finishedAt: ${stoppedStatus.state.finishedAt}');
        // verification
        expect(stopResponse, isNotNull);
        expect(stoppedStatus.state.running, isFalse);
        expect(stoppedStatus.state.exitCode, isNot(0));
        // a bit flaky
        expect(stoppedStatus.state.finishedAt.millisecondsSinceEpoch,
            greaterThan(referenceTime.millisecondsSinceEpoch));
        expect(stoppedStatus.state.finishedAt.millisecondsSinceEpoch,
            lessThan(new DateTime.now().millisecondsSinceEpoch));
      });
    });

    group('restart', () {
      test('simple', () async {
        // set up
        final ContainerInfo startedStatus =
            await connection.container(createdResponse.container);
        expect(startedStatus.state.running, isNotNull);

        // exercise
        final SimpleResponse restartResponse =
            await connection.restart(createdResponse.container);
        await new Future.delayed(const Duration(milliseconds: 100), () {});
        final ContainerInfo restartedStatus =
            await connection.container(createdResponse.container);

        // verification
        expect(restartResponse, isNotNull);
        // I expected it to be true but [restarting] seems not to be set
        //expect(restartedStatus.state.restarting, isTrue);
        // TODO(zoechi) check why running is false after restarting
        expect(restartedStatus.state.running, isFalse);
        expect(restartedStatus.state.startedAt.millisecondsSinceEpoch,
            greaterThan(startedStatus.state.startedAt.millisecondsSinceEpoch));

        await new Future.delayed(const Duration(milliseconds: 100), () {});
      }, skip: 'restart seems not to work properly (also not at the console');
    });

    group('kill', () {
      test('simple', () async {
        // set up
        final ContainerInfo startedStatus =
            await connection.container(createdResponse.container);
        expect(startedStatus.state.running, isNotNull);

        final referenceTime = new DateTime.now().toUtc();

        // exercise
        final SimpleResponse killResponse =
            await connection.kill(createdResponse.container, signal: 'SIGKILL');
        await new Future.delayed(const Duration(milliseconds: 100), () {});
        final ContainerInfo killedStatus =
            await connection.container(createdResponse.container);

        print(
            'ref: ${referenceTime} finishedAt: ${killedStatus.state.finishedAt}');

        // verification
        expect(killResponse, isNotNull);
        expect(killedStatus.state.running, isFalse);
        expect(killedStatus.state.exitCode, -1);
        expect(killedStatus.state.finishedAt.millisecondsSinceEpoch,
            greaterThan(referenceTime.millisecondsSinceEpoch));
        expect(killedStatus.state.finishedAt.millisecondsSinceEpoch,
            lessThan(new DateTime.now().millisecondsSinceEpoch));
      });
    });

    group('rename', () {
      test('simple', () async {
        // set up
        final ContainerInfo startedStatus =
            await connection.container(createdResponse.container);
        expect(startedStatus.state.running, isNotNull);
        expect(startedStatus.name, isNot('SomeOtherName'));

        // exercise
        final SimpleResponse renameResponse =
            await connection.rename(createdResponse.container, 'SomeOtherName');
        final ContainerInfo renamedStatus =
            await connection.container(createdResponse.container);

        // verification
        expect(renameResponse, isNotNull);
        expect(renamedStatus.name, 'SomeOtherName');
      }, skip: 'execute test only if Docker API version is > 1.17');
    });

    group('pause', () {
      tearDown(() async {
        await connection.unpause(createdResponse.container);
        await new Future.delayed(const Duration(milliseconds: 100), () {});
      });
      test('simple', () async {
        // set up
        final ContainerInfo startedStatus =
            await connection.container(createdResponse.container);
        expect(startedStatus.state.running, isNotNull);

        // exercise
        final SimpleResponse pauseResponse =
            await connection.pause(createdResponse.container);
        final ContainerInfo pausedStatus =
            await connection.container(createdResponse.container);

        // verification
        expect(pauseResponse, isNotNull);
        expect(pausedStatus.state.paused, isTrue);
        expect(pausedStatus.state.running, isTrue);
      });
    });

    group('unpause', () {
      test('simple', () async {
        // set up
        final ContainerInfo startedStatus =
            await connection.container(createdResponse.container);
        expect(startedStatus.state.running, isNotNull);

        final SimpleResponse pauseResponse =
            await connection.pause(createdResponse.container);
        final ContainerInfo pausedStatus =
            await connection.container(createdResponse.container);

        expect(pauseResponse, isNotNull);
        expect(pausedStatus.state.paused, isTrue);
        expect(pausedStatus.state.running, isTrue);

        // exercise
        final SimpleResponse unpauseResponse =
            await connection.unpause(createdResponse.container);
        final ContainerInfo unpausedStatus =
            await connection.container(createdResponse.container);

        // verification
        expect(unpauseResponse, isNotNull);
        expect(unpausedStatus.state.paused, isFalse);
        expect(unpausedStatus.state.running, isTrue);
      });
    });

    group('attach', () {
      test('simple', () async {
        // exercise
        final Stream attachResponse = await connection.attach(
            createdResponse.container,
            logs: true, stream: true, stdin: true, stdout: true, stderr: true);
        final buf = new BytesBuilder(copy: false);
        StreamSubscription sub;
        Completer c = new Completer();
        sub = attachResponse.listen((data) {
          print(UTF8.decode(data));
          buf.add(data);
          if (buf.length > 1000) {
            sub.cancel();
            c.complete();
          }
        }, onDone: () {
          if (!c.isCompleted) {
            c.complete();
          }
        });
        await c.future;
        print(UTF8.decode(buf.takeBytes()));
        // verification
        expect(buf.length, greaterThan(1000));
      }, skip: 'available API version >= 1.17');
    });

    group('attachWs', () {
      test('simple', () async {
        // exercise
        final Stream attachResponse = await connection.attachWs(
            createdResponse.container,
            logs: true, stream: true, stdin: true, stdout: true, stderr: true);
        final buf = new BytesBuilder(copy: false);
        StreamSubscription sub;
        Completer c = new Completer();
        sub = attachResponse.listen((data) {
          print(UTF8.decode(data));
          buf.add(data);
          if (buf.length > 1000) {
            sub.cancel();
            c.complete();
          }
        }, onDone: () {
          if (!c.isCompleted) {
            c.complete();
          }
        });
        await c.future;
        print(UTF8.decode(buf.takeBytes()));
        // verification
        expect(buf.length, greaterThan(1000));
      }, skip: 'available API version >= 1.17 - and not yet implemented');
    });

    group('wait', () {
      test('simple', () async {
        // set up
        final ContainerInfo startedStatus =
            await connection.container(createdResponse.container);
        expect(startedStatus.state.running, isNotNull);

        final waitReturned = expectAsync(() {});

        // exercise
        connection.wait(createdResponse.container).then((response) {
          // verification
          expect(response, isNotNull);
          expect(response.statusCode, isNot(0));
          waitReturned();
        });

        // exercise
        await new Future.delayed(const Duration(milliseconds: 100), () {});
        await connection.stop(createdResponse.container);
      }, timeout: const Timeout(const Duration(seconds: 60)));
    });

    group('remove', () {
      test('simple', () async {
        // set up
        await connection.stop(createdResponse.container);

        // exercise
        await connection.remove(createdResponse.container);

        // verification
        expect(connection.container(createdResponse.container), throws);

        // tear down
        createdResponse = null; // prevent removing again in tearDown
      }, timeout: const Timeout(const Duration(seconds: 60)));
    });
  });
}
