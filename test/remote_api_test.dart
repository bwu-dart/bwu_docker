@TestOn('vm')
library bwu_docker.test.docker;

import 'dart:io' show BytesBuilder;
import 'dart:convert' show JSON, UTF8;
import 'dart:async' show Completer, Future, Stream, StreamSubscription;
import 'package:test/test.dart';
import 'package:bwu_docker/src/remote_api.dart';
import 'package:bwu_docker/src/data_structures.dart';

//const imageName = 'selenium/standalone-chrome';
//const imageTag = '2.45.0';
//const entryPoint = '/opt/bin/entry_point.sh';
//const runningProcess = '/bin/bash ${entryPoint}';
//const dockerPort = 2375;

// Docker-in-Docker to allow to test with different Docker version
// docker run --privileged -d -p 1234:1234 -e PORT=1234 jpetazzo/dind
const imageName = 'busybox';
const imageTag = 'buildroot-2014.02';
const entryPoint = '/bin/sh';
const runningProcess = '/bin/sh';
const dockerPort = 1234;

const imageNameAndTag = '${imageName}:${imageTag}';

void main([List<String> args]) {
  //initLogging(args);

  DockerConnection connection;
  CreateResponse createdContainer;

  /// setUp helper to create the image used in tests if it is not yet available.
  final ensureImageExists = () async {
    try {
      await connection.image(new Image(imageNameAndTag));
    } on DockerRemoteApiError {
      final Iterable<CreateImageResponse> createResponse =
          await connection.createImage(imageNameAndTag);
      for (var e in createResponse) {
        print('${e.status} - ${e.progressDetail}');
      }
    }
  };

  /// setUp helper to create a container from the image used in tests.
  final createContainer = () async {
    createdContainer = await connection
        .createContainer(new CreateContainerRequest()..image = imageNameAndTag);
  };

  /// teatDown helper to remove the container created in setUp
  final removeContainer = () async {
    if (createdContainer != null) {
      int tries = 3;
      String errorMsg = '';
      while (createdContainer != null && tries > 0) {
        try {
          connection
              .stop(createdContainer.container, timeout: 3)
              .catchError((_) {});
          final WaitResponse r =
              await connection.wait(createdContainer.container);
          await connection.removeContainer(createdContainer.container,
              force: true, removeVolumes: true);
          createdContainer = null;
        } catch (error) {
          if (error.statusCode == 404) {
            createdContainer = null;
            break;
          }
          if (error.toString().isNotEmpty) {
            errorMsg = '${error}\n${error}';
          }
          await new Future.delayed(const Duration(milliseconds: 100));
        }
        tries--;
      }
      if (createdContainer != null) {
        print(
            '>>> remove ${createdContainer.container.id} failed - ${errorMsg}');
        createdContainer = null;
      }
    }
  };

  /// Helper to skip test if feature is not supported on the connected server.
  final checkMinVersion = (Version supportedVersion) {
    if (connection.apiVersion < supportedVersion) {
      print(
          'Test skipped because this command requires Docker API version ${supportedVersion} (current: ${connection.apiVersion}).');
      return false;
    }
    return true;
  };

  setUp(() async {
    connection = new DockerConnection('localhost', dockerPort);
    await connection.init();
    assert(connection.dockerVersion != null);
    await ensureImageExists();
  });

  tearDown(() async {
    await removeContainer();
  });

  /// If the used Docker image is not available the download takes some time and
  /// makes the first test time out
  group('((prevent timeout))', () {
    setUp(() => ensureImageExists());

    test('((dummy))', () {},
        timeout: const Timeout(const Duration(seconds: 300)));
  });

  group('containers', () {
    group('create', () {
      test('simple', () async {
        // exercise
        await createContainer();

        // verification
        expect(createdContainer.container, new isInstanceOf<Container>());
        expect(createdContainer.container.id, isNotEmpty);
      });

      test('with name', () async {
        // set up
        if (!checkMinVersion(ApiVersion.v1_17)) {
          return;
        }

        const containerName = '/dummy_name';

        // exercise
        createdContainer = await connection.createContainer(
            new CreateContainerRequest()..image = imageNameAndTag,
            name: 'dummy_name');
        await new Future.delayed(const Duration(milliseconds: 100));
//          print(createdContainer.container.id);

        // verification
        expect(createdContainer.container, new isInstanceOf<Container>());
        expect(createdContainer.container.id, isNotEmpty);

        final Iterable<Container> containers = await connection.containers(
            filters: {'name': [containerName]}, all: true);

        expect(containers.length, greaterThan(0));
        expect(
            containers, everyElement((c) => c.names.contains(containerName)));
      });
    });

    group('logs', () {
      setUp(() {
        ensureImageExists();
      });

      test('simple', () async {
        // set up
        createdContainer = await connection.createContainer(
            new CreateContainerRequest()
          ..image = imageNameAndTag
          ..hostConfig.logConfig = {'Type': 'json-file'});
        final SimpleResponse startedContainer =
            await connection.start(createdContainer.container);
        expect(startedContainer, isNotNull);

        // exercise
        Stream log = await connection.logs(createdContainer.container,
            stdout: true,
            stderr: true,
            timestamps: true,
            follow: false,
            tail: 10);
        final buf = new BytesBuilder(copy: false);
        final sub = log.take(100).listen(buf.add);

        await sub.asFuture();

//          print(buf.length);
//          print(buf.toBytes());

        // verification
        expect(buf, isNotNull);
      } /*, skip: 'find a way to produce log output, currently the returned data is always empty'*/);
    });

    group('start', () {
      setUp(() async {
        await ensureImageExists();
        await createContainer();
      });

      test('simple', () async {
        // set up

        // exercise
        final SimpleResponse startedContainer =
            await connection.start(createdContainer.container);

        // verification
        expect(startedContainer, isNotNull);
        final Iterable<Container> containers = await connection.containers(
            filters: {'status': [ContainerStatus.running.toString()]});
        //print(containers.map((c) => c.toJson()).toList());

        expect(containers,
            anyElement((c) => c.id == createdContainer.container.id));
      }, timeout: const Timeout(const Duration(seconds: 100)));
    });

    group('commit', () {
      setUp(() async {
        await ensureImageExists();
        await createContainer();
      });

      test('simple', () async {
        // set up

        // exercise
        final SimpleResponse startedContainer =
            await connection.start(createdContainer.container);

        // verification
        expect(startedContainer, isNotNull);
        final CommitResponse commitResponse = await connection.commit(
            new CommitRequest(
                attachStdout: true,
                cmd: ['date'],
                volumes: new Volumes()..add('/tmp', {}),
                exposedPorts: {'22/tcp': {}}), createdContainer.container,
            tag: 'commitTest', comment: 'remove', author: 'someAuthor');

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
        createdContainer = await connection.createContainer(
            new CreateContainerRequest()
          ..image = imageNameAndTag
          ..openStdin = true
          ..tty = true);
        await connection.start(createdContainer.container);
        await new Future.delayed(const Duration(milliseconds: 100));
      });

      group('containers', () {
        test('simple', () async {
          // exercise
          Iterable<Container> containers = await connection.containers();

          // verification
          expect(containers, isNotEmpty);
          expect(containers.first.image, isNotEmpty);
          expect(containers, anyElement((c) => c.image == imageNameAndTag));
        });

        test('"all: true"', () async {
          // set up
          String containerId = createdContainer.container.id;
          final Iterable<Container> containers =
              await connection.containers(all: true);
          expect(containers, isNotEmpty);
          expect(containers.first.image, isNotEmpty);
          expect(containers,
              anyElement((c) => c.id == createdContainer.container.id));

          await connection.kill(createdContainer.container, signal: 'SIGKILL');
          await connection.removeContainer(createdContainer.container);
          createdContainer = null; // prevent remove again in tearDown

          // exercise
          final Iterable<Container> updatedContainers =
              await connection.containers(all: true);

          // verification
          expect(
              updatedContainers, isNot(anyElement((c) => c.id == containerId)));
          createdContainer = null;
        });

        test('filter "status: exited"', () async {
          // set up

          final Iterable<Container> containers =
              await connection.containers(filters: {'status': ['exited']});

          expect(containers, isNotEmpty);
          expect(containers.first.image, isNotEmpty);
          expect(containers,
              isNot(anyElement((c) => c.id == createdContainer.container.id)));

          // exercise
          await connection.kill(createdContainer.container, signal: 'SIGKILL');

          await new Future.delayed(const Duration(milliseconds: 500));

          final Iterable<Container> updatedContainers =
              await connection.containers(all: true);

          // verification
          expect(updatedContainers, isNotEmpty);
          expect(updatedContainers.first.image, isNotEmpty);
          expect(updatedContainers,
              anyElement((c) => c.id == createdContainer.container.id));
        });
      });

      group('container', () {
        test('simple', () async {
          // exercise
          final ContainerInfo container =
              await connection.container(createdContainer.container);
          await connection.start(createdContainer.container);
          await new Future.delayed(const Duration(milliseconds: 500));

          // verification
          expect(container, new isInstanceOf<ContainerInfo>());
          expect(container.id, createdContainer.container.id);
          expect(container.config.cmd, [entryPoint]);
          expect(container.config.image, imageNameAndTag);
          expect(container.state.running, isTrue);
        });
      });

      group('top', () {
        test('simple', () async {
          // exercise
          final TopResponse topResponse =
              await connection.top(createdContainer.container);

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

        test('with ps_args', () async {
          // exercise
          final TopResponse topResponse =
              await connection.top(createdContainer.container, psArgs: 'aux');

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
        test('simple', () async {
          final Exec createdExec = await connection.execCreate(
              createdContainer.container,
              attachStdin: true,
              tty: true,
              cmd: [
            '/bin/sh -c "echo sometext > /tmp/somefile.txt"',
            '/bin/sh -c ls -la'
          ]);
          //cmd: ['echo hallo']);
          final startResponse = await connection.execStart(createdExec);

          await for (var _ in startResponse.stdout) {
            //print('x: ${UTF8.decode(x)}');
          }
          await new Future.delayed(const Duration(
              milliseconds: 500)); // TODO(zoechi) check if necessary

//          print('4');
          // exercise
          final ChangesResponse changesResponse =
              await connection.changes(createdContainer.container);
//          print('changes: ${changesResponse.changes}');

          // verification
          // TODO(zoechi) provoke some changes and check the result
          // expect(changesResponse.changes.length, greaterThan(0));
          expect(changesResponse.changes,
              everyElement((c) => c.path.startsWith('/')));
          expect(changesResponse.changes, everyElement((c) => c.kind != null));
        });
      });

      group('export', () {
        test('simple', () async {
          if (!checkMinVersion(ApiVersion.v1_17)) {
            return;
          }

          // exercise
          final Stream exportResponse =
              await connection.export(createdContainer.container);
          final buf = new BytesBuilder(copy: false);
          var subscription = exportResponse.take(1000000).listen((data) {
            buf.add(data);
          });
          await subscription.asFuture();

          // verification
          expect(buf.length, greaterThan(1000000));

          // tearDown
          // Remove container in tearDown fails without some delay after
          // canceling the export stream.
          await new Future.delayed(const Duration(milliseconds: 500));
        });
      });

      group('stats', () {
        test('simple', () async {
          if (!checkMinVersion(ApiVersion.v1_17)) {
            return;
          }

          // exercise
          final Stream<StatsResponse> stream =
              connection.stats(createdContainer.container);
          final StatsResponse item = await stream.first;

          // verification
          expect(item.read, isNotNull);
          expect(item.read.millisecondsSinceEpoch,
              greaterThan(new DateTime(1, 1, 1).millisecondsSinceEpoch));
          expect(item.network.rxBytes, greaterThan(0));
          expect(item.cpuStats.cupUsage.totalUsage, greaterThan(0));
          expect(item.memoryStats.limit, greaterThan(0));
        });
      });

      group('resize', () {
        test('simple', () async {
          // exercise
          final SimpleResponse resizeResponse =
              await connection.resize(createdContainer.container, 60, 20);

          await connection.restart(createdContainer.container);
          final ContainerInfo containerResponse =
              await connection.container(createdContainer.container);

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
              await connection.container(createdContainer.container);
          expect(startedStatus.state.running, isNotNull);

//          final referenceTime = new DateTime.now().toUtc();

          // exercise
          final SimpleResponse stopResponse =
              await connection.stop(createdContainer.container);
          final ContainerInfo stoppedStatus =
              await connection.container(createdContainer.container);

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
        test('simple', () async {
          // set up
          final ContainerInfo startedStatus =
              await connection.container(createdContainer.container);
          expect(startedStatus.state.running, isNotNull);

          final expectRestartEvent = expectAsync(() {});
          connection
              .events(
                  filters: new EventsFilter()
            ..containers.add(createdContainer.container))
              .listen((event) {
            if (event.status == ContainerEvent.restart) {
              expectRestartEvent();
            }
          });

          // exercise
          final SimpleResponse restartResponse =
              await connection.restart(createdContainer.container);
          await new Future.delayed(const Duration(milliseconds: 100), () {});
          final ContainerInfo restartedStatus =
              await connection.container(createdContainer.container);

          // verification
          expect(restartResponse, isNotNull);
          // I expected it to be true but [restarting] seems not to be set
          //expect(restartedStatus.state.restarting, isTrue);
          // TODO(zoechi) check why running is false after restarting
          //expect(restartedStatus.state.running, isFalse);
          expect(restartedStatus.state.startedAt.millisecondsSinceEpoch,
              greaterThan(
                  startedStatus.state.startedAt.millisecondsSinceEpoch));

          await new Future.delayed(const Duration(milliseconds: 100), () {});
        });
      });

      group('kill', () {
        test('simple', () async {
          // set up
          final ContainerInfo startedStatus =
              await connection.container(createdContainer.container);
          expect(startedStatus.state.running, isNotNull);

//          final referenceTime = new DateTime.now().toUtc();

          // exercise
          final SimpleResponse killResponse = await connection.kill(
              createdContainer.container, signal: 'SIGKILL');
          await new Future.delayed(const Duration(milliseconds: 100), () {});
          final ContainerInfo killedStatus =
              await connection.container(createdContainer.container);

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
        test('simple', () async {
          final supportedVersion = new Version.fromString('1.17');
          if (!checkMinVersion(supportedVersion)) {
            return;
          }

          // set up
          final ContainerInfo startedStatus =
              await connection.container(createdContainer.container);
          expect(startedStatus.state.running, isNotNull);
          expect(startedStatus.name, isNot('SomeOtherName'));

          // exercise
          final SimpleResponse renameResponse = await connection.rename(
              createdContainer.container, 'SomeOtherName');
          final ContainerInfo renamedStatus =
              await connection.container(createdContainer.container);

          // verification
          expect(renameResponse, isNotNull);
          // 1.15 'SomeOtherName
          // 1.18 '/SomeOtherName
          expect(renamedStatus.name, endsWith('SomeOtherName'));
        });
      });

      group('pause', () {
        tearDown(() async {
          await connection.unpause(createdContainer.container);
          await new Future.delayed(const Duration(milliseconds: 100), () {});
        });
        test('simple', () async {
          // set up
          final ContainerInfo startedStatus =
              await connection.container(createdContainer.container);
          expect(startedStatus.state.running, isNotNull);

          // exercise
          final SimpleResponse pauseResponse =
              await connection.pause(createdContainer.container);
          final ContainerInfo pausedStatus =
              await connection.container(createdContainer.container);

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
              await connection.container(createdContainer.container);
          expect(startedStatus.state.running, isNotNull);

          final SimpleResponse pauseResponse =
              await connection.pause(createdContainer.container);
          final ContainerInfo pausedStatus =
              await connection.container(createdContainer.container);

          expect(pauseResponse, isNotNull);
          expect(pausedStatus.state.paused, isTrue);
          expect(pausedStatus.state.running, isTrue);

          // exercise
          final SimpleResponse unpauseResponse =
              await connection.unpause(createdContainer.container);
          final ContainerInfo unpausedStatus =
              await connection.container(createdContainer.container);

          // verification
          expect(unpauseResponse, isNotNull);
          expect(unpausedStatus.state.paused, isFalse);
          expect(unpausedStatus.state.running, isTrue);
        });
      });

      group('attachWs', () {
        test('simple', () async {
          final supportedVersion = new Version.fromString('1.17');
          if (!checkMinVersion(supportedVersion)) {
            return;
          }

          // exercise
          final Stream attachResponse = await connection.attachWs(
              createdContainer.container,
              logs: true,
              stream: true,
              stdin: true,
              stdout: true,
              stderr: true);
          final buf = new BytesBuilder(copy: false);
          StreamSubscription sub;
          Completer c = new Completer();
          sub = attachResponse.listen((data) {
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
        });
      }, skip: 'not yet implemented');

      group('wait', () {
        test('simple', () async {
          // set up
          final ContainerInfo startedStatus =
              await connection.container(createdContainer.container);
          expect(startedStatus.state.running, isNotNull);

          final waitReturned = expectAsync(() {});

          // exercise
          connection.wait(createdContainer.container).then((response) {
            // verification
            expect(response, isNotNull);
            expect(response.statusCode, isNot(0));
            waitReturned();
          });

          // exercise
          await new Future.delayed(const Duration(milliseconds: 100), () {});
          await connection.stop(createdContainer.container);
        }, timeout: const Timeout(const Duration(seconds: 60)));
      });

      group('remove', () {
        test('simple', () async {
          // set up
          await connection.stop(createdContainer.container);

          // exercise
          await connection.removeContainer(createdContainer.container);

          // verification
          expect(connection.container(createdContainer.container), throws);

          // tear down
          createdContainer = null; // prevent removing again in tearDown
        }, timeout: const Timeout(const Duration(seconds: 60)));
      });
    });

    group('attach', () {
      setUp(() async {
        createdContainer = await connection.createContainer(
            new CreateContainerRequest()
          ..image = imageNameAndTag
          ..openStdin = false
          ..attachStdin = false
          ..cmd = ['/bin/sh', '-c', 'uptime']);
      });

      test('simple', () async {
        if (!checkMinVersion(ApiVersion.v1_17)) {
          return;
        }

        // exercise
        final DeMux attachResponse = await connection.attach(
            createdContainer.container,
            stream: true, stdout: true, stderr: true);

        expect(attachResponse, isNotNull);

        final buf = new BytesBuilder(copy: false);

        final stdoutSubscription = attachResponse.stdout
            .take(1000)
            .listen((data) {
          buf.add(data);
        }, onDone: () => print('done'));

        await connection.start(createdContainer.container);
        await stdoutSubscription.asFuture();

        // verification
        expect(buf.length, greaterThan(50));
        final s = UTF8.decode(buf.toBytes());
        expect(s, contains('up'));
        expect(s, contains('days'));
        expect(s, contains('load average'));
      });
    });
  });

  group('images', () {
    group('images', () {
      test('simple', () async {
        // exercise
        Iterable<ImageInfo> images = await connection.images();
//        print('Images count: ${images.length}');

        // verification
        expect(images, isNotEmpty);
        expect(images.first.id, isNotEmpty);
        expect(images,
            anyElement((img) => img.repoTags.contains(imageNameAndTag)));
        expect(images, anyElement(
            (img) => (img.created as DateTime).millisecondsSinceEpoch >
                new DateTime(1, 1, 1).millisecondsSinceEpoch));
      });

      test('all: true', () async {
        // set up
//        String containerId = createdContainer.container.id;
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
      test('simple', () async {
        final Iterable<CreateImageResponse> createImageResponse =
            await connection.createImage(imageNameAndTag);
        if (connection.apiVersion <= ApiVersion.v1_15) {
          expect(createImageResponse.first.status,
              'Pulling repository ${imageName}');
        } else {
          expect(createImageResponse.first.status, 'Pulling from ${imageName}');
        }
        expect(createImageResponse.length, greaterThan(5));
      });
    });

    group('image', () {
      test('simple', () async {
        final ImageInfo imageResponse =
            await connection.image(new Image(imageNameAndTag));
        expect(imageResponse.config.cmd, contains(entryPoint));
      });
    });

    group('history', () {
      test('simple', () async {
        final Iterable<ImageHistoryResponse> imageHistoryResponse =
            await connection.history(new Image(imageNameAndTag));
        expect(imageHistoryResponse.length, greaterThan(2));
        expect(imageHistoryResponse, everyElement(
            (e) => e.created.millisecondsSinceEpoch >
                new DateTime(1, 1, 1).millisecondsSinceEpoch));
        expect(imageHistoryResponse,
            anyElement((e) => e.createdBy != null && e.createdBy.isNotEmpty));
        expect(imageHistoryResponse,
            anyElement((e) => e.tags != null && e.tags.isNotEmpty));
        expect(imageHistoryResponse,
            anyElement((e) => e.size != null && e.size > 0));
      });
    });

    group('push', () {
      test('simple', () async {
        final Iterable<ImagePushResponse> imagePushResponse =
            await connection.push(new Image(imageName));
        expect(imagePushResponse.length, greaterThan(3));
        expect(imagePushResponse, everyElement(
            (e) => e.created.millisecondsSinceEpoch >
                new DateTime(1, 1, 1).millisecondsSinceEpoch));
        expect(imagePushResponse,
            anyElement((e) => e.createdBy != null && e.createdBy.isNotEmpty));
        expect(imagePushResponse,
            anyElement((e) => e.tags != null && e.tags.isNotEmpty));
        expect(
            imagePushResponse, anyElement((e) => e.size != null && e.size > 0));
      }, skip: 'complete test when `exec` is working');
    });

    group('tag', () {
      test('simple', () async {
        final SimpleResponse imageTagResponse = await connection.tag(
            new Image(imageNameAndTag), 'SomeRepo', 'SomeTag');
        expect(imageTagResponse, isNotNull);
      });

      tearDown(() async {
        try {
          await connection.removeImage(new Image('SomeRepo:SomeTag'));
        } catch (_) {}
      });
    });

    group('removeImage', () {
      test('simple', () async {
        final SimpleResponse imageTagResponse = await connection.tag(
            new Image(imageNameAndTag), imageName, 'removeImage');
        expect(imageTagResponse, isNotNull);

        final Iterable<ImageRemoveResponse> imageRemoveResponse =
            await connection.removeImage(new Image('${imageName}:removeImage'));
        expect(imageRemoveResponse, isNotNull);
        expect(imageRemoveResponse,
            anyElement((e) => e.untagged == '${imageName}:removeImage'));
      });
    });

    group('search', () {
      test('simple', () async {
        final Iterable<SearchResponse> searchResponse =
            await connection.search('sshd');
        expect(searchResponse, isNotNull);
        expect(searchResponse, anyElement((e) => e.description ==
            'Dockerized SSH service, built on top of official Ubuntu images.'));
        expect(searchResponse,
            anyElement((e) => e.name != null && e.name.isNotEmpty));
        expect(searchResponse, anyElement((e) => e.isOfficial != null));
        expect(searchResponse, anyElement((e) => e.isAutomated != null));
        expect(searchResponse,
            anyElement((e) => e.starCount != null && e.starCount > 0));
      });
    });
  });

  group('misc', () {
    group('auth', () {
      test('simple', () async {
//        Succeeds with real password
//        final AuthResponse authResponse = await connection.auth(
//            new AuthRequest('zoechi', 'xxxxx', 'guenter@gzoechbauer.com',
//                'https://index.docker.io/v1/'));
//        expect(authResponse, isNotNull);
//        expect(authResponse.status, 'Login Succeeded');

        expect(connection.auth(new AuthRequest('xxxxx', 'xxxxx', 'xxx@xxx.com',
                'https://index.docker.io/v1/')), throwsA(
            (e) => e is DockerRemoteApiError &&
                //e.body == 'Wrong login/password, please try again\n'));
                e.body ==
                    'Login: Account is not Active. Please check your e-mail for a confirmation link.\n'));
      });
    });

    group('info', () {
      test('simple', () async {
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
        expect(infoResponse.initSha1, isNotEmpty);
        expect(infoResponse.ipv4Forwarding, isNotNull);
        expect(infoResponse.kernelVersion, isNotEmpty);
        expect(infoResponse.memoryLimit, isNotNull);
        expect(infoResponse.operatingSystem, isNotEmpty);
        expect(infoResponse.swapLimit, isNotNull);
      });
    });

    group('version', () {
      test('simple', () async {
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
      test('simple', () async {
        final SimpleResponse pingResponse = await connection.ping();
        expect(pingResponse, isNotNull);
      });
    });

    group('get', () {
      test('simple', () async {
        // exercise
        final Stream exportResponse =
            await connection.get(new Image(imageNameAndTag));
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

    group('getAll', () {
      test('simple', () async {
        // exercise
        final Stream exportResponse = await connection.getAll();
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
    }, skip: 'test not yet working');

    // TODO(zoechi) implement test for load()
  });

  group('exec', () {
    group('execCreate', () {
      test('simple', () async {
        final supportedVersion = new Version.fromString('1.17');
        if (!checkMinVersion(supportedVersion)) {
          return;
        }

        createdContainer = await connection.createContainer(
            new CreateContainerRequest()..image = imageNameAndTag);
        await connection.start(createdContainer.container);
        //await new Future.delayed(const Duration(milliseconds: 500));
        final Exec execResponse = await connection.execCreate(
            createdContainer.container,
            attachStdin: true,
            cmd: ['echo sometext > ~/somefile.txt', 'ls -la']);
        print(execResponse.id);
        final startResponse = await connection.execStart(execResponse);
        expect(startResponse, isNotNull);
        print('startResponse: ${startResponse}');
        await for (var v in startResponse.stdin) {
          print('startResonse: ${v}');
        }
        await for (var v in startResponse.stdout) {
          print('startResonse: ${v}');
        }
        await for (var v in startResponse.stderr) {
          print('startResonse: ${v}');
        }
      }, skip: 'Test broken, probably due to a Docker issue.');
    });

    // TODO(zoechi) implement test for execStart()
    // TODO(zoechi) implement test for execResize()

    group('execInspect', () {
      test('simple', () async {
        final supportedVersion = new Version.fromString('1.17');
        if (!checkMinVersion(supportedVersion)) {
          return;
        }

        createdContainer = await connection.createContainer(
            new CreateContainerRequest()..image = imageNameAndTag);
        await connection.start(createdContainer.container);
        //await new Future.delayed(const Duration(milliseconds: 500));
        final Exec execResponse = await connection.execCreate(
            createdContainer.container,
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
        expect(inspectResponse.container.id, createdContainer.container.id);
      });
    });
  });

  group('events', () {
    test('filter die', () async {
      final CreateResponse createdContainer = await connection.createContainer(
          new CreateContainerRequest()..image = imageNameAndTag);

      final startReceived = expectAsync(() {});
      final stopReceived = expectAsync(() {});

      StreamSubscription subscription;
      subscription = connection.events(filters: new EventsFilter()
        ..events.addAll([ContainerEvent.start, ContainerEvent.stop])
        ..containers.add(createdContainer.container)).listen((event) {
        if (event.id == createdContainer.container.id &&
            event.from == imageNameAndTag &&
            event.time.millisecondsSinceEpoch >
                new DateTime(1, 1, 1).millisecondsSinceEpoch) {
          if (event.status == ContainerEvent.start) {
            startReceived();
            connection.stop(createdContainer.container);
          } else if (event.status == ContainerEvent.die) {
            if (connection.apiVersion >= ApiVersion.v1_17) {
              fail('"die" event was filtered out.');
            }
          } else if (event.status == ContainerEvent.stop) {
            stopReceived();
            subscription.cancel();
          }
        }
      });

      await new Future.delayed(const Duration(milliseconds: 100));

      await connection.start(createdContainer.container);
    });

    test('container until', () async {
      final CreateResponse createdContainer = await connection.createContainer(
          new CreateContainerRequest()..image = imageNameAndTag);
      final startReceived = expectAsync(() {});
      //final dieReceived = expectAsync(() {});
      final stopReceived = expectAsync(() {});
      StreamSubscription subscription;
      subscription = connection
          .events(
              since: new DateTime.now(),
              until: new DateTime.now().add(const Duration(minutes: 2)))
          .listen((event) {
        if (event.id == createdContainer.container.id &&
            event.from == imageNameAndTag &&
            event.time.millisecondsSinceEpoch >
                new DateTime(1, 1, 1).millisecondsSinceEpoch) {
          if (event.status == ContainerEvent.start) {
            startReceived();
            connection.stop(createdContainer.container);
          } else if (event.status == ContainerEvent.die) {
            // TODO(zoechi) wasn't able to make filter for events work
            // fail('"die" event was filtered out.');
          } else if (event.status == ContainerEvent.stop) {
            stopReceived();
            subscription.cancel();
          }
        }
      });

      await new Future.delayed(const Duration(milliseconds: 100));

      await connection.start(createdContainer.container);
    });
  });
}
