@TestOn('vm')
library bwu_docker.test.docker;

import 'dart:io' as io;
import 'dart:convert' show JSON, UTF8;
import 'dart:async' show Completer, Future, Stream, StreamSubscription;
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:bwu_docker/src/remote_api.dart';
import 'package:bwu_docker/src/data_structures.dart';
import 'utils.dart' as utils;

//const imageName = 'selenium/standalone-chrome';
//const imageTag = '2.45.0';
//const entryPoint = '/opt/bin/entry_point.sh';
//const runningProcess = '/bin/bash ${entryPoint}';
//const dockerPort = 2375;

// Docker-in-Docker to allow to test with different Docker version
// docker run --privileged -d -p 1234:1234 -e PORT=1234 docker
// jpetazzo/dind became docker
// // docker run --privileged -d -p 1234:1234 -e PORT=1234 jpetazzo/dind
// See also https://github.com/bwu-dart/bwu_docker/wiki/Development-tips-&-tricks#run-docker-inside-docker
const String imageName = 'busybox';
const String imageTag = 'buildroot-2014.02';
const String entryPoint = '/bin/sh';
const String runningProcess = '/bin/sh';
const String imageNameAndTag = '${imageName}:${imageTag}';

String envDockerHost;

dynamic main([List<String> args]) async {
  envDockerHost = io.Platform.environment[dockerHostFromEnvironment];
  if (envDockerHost == null) {
    throw '$dockerHostFromEnvironment must be set in ENV';
  }

  DockerConnection connection =
      new DockerConnection(Uri.parse(envDockerHost), new http.Client());
  await connection.init();

  // Run tests for each [RemoteApiVersion] supported by this package and
  // supported by the Docker service.
  for (RemoteApiVersion remoteApiVersion in RemoteApiVersion.versions) {
    group(remoteApiVersion.toString(), () => tests(remoteApiVersion),
        skip: remoteApiVersion > connection.remoteApiVersion
            ? remoteApiVersion.toString()
            : false);
  }
}

void tests(RemoteApiVersion remoteApiVersion) {
  DockerConnection connection;
  Container createdContainer;

  /// setUp helper to create the image used in tests if it is not yet available.
  Future ensureImageExists () async {
    return utils.ensureImageExists(connection, imageNameAndTag);
  };

  /// setUp helper to create a container from the image used in tests.
  Future createContainer() async {
    createdContainer =
        (await connection.createContainer(new CreateContainerRequest()
          ..image = imageNameAndTag
          ..cmd = ['/bin/sh']
          ..attachStdin = false
          ..attachStdout = true
          ..attachStderr = true
          ..openStdin = false
          ..stdinOnce = false
          ..tty = true
          ..hostConfig.logConfig = <String,String>{'Type': 'json-file'})).container;
  };

  /// tearDown helper to remove the container created in setUp
  Future removeContainer() async {
    await utils.removeContainer(connection, createdContainer);
    createdContainer = null;
  };

  setUp(() async {
    connection = new DockerConnection.useRemoteApiVersion(
        Uri.parse(envDockerHost), remoteApiVersion, new http.Client());
    await connection.init();
    assert(connection.dockerVersion != null);
    await ensureImageExists();
  });

  tearDown(() async {
    await removeContainer();
  });

  /// If the used Docker image is not available the download takes some time and
  /// makes the first test time out. This is just to prevent this timeout.
  group('((prevent timeout))', () {
    setUp(() => ensureImageExists());

    test('((dummy))', () {
    }, timeout: const Timeout(const Duration(seconds: 300)));
  });

  group('containers', () {
    group('create', () {
      test('should create a new container', () async {
        // exercise
        await createContainer();

        // verification
        expect(createdContainer, new isInstanceOf<Container>());
        expect(createdContainer.id, isNotEmpty);
      });

      test('should create a new container with an assigned name', () async {
        // set up
        const containerName = '/dummy_name';

        final Iterable<Container> alreadyExisting =
            await connection.containers(filters: {
          'name': [containerName]
        }, all: true);
        alreadyExisting
            .where((c) => c.names.contains(containerName))
            .forEach((c) {
          connection.removeContainer(new Container(c.id));
        });
        await utils.waitMilliseconds(100);

        // exercise
        createdContainer = (await connection.createContainer(
            new CreateContainerRequest()..image = imageNameAndTag,
            name: 'dummy_name')).container;
        await utils.waitMilliseconds(100);
//          print(createdContainer.id);

        // verification
        expect(createdContainer, new isInstanceOf<Container>());
        expect(createdContainer.id, isNotEmpty);

        final Iterable<Container> containers =
            await connection.containers(filters: {
          'name': [containerName]
        }, all: true);

        expect(containers.length, greaterThan(0));
        expect(
            containers, everyElement((c) => c.names.contains(containerName)));
      },
          skip: remoteApiVersion < RemoteApiVersion.v1_17
              ? remoteApiVersion.toString()
              : false);
    });

    group('logs', () {
      setUp(() async {
        await ensureImageExists();
        await createContainer();
        // produce some log output - TODO(zoechi) find a better way
        await connection.start(createdContainer);
        await connection.restart(createdContainer);
        await connection.kill(createdContainer, signal: 'SIGKILL');
        final startedContainer = await connection.start(createdContainer);

        expect(startedContainer, isNotNull);
      });

      test('should receive log output', () async {
        // exercise
        Stream log = await connection.logs(createdContainer,
            stdout: true,
            stderr: true,
            timestamps: true,
            follow: false,
            tail: 10);
        final buf = new io.BytesBuilder(copy: false);
        final sub = log.take(100).listen(buf.add);

        await sub.asFuture();

        // verification
        expect(buf, isNotEmpty);
      });

      test('should receive log output after a specific time', () async {
        // set up
        Stream log = await connection.logs(createdContainer,
            stdout: true,
            stderr: true,
            timestamps: true,
            follow: false,
            tail: 10);
        final buf = new io.BytesBuilder(copy: false);
        final sub = log.take(100).listen(buf.add);

        await sub.asFuture();

        expect(buf.isNotEmpty, isTrue);

        // exercise
        Stream logSince = await connection.logs(createdContainer,
            stdout: true,
            stderr: true,
            since: new DateTime.now()..add(const Duration(seconds: 1)),
            timestamps: true,
            follow: false,
            tail: 10);
        final bufSince = new io.BytesBuilder(copy: false);
        final subSince = logSince.take(100).listen(bufSince.add);

        await subSince.asFuture();

        // verification
//        if (bufSince.isNotEmpty) {
// TODO(zoechi) this check is flaky. Find out why it sometimes contains log output
// when it shouldn't
//          print('x');
//        }
        expect(bufSince.isEmpty, isTrue);
      },
          skip: remoteApiVersion < RemoteApiVersion.v1_19
              ? remoteApiVersion.toString()
              : false);
    });

    group('start', () {
      setUp(() async {
        await ensureImageExists();
        await createContainer();
      });

      test('should start the container', () async {
        // exercise
        final SimpleResponse startedContainer =
            await connection.start(createdContainer);
        await utils.waitMilliseconds(100);

        // verification
        expect(startedContainer, isNotNull);
        final Iterable<Container> containers =
            await connection.containers(filters: {
          'status': [ContainerStatus.running.toString()]
        });

        expect(containers, anyElement((c) => c.id == createdContainer.id));
      }, timeout: const Timeout(const Duration(seconds: 100)));
    });

    group('commit', () {
      setUp(() async {
        await ensureImageExists();
        await createContainer();
      });

      test('should create a new image from the containers changes', () async {
        // set up
        final SimpleResponse startedContainer =
            await connection.start(createdContainer);
        expect(startedContainer, isNotNull);

        // exercise
        final CommitResponse commitResponse = await connection.commit(
            new CommitRequest(
                attachStdout: true,
                cmd: ['date'],
                volumes: new Volumes()..add('/tmp', {}),
                exposedPorts: {'22/tcp': {}}),
            createdContainer,
            tag: 'commitTest',
            comment: 'remove',
            author: 'someAuthor');

        // verification
        expect(commitResponse.id, isNotEmpty);
//          print(commitResponse.id);

        final ImageInfo committedContainer =
            await connection.image(new Image(commitResponse.id));

        expect(committedContainer.author, 'someAuthor');
        expect(
            committedContainer.config.exposedPorts.keys, anyElement('22/tcp'));

        await connection.removeImage(new Image(commitResponse.id));
      });
    });

    // with container started in setUp
    group('', () {
      setUp(() async {
        await createContainer();
//        createdContainer = await connection.createContainer(
//            new CreateContainerRequest()
//          ..image = imageNameAndTag
//          ..openStdin = true
//          ..tty = true);
        await connection.start(createdContainer);
        await utils.waitMilliseconds(100);
      });

      group('containers', () {
        test('should return the list of all running containers', () async {
          // exercise
          Iterable<Container> containers = await connection.containers();

          // verification
          expect(containers, isNotEmpty);
          expect(containers.first.image, isNotEmpty);
          expect(containers, anyElement((Container c) => c.image == imageNameAndTag));
        });

        test('should return the list of containers including status exited',
            () async {
          // set up
          final Iterable<Container> containers = await connection.containers();
          expect(containers, isNotEmpty);
          expect(containers.first.image, isNotEmpty);
          expect(containers, anyElement((Container c) => c.id == createdContainer.id));

          await connection.stop(createdContainer);

          // exercise
          final Iterable<Container> updatedContainers =
              await connection.containers(all: true);

          // verification
          final Container stoppedContainer =
              updatedContainers.firstWhere((Container c) => c.id == createdContainer.id);

          expect(stoppedContainer.status, startsWith('Exited'));
        });

        test('should return the list of exited containers', () async {
          // set up
          final SimpleResponse startedResponse =
              await connection.start(createdContainer);
          expect(startedResponse, isNotNull);

          await utils.waitMilliseconds(100);

          final Iterable<Container> exitedContainers =
              await connection.containers(filters: {
            'status': ['exited']
          });

          expect(exitedContainers, isEmpty);

          // exercise
          await connection.stop(createdContainer);

          await utils.waitMilliseconds(100);

          final Iterable<Container> updatedContainers =
              await connection.containers(filters: {
            'status': ['exited']
          });

          // verification
          expect(updatedContainers, isNotEmpty);
          expect(updatedContainers.first.image, isNotEmpty);
          expect(updatedContainers,
              anyElement((c) => c.id == createdContainer.id));
        });
      });

      group('container', () {
        test('should return detail information about the container', () async {
          // exercise
          final ContainerInfo container =
              await connection.container(createdContainer);
          await connection.start(createdContainer);
          await utils.waitMilliseconds(500);

          // verification
          expect(container, new isInstanceOf<ContainerInfo>());
          expect(container.id, createdContainer.id);
          expect(container.config.cmd, [entryPoint]);
          expect(container.config.image, imageNameAndTag);
          expect(container.state.running, isTrue);
        });
      });

      group('top', () {
        test('should return the list of active processes in the container',
            () async {
          // exercise
          final TopResponse topResponse =
              await connection.top(createdContainer);

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
          expect(topResponse.processes,
              anyElement((e) => e.any((i) => i.contains(runningProcess))));
        });

        test(
            'should return the list of active processes with customized "ps" arguments',
            () async {
          // exercise
          final TopResponse topResponse =
              await connection.top(createdContainer, psArgs: 'aux');

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
          expect(topResponse.processes,
              anyElement((e) => e.any((i) => i.contains(runningProcess))));
        });
      });

      group('changes', () {
        test('should return a list of changes in the container', () async {
          // set up
          final Exec createdExec = await connection.execCreate(createdContainer,
              attachStdin: false,
              attachStdout: true,
              attachStderr: true,
              tty: true,
              cmd: [
                '/bin/sh',
                '-c',
                'echo sometext > /tmp/somefile.txt',
                '/bin/sh',
                '-c',
                'ls -la'
              ]);
          //cmd: ['echo hallo']);
          final startResponse = await connection.execStart(createdExec);

          await for (var _ in startResponse.stdout) {
// only for debugging purposes (otherwise spams the test log output)
//            print('stdout: ${UTF8.decode(_)}');
          }
          await for (var _ in startResponse.stderr) {
// only for debugging purposes (otherwise spams the test log output)
//            print('stderr: ${UTF8.decode(_)}');
          }

          await utils.waitMilliseconds(1500); // TODO(zoechi) check if necessary

          // exercise
          final ChangesResponse changesResponse =
              await connection.changes(createdContainer);
//          print('changes: ${changesResponse.changes}');

          // verification
          // TODO(zoechi) provoke some changes and check the result
          // expect(changesResponse.changes.length, greaterThan(0));
          expect(changesResponse.changes,
              everyElement(( c) => c.path.startsWith('/')));
          expect(changesResponse.changes, everyElement((c) => c.kind != null));
        });
      });

      group('export', () {
        test('should return the contents of the container as tar stream',
            () async {
          // exercise
          final Stream exportResponse =
              await connection.export(createdContainer);
          final io.BytesBuilder buf = new io.BytesBuilder(copy: false);
          final StreamSubscription subscription = exportResponse.take(1000000).listen((List<int>data) {
            buf.add(data);
          });
          await subscription.asFuture();

          // verification
          expect(buf.length, greaterThan(1000000));

          // tearDown
          // Remove container in tearDown fails without some delay after
          // canceling the export stream.
          await utils.waitMilliseconds(500);
        },
            skip: remoteApiVersion < RemoteApiVersion.v1_17
                ? remoteApiVersion.toString()
                : false);
      });

      group('stats', () {
        test(
            'should return a live stream of the containers resource usage statistics',
            () async {
          // exercise
          final Stream<StatsResponse> stream =
              connection.stats(createdContainer).take(5);

          final List<StatsResponse> items = await stream.toList();

          // verification
          for (final item in items) {
            expect(item.read, isNotNull);
            expect(item.read.millisecondsSinceEpoch,
                greaterThan(new DateTime(1, 1, 1).millisecondsSinceEpoch));
            expect(item.network.rxBytes, greaterThan(0));
            expect(item.cpuStats.cupUsage.totalUsage, greaterThan(0));
            expect(item.memoryStats.limit, greaterThan(0));
          }
        },
            skip: remoteApiVersion < RemoteApiVersion.v1_17
                ? remoteApiVersion.toString()
                : false);

        test(
            'should return a single event of a containers resource usage statistics',
            () async {
          // exercise
          final Stream<StatsResponse> stream =
              connection.stats(createdContainer, stream: false);
          final StatsResponse item = await stream.first;

          // verification
          expect(item.read, isNotNull);
          expect(item.read.millisecondsSinceEpoch,
              greaterThan(new DateTime(1, 1, 1).millisecondsSinceEpoch));
          expect(item.network.rxBytes, greaterThan(0));
          expect(item.cpuStats.cupUsage.totalUsage, greaterThan(0));
          expect(item.memoryStats.limit, greaterThan(0));
        },
            skip: remoteApiVersion < RemoteApiVersion.v1_19
                ? remoteApiVersion.toString()
                : false);
      });

      group('resize', () {
        test('should resize the containers TTY', () async {
          // exercise
          final SimpleResponse resizeResponse =
              await connection.resize(createdContainer, 60, 20);

          await connection.restart(createdContainer);
          final ContainerInfo containerResponse =
              await connection.container(createdContainer);

          // verification
          expect(resizeResponse, isNotNull);
          expect(containerResponse.state.running, isTrue);

          // TODO(zoechi) find a way to check the tty size
        });
      });

      group('stop', () {
        test('should stop the running container', () async {
          // set up
          final ContainerInfo startedStatus =
              await connection.container(createdContainer);
          expect(startedStatus.state.running, isNotNull);

//          final referenceTime = new DateTime.now().toUtc();

          // exercise
          final SimpleResponse stopResponse =
              await connection.stop(createdContainer);
          final ContainerInfo stoppedStatus =
              await connection.container(createdContainer);

//          print(
//              'ref: ${referenceTime} finishedAt: ${stoppedStatus.state.finishedAt}');
          // verification
          expect(stopResponse, isNotNull);
          expect(stoppedStatus.state.running, isFalse);
          expect(stoppedStatus.state.exitCode, isNot(0));
          // a bit flaky
          // expect(stoppedStatus.state.finishedAt.millisecondsSinceEpoch,
          //    greaterThan(referenceTime.millisecondsSinceEpoch));
          expect(stoppedStatus.state.finishedAt.millisecondsSinceEpoch,
              lessThan(new DateTime.now().millisecondsSinceEpoch));
          expect(stoppedStatus.state.finishedAt.millisecondsSinceEpoch,
              greaterThan(new DateTime(1, 1, 1).millisecondsSinceEpoch));
        });
      });

      group('restart', () {
        test('should stop and start the running container', () async {
          // set up
          final ContainerInfo startedStatus =
              await connection.container(createdContainer);
          expect(startedStatus.state.running, isNotNull);

          final Function expectRestartEvent = expectAsync(() {});
          connection
              .events(
                  filters: new EventsFilter()..containers.add(createdContainer))
              .listen((EventResponse event) {
            if (event.status == ContainerEvent.restart) {
              expectRestartEvent();
            }
          });

          // exercise
          final SimpleResponse restartResponse =
              await connection.restart(createdContainer);
          await utils.waitMilliseconds(500);
          final ContainerInfo restartedStatus =
              await connection.container(createdContainer);

          // verification
          expect(restartResponse, isNotNull);
          // I expected it to be true but [restarting] seems not to be set
          //expect(restartedStatus.state.restarting, isTrue);
          // TODO(zoechi) check why running is false after restarting
          //expect(restartedStatus.state.running, isFalse);
          expect(
              restartedStatus.state.startedAt.millisecondsSinceEpoch,
              greaterThan(
                  startedStatus.state.startedAt.millisecondsSinceEpoch));

          await utils.waitMilliseconds(100);
        });
      });

      group('kill', () {
        test('should kill the container', () async {
          // set up
          final ContainerInfo startedStatus =
              await connection.container(createdContainer);
          expect(startedStatus.state.running, isNotNull);

//          final referenceTime = new DateTime.now().toUtc();

          // exercise
          final SimpleResponse killResponse =
              await connection.kill(createdContainer, signal: 'SIGKILL');
          await utils.waitMilliseconds(100);
          final ContainerInfo killedStatus =
              await connection.container(createdContainer);

//          print(
//              'ref: ${referenceTime} finishedAt: ${killedStatus.state.finishedAt}');

          // verification
          expect(killResponse, isNotNull);
          expect(killedStatus.state.running, isFalse);
          expect(killedStatus.state.exitCode, isNot(0));
          // TODO(zoechi) flaky, do a different check to verify if kill worked properly
          //expect(killedStatus.state.finishedAt.millisecondsSinceEpoch,
          //    greaterThan(referenceTime.millisecondsSinceEpoch));
          expect(killedStatus.state.finishedAt.millisecondsSinceEpoch,
              lessThan(new DateTime.now().millisecondsSinceEpoch));
        });
      });

      group('rename', () {
        test('should assign a new name to the container', () async {
          // set up
          final ContainerInfo startedStatus =
              await connection.container(createdContainer);
          expect(startedStatus.state.running, isNotNull);
          expect(startedStatus.name, isNot('SomeOtherName'));

          // exercise
          final SimpleResponse renameResponse =
              await connection.rename(createdContainer, 'SomeOtherName');
          final ContainerInfo renamedStatus =
              await connection.container(createdContainer);

          // verification
          expect(renameResponse, isNotNull);
          // 1.15 'SomeOtherName
          // 1.18 '/SomeOtherName
          expect(renamedStatus.name, endsWith('SomeOtherName'));
        },
            skip: remoteApiVersion < RemoteApiVersion.v1_17
                ? remoteApiVersion.toString()
                : false);
      });

      group('pause', () {
        tearDown(() async {
          await connection.unpause(createdContainer);
          await utils.waitMilliseconds(100);
        });

        test('should pause the container', () async {
          // set up
          final ContainerInfo startedStatus =
              await connection.container(createdContainer);
          expect(startedStatus.state.running, isNotNull);

          // exercise
          final SimpleResponse pauseResponse =
              await connection.pause(createdContainer);
          final ContainerInfo pausedStatus =
              await connection.container(createdContainer);

          // verification
          expect(pauseResponse, isNotNull);
          expect(pausedStatus.state.paused, isTrue);
          expect(pausedStatus.state.running, isTrue);
        });
      });

      group('unpause', () {
        test('should set the paused container back to running', () async {
          // set up
          final ContainerInfo startedStatus =
              await connection.container(createdContainer);
          expect(startedStatus.state.running, isNotNull);

          final SimpleResponse pauseResponse =
              await connection.pause(createdContainer);
          final ContainerInfo pausedStatus =
              await connection.container(createdContainer);

          expect(pauseResponse, isNotNull);
          expect(pausedStatus.state.paused, isTrue);
          expect(pausedStatus.state.running, isTrue);

          // exercise
          final SimpleResponse unpauseResponse =
              await connection.unpause(createdContainer);
          final ContainerInfo unpausedStatus =
              await connection.container(createdContainer);

          // verification
          expect(unpauseResponse, isNotNull);
          expect(unpausedStatus.state.paused, isFalse);
          expect(unpausedStatus.state.running, isTrue);
        });
      });

      group('attachWs', () {
        test('simple', () async {
          // exercise
          final Stream attachResponse = await connection.attachWs(
              createdContainer,
              logs: true,
              stream: true,
              stdin: true,
              stdout: true,
              stderr: true);
          final io.BytesBuilder buf = new io.BytesBuilder(copy: false);
          StreamSubscription sub;
          Completer c = new Completer();
          sub = attachResponse.listen((List<int> data) {
//            print(UTF8.decode(data));
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
//          print(UTF8.decode(buf.takeBytes()));
          // verification
          expect(buf.length, greaterThan(1000));
        },
            skip: remoteApiVersion < RemoteApiVersion.v1_17
                ? remoteApiVersion.toString()
                : false);
      }, skip: 'not yet implemented');

      group('wait', () {
        test('should wait until the container stopped', () async {
          // set up
          final ContainerInfo startedStatus =
              await connection.container(createdContainer);
          expect(startedStatus.state.running, isNotNull);

          final waitReturned = expectAsync(() {});

          // exercise
          connection.wait(createdContainer).then((response) {
            // verification
            expect(response, isNotNull);
            expect(response.statusCode, isNot(0));
            waitReturned();
          });

          // exercise
          await utils.waitMilliseconds(100);
          await connection.stop(createdContainer);
        }, timeout: const Timeout(const Duration(seconds: 60)));
      });

      group('remove', () {
        test('should remove the container from the file system', () async {
          // set up
          await connection.stop(createdContainer);

          // exercise
          await connection.removeContainer(createdContainer);

          // verification
          expect(connection.container(createdContainer), throws);

          // tear down
          createdContainer = null; // prevent removing again in tearDown
        }, timeout: const Timeout(const Duration(seconds: 60)));
      });

      group('copy', () {
        setUp(() async {
          const List<String> entryPoint = const <String>[
            '/bin/sh',
            '-c',
            'echo "some text" > copytest.txt'
          ];

          // exercise
          final Exec createResponse =
              await connection.execCreate(createdContainer, cmd: entryPoint);

          await connection.execStart(createResponse, tty: false, detach: true);
          await utils.waitMilliseconds(200);
        });

        test('should retrieve a file from the containers file system',
            () async {
          // exercise
//          print(createdContainer.id);
          final fileStream =
              await connection.copy(createdContainer, '/copytest.txt');
          final StringBuffer buf = new StringBuffer();
          await for (var data in fileStream) {
            buf.write(UTF8.decode(data));
          }

          // verification
          expect(buf.toString(), contains('some text'));

          // tear down
          createdContainer = null; // prevent removing again in tearDown
        }, timeout: const Timeout(const Duration(seconds: 60)));
      });
    });

    group('attach', () {
      setUp(() async {
        createdContainer =
            (await connection.createContainer(new CreateContainerRequest()
              ..image = imageNameAndTag
              ..openStdin = false
              ..attachStdin = false
              ..cmd = ['/bin/sh', '-c', 'uptime'])).container;
      });

      test(
          'should attach to the containers stdout and stderr and return a stream of the output',
          () async {
        // exercise
        final DeMux attachResponse = await connection.attach(createdContainer,
            stream: true, stdout: true, stderr: true);

        expect(attachResponse, isNotNull);

        final buf = new io.BytesBuilder(copy: false);

        final stdoutSubscription =
            attachResponse.stdout.take(1000).listen((data) {
          buf.add(data);
        });

        await connection.start(createdContainer);
        await stdoutSubscription.asFuture();

        // verification
        expect(buf.length, greaterThan(50));
        final s = UTF8.decode(buf.toBytes());
        expect(s, contains('up'));
        expect(s, contains(' day'));
        expect(s, contains('load average'));
      },
          skip: remoteApiVersion < RemoteApiVersion.v1_17
              ? remoteApiVersion.toString()
              : false);
    });
  });

  group('images', () {
    group('images', () {
      test('should return a list of images', () async {
        // exercise
        Iterable<ImageInfo> images = await connection.images();
//        print('Images count: ${images.length}');

        // verification
        expect(images, isNotEmpty);
        expect(images.first.id, isNotEmpty);
        expect(images,
            anyElement((img) => img.repoTags.contains(imageNameAndTag)));
        expect(
            images,
            anyElement((img) =>
                (img.created as DateTime).millisecondsSinceEpoch >
                    new DateTime(1, 1, 1).millisecondsSinceEpoch));
      });

      test('all: true', () async {
        // set up
//        String containerId = createdContainer.id;
        final Iterable<ImageInfo> images = await connection.images(all: true);
        expect(images, isNotEmpty);
        expect(images.first.id, isNotEmpty);
        // TODO(zoechi) complete test
//        expect(images, anyElement((c) => c.repoTags == createdResponse.container.id));

//        await connection.kill(createdResponse.container, signal: 'SIGKILL');
//        await connection.remove(createdResponse.container);
        createdContainer = null; // prevent remove again in tearDown

        // exercise
        //final Iterable<ImageInfo> updatedImages =
        await connection.images(all: true);

        // verification
//        expect(updatedImages, isNot(anyElement((c) => c.id == containerId)));
//        createdResponse = null;
      });

      // TODO(zoechi) add another test with digest: true
    });

    // TODO(zoechi) test build

    group('create', () {
      test('should create a new image by pulling it from the registry',
          () async {
        final Iterable<CreateImageResponse> createImageResponse =
            await connection.createImage(imageNameAndTag);
        if (connection.remoteApiVersion <= RemoteApiVersion.v1_15) {
          expect(createImageResponse.first.status,
              'Pulling repository ${imageName}');
        } else {
          expect(createImageResponse.first.status, 'Pulling from ${imageName}');
//          expect(createImageResponse.first.status, 'Pulling repository ${imageName}');
        }
        expect(createImageResponse.length, greaterThan(5));
      });
    });

    group('image', () {
      test('should return detailed information about the image', () async {
        final ImageInfo imageResponse =
            await connection.image(new Image(imageNameAndTag));
        expect(imageResponse.config.cmd, contains(entryPoint));
      });
    });

    group('history', () {
      test('should return the history of the image', () async {
        final Iterable<ImageHistoryResponse> imageHistoryResponse =
            await connection.history(new Image(imageNameAndTag));
        expect(imageHistoryResponse.length, greaterThan(2));
        expect(
            imageHistoryResponse,
            everyElement((ImageHistoryResponse e) => e.created.millisecondsSinceEpoch >
                new DateTime(1, 1, 1).millisecondsSinceEpoch));
        expect(imageHistoryResponse,
            anyElement((ImageHistoryResponse e) => e.createdBy != null && e.createdBy.isNotEmpty));
        expect(imageHistoryResponse,
            anyElement((ImageHistoryResponse e) => e.tags != null && e.tags.isNotEmpty));
        expect(imageHistoryResponse,
            anyElement((ImageHistoryResponse e) => e.size != null && e.size > 0));
      });
    });

    group('push', () {
      test('should push the image to the registry', () async {
        final Iterable<ImagePushResponse> imagePushResponse =
            await connection.push(new Image(imageName));
        expect(imagePushResponse.length, greaterThan(3));
        expect(
            imagePushResponse,
            everyElement((ImagePushResponse e) => e.created.millisecondsSinceEpoch >
                new DateTime(1, 1, 1).millisecondsSinceEpoch));
        expect(imagePushResponse,
            anyElement((ImagePushResponse e) => e.createdBy != null && e.createdBy.isNotEmpty));
        expect(imagePushResponse,
            anyElement((ImagePushResponse e) => e.tags != null && e.tags.isNotEmpty));
        expect(
            imagePushResponse, anyElement((e) => e.size != null && e.size > 0));
      }, skip: 'don\'t know yet how to test');
    });

    group('tag', () {
      test('should tag the image into a repository', () async {
        final SimpleResponse imageTagResponse = await connection.tag(
            new Image(imageNameAndTag), 'SomeRepo', 'SomeTag');
        // TODO(zoechi) check the tag is set
        expect(imageTagResponse, isNotNull);
      });

      tearDown(() async {
        try {
          await connection.removeImage(new Image('SomeRepo:SomeTag'));
        } catch (_) {}
      });
    });

    group('removeImage', () {
      test('should remove the image from the filesystem', () async {
        final SimpleResponse imageTagResponse = await connection.tag(
            new Image(imageNameAndTag), imageName, 'removeImage');
        expect(imageTagResponse, isNotNull);

        final Iterable<ImageRemoveResponse> imageRemoveResponse =
            await connection.removeImage(new Image('${imageName}:removeImage'));
        expect(imageRemoveResponse, isNotNull);
        expect(imageRemoveResponse,
            anyElement((ImageRemoveResponse e) => e.untagged == '${imageName}:removeImage'));
      });
    });

    group('search', () {
      test('should return a list of found images', () async {
        final Iterable<SearchResponse> searchResponse =
            await connection.search('sshd');
        expect(searchResponse, isNotNull);
        expect(
            searchResponse,
            anyElement((SearchResponse e) => e.description ==
                'Dockerized SSH service, built on top of official Ubuntu images.'));
        expect(searchResponse,
            anyElement((SearchResponse e) => e.name != null && e.name.isNotEmpty));
        expect(searchResponse, anyElement((e) => e.isOfficial != null));
        expect(searchResponse, anyElement((e) => e.isAutomated != null));
        expect(searchResponse,
            anyElement((SearchResponse e) => e.starCount != null && e.starCount > 0));
      }, timeout: const Timeout(const Duration(seconds: 60)));
    });
  });

  group('misc', () {
    group('auth', () {
      test('should decline the invalid login credentials', () async {
//        Succeeds with real password
//        final AuthResponse authResponse = await connection.auth(
//            new AuthRequest('zoechi', 'xxxxx', 'guenter@gzoechbauer.com',
//                'https://index.docker.io/v1/'));
//        expect(authResponse, isNotNull);
//        expect(authResponse.status, 'Login Succeeded');

        expect(
            connection.auth(new AuthRequest('xxxxx', 'xxxxx', 'xxx@xxx.com',
                'https://index.docker.io/v1/')),
            throwsA((e) => e is DockerRemoteApiError &&
                //e.body == 'Wrong login/password, please try again\n'));
                e.body ==
                    'Login: Account is not Active. Please check your e-mail for a confirmation link.\n'));
      });
    });

    group('info', () {
      test('should return system-wide information', () async {
        final InfoResponse infoResponse = await connection.info();
        expect(infoResponse, isNotNull);
        expect(infoResponse.containers, greaterThan(0));
        expect(infoResponse.debug, isNotNull);
        expect(infoResponse.driver, isNotEmpty);
        expect(infoResponse.driverStatus, isNotEmpty);
        expect(infoResponse.eventsListenersCount, isNotNull);
        expect(infoResponse.executionDriver, isNotNull);
        expect(infoResponse.fdCount, greaterThan(0));
        expect(infoResponse.goroutinesCount, greaterThan(0));
        expect(infoResponse.images, greaterThan(0));
        expect(infoResponse.indexServerAddress.length, greaterThan(0));
        expect(infoResponse.initPath, isNotEmpty);
        expect(infoResponse.initSha1, isNotNull);
        expect(infoResponse.ipv4Forwarding, isNotNull);
        expect(infoResponse.kernelVersion, isNotEmpty);
        expect(infoResponse.memoryLimit, isNotNull);
        expect(infoResponse.operatingSystem, isNotEmpty);
        expect(infoResponse.swapLimit, isNotNull);
      });
    });

    group('version', () {
      test('should return Docker version information', () async {
        final VersionResponse versionResponse = await connection.version();
        expect(versionResponse, isNotNull);
        expect(versionResponse.apiVersion.major, greaterThanOrEqualTo(1));
        expect(versionResponse.apiVersion.minor, greaterThanOrEqualTo(1));
        expect(versionResponse.architecture, isNotEmpty);
        expect(versionResponse.gitCommit, isNotEmpty);
        expect(versionResponse.goVersion, isNotEmpty);
        expect(versionResponse.kernelVersion, isNotEmpty);
        expect(versionResponse.os, isNotEmpty);
        expect(versionResponse.version.major, greaterThanOrEqualTo(1));
        expect(versionResponse.version.minor, greaterThanOrEqualTo(1));
      });
    });

    group('ping', () {
      test('should not a non-error response', () async {
        final SimpleResponse pingResponse = await connection.ping();
        expect(pingResponse, isNotNull);
      });
    });

    group('get', () {
      test('should return a tarball containing all images in the repository',
          () async {
        // exercise
        final Stream exportResponse =
            await connection.get(new Image(imageNameAndTag));
        final io.BytesBuilder buf = new io.BytesBuilder(copy: false);
        StreamSubscription sub;
        Completer c = new Completer();
        sub = exportResponse.listen((List<int> data) {
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
        await utils.waitMilliseconds(500);
      });
    });

    group('getAll', () {
      test('should return a tarball containing all images in all repositories',
          () async {
        // exercise
        final Stream exportResponse = await connection.getAll();
        final io.BytesBuilder buf = new io.BytesBuilder(copy: false);
        StreamSubscription sub;
        Completer c = new Completer();
        sub = exportResponse.listen((List<int> data) {
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
        await utils.waitMilliseconds(500);
      });
    }, skip: 'test not yet working');

    // TODO(zoechi) implement test for load()
  });

  group('exec', () {
    group('create', () {
      test('should set up the exec instance in the running container',
          () async {
        // set up
        await createContainer();
        await connection.start(createdContainer);

        const entryPoint = 'echo sometext > ~/somefile.txt';
        const args = 'ls -la';

        // exercise
        final Exec createResponse = await connection.execCreate(
            createdContainer,
            attachStdin: false,
            attachStdout: true,
            attachStderr: true,
            cmd: [entryPoint, args]);

        // verify
        final ExecInfo inspectResponse =
            await connection.execInspect(createResponse);
        expect(inspectResponse.container.id, createdContainer.id);
        expect(inspectResponse.running, isFalse);
        expect(inspectResponse.processConfig.entrypoint, entryPoint);
        expect(inspectResponse.processConfig.arguments, [args]);
        expect(inspectResponse.openStderr, isTrue);
        expect(inspectResponse.openStdout, isTrue);
        expect(inspectResponse.openStdin, isFalse);
      },
          skip: remoteApiVersion < RemoteApiVersion.v1_17
              ? remoteApiVersion.toString()
              : false);
    });

    group('start', () {
      test('should start the exec and return the stdout as stream', () async {
        // set up
        await createContainer();
        await connection.start(createdContainer);

        const entryPoint = const ['/bin/sh', '-c', 'tail -f /etc/inittab'];

        // exercise
        final Exec createResponse = await connection.execCreate(
            createdContainer,
            attachStdout: true,
            attachStderr: true,
            tty: true,
            cmd: entryPoint);

        final DeMux startResponse = await connection.execStart(createResponse,
            tty: false, detach: false);

        final StringBuffer stdoutBuf = new StringBuffer();
        final StreamSubscription stdoutSubscription = startResponse.stdout.listen((List<int>data) {
          stdoutBuf.write(UTF8.decode(data));
        });

        final StringBuffer stderrBuf = new StringBuffer();
        final StreamSubscription stderrSubscription = startResponse.stderr.listen((List<int> data) {
          stderrBuf.write(UTF8.decode(data));
        });

        // verify
        final ExecInfo inspectResponse =
            await connection.execInspect(createResponse);
        expect(inspectResponse.container.id, createdContainer.id);
        expect(inspectResponse.running, isTrue);
        expect(inspectResponse.processConfig.entrypoint, entryPoint[0]);
        expect(inspectResponse.processConfig.arguments, entryPoint.sublist(1));
        expect(inspectResponse.openStdin, isFalse);
        expect(inspectResponse.openStdout, isTrue);
        expect(inspectResponse.openStderr, isTrue);

        connection.stop(createdContainer);
        await Future.wait(
            [stdoutSubscription.asFuture(), stderrSubscription.asFuture()]);

        expect(stdoutBuf, isNotEmpty);
        expect(stderrBuf, isEmpty);
      },
          skip: remoteApiVersion < RemoteApiVersion.v1_17
              ? remoteApiVersion.toString()
              : false);
    });

    // TODO(zoechi) implement test for execResize()

    group('inspect', () {
      test('should return detail information about the created exec instance',
          () async {
        await createContainer();
        await connection.start(createdContainer);
        //await utils.waitMilliseconds(200);

        final Exec execResponse = await connection.execCreate(createdContainer,
            attachStdin: true,
            cmd: ['echo sometext > ~/somefile.txt', 'ls -la']);

        final ExecInfo inspectResponse =
            await connection.execInspect(execResponse);
        expect(inspectResponse, isNotNull);
        expect(inspectResponse.id, execResponse.id);
        expect(inspectResponse.running, isFalse);
        expect(
            inspectResponse.processConfig.entrypoint, startsWith('echo some'));
        expect(inspectResponse.openStdin, isTrue);
        expect(inspectResponse.openStdout, isFalse);
        expect(inspectResponse.openStderr, isFalse);
        expect(inspectResponse.container.id, createdContainer.id);
      },
          skip: remoteApiVersion < RemoteApiVersion.v1_17
              ? remoteApiVersion.toString()
              : false);

      test('should return detail information about the started exec instance',
          () async {
        await createContainer();
        await connection.start(createdContainer);
        //await utils.waitMilliseconds(200);

        final Exec execResponse = await connection.execCreate(createdContainer,
            attachStdin: true,
            cmd: ['echo sometext > ~/somefile.txt', 'ls -la']);

        final ExecInfo inspectResponse =
            await connection.execInspect(execResponse);
        expect(inspectResponse, isNotNull);
        expect(inspectResponse.id, execResponse.id);
        expect(inspectResponse.running, isFalse);
        expect(
            inspectResponse.processConfig.entrypoint, startsWith('echo some'));
        expect(inspectResponse.openStdin, isTrue);
        expect(inspectResponse.openStdout, isFalse);
        expect(inspectResponse.openStderr, isFalse);
        expect(inspectResponse.container.id, createdContainer.id);
      },
          skip: remoteApiVersion < RemoteApiVersion.v1_17
              ? remoteApiVersion.toString()
              : false);
    });
  });

  group('events', () {
    test('should return events of the container except "die" as a stream',
        () async {
      // set up
      await createContainer();

      final startReceived = expectAsync(() {});
      final stopReceived = expectAsync(() {});

      // exercise
      StreamSubscription subscription;
      subscription = connection.events(filters: new EventsFilter()
        ..events.addAll([ContainerEvent.start, ContainerEvent.stop])
        ..containers.add(createdContainer)).listen((event) {
        // verify
        if (event.id == createdContainer.id &&
            event.from == imageNameAndTag &&
            event.time.millisecondsSinceEpoch >
                new DateTime(1, 1, 1).millisecondsSinceEpoch) {
          //
          if (event.status == ContainerEvent.start) {
            startReceived();
            connection.stop(createdContainer);
            //
          } else if (event.status == ContainerEvent.die) {
            if (connection.remoteApiVersion >= RemoteApiVersion.v1_17) {
              fail('"die" event was filtered out.');
            }
            //
          } else if (event.status == ContainerEvent.stop) {
            stopReceived();
            subscription.cancel();
          }
        }
      });

      await utils.waitMilliseconds(100);

      await connection.start(createdContainer);
    });

    test(
        'should return events of the container occured before the specified time',
        () async {
      // set up
      await createContainer();

      final startReceived = expectAsync(() {});
      final dieReceived = expectAsync(() {});
      final stopReceived = expectAsync(() {});

      // exercise
      StreamSubscription subscription;
      subscription = connection
          .events(
              since: new DateTime.now(),
              until: new DateTime.now().add(const Duration(minutes: 2)))
          .listen((event) {
        // verify
        if (event.id == createdContainer.id &&
            event.from == imageNameAndTag &&
            event.time.millisecondsSinceEpoch >
                new DateTime(1, 1, 1).millisecondsSinceEpoch) {
          //
          if (event.status == ContainerEvent.start) {
            startReceived();
            connection.stop(createdContainer);
            //
          } else if (event.status == ContainerEvent.die) {
            if (connection.remoteApiVersion >= RemoteApiVersion.v1_17) {
              dieReceived();
            }
            //
          } else if (event.status == ContainerEvent.stop) {
            stopReceived();
            subscription.cancel();
          }
        }
      });

      await utils.waitMilliseconds(100);

      await connection.start(createdContainer);
    });
  });
}
