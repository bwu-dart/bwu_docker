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
  CreateResponse createdContainer;

  final removeContainer = () async {
    if (createdContainer != null) {
      try {
        //print('--- remove --- ${createdResponse.container.id}');
        await connection.kill(createdContainer.container, signal: 'SIGKILL');
        await connection.removeContainer(createdContainer.container,
            force: true);
      } catch (e) {
        print('--- remove --- ${createdContainer.container.id} failed - ${e}');
      }
    }
  };

  setUp(() async {
    connection = new DockerConnection('localhost', 2375);
    var imageResponse;
    try {
      imageResponse = await connection.image(new Image(imageNameAndVersion));
    } on DockerRemoteApiError {
      final createResponse = await connection.createImage(imageNameAndVersion);
      for (var e in createResponse) {
        print('${e.status} - ${e.progressDetail}');
      }
    }
    print(imageResponse);
  });

  test('dummy', () {}, timeout: const Timeout(const Duration(seconds: 300)));

  group('containers', () {
    tearDown(() async {
      await removeContainer();
    });

    // Need different setUp()
    group('', () {
      group('create', () {
        test('simple', () async {
          // exercise
          createdContainer = await connection.createContainer(
              new CreateContainerRequest()..image = imageNameAndVersion);

          // verification
          expect(createdContainer.container, new isInstanceOf<Container>());
          expect(createdContainer.container.id, isNotEmpty);
        });

        test('with name', () async {
          // set up
          const containerName = '/dummy_name';

          // exercise
          createdContainer = await connection.createContainer(
              new CreateContainerRequest()..image = imageNameAndVersion,
              name: 'dummy_name');
          expect(createdContainer.container, new isInstanceOf<Container>());
          expect(createdContainer.container.id, isNotEmpty);

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
          createdContainer = await connection.createContainer(
              new CreateContainerRequest()
            ..image = imageNameAndVersion
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
          createdContainer = await connection.createContainer(
              new CreateContainerRequest()..image = imageNameAndVersion);

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
        });
      });

      group('commit', () {
        test('simple', () async {
          // set up
          createdContainer = await connection.createContainer(
              new CreateContainerRequest()..image = imageNameAndVersion);

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
          print(commitResponse.id);

          final ImageInfo committedContainer =
              await connection.image(new Image(commitResponse.id));

          expect(committedContainer.author, 'someAuthor');
          expect(committedContainer.config.exposedPorts.keys,
              anyElement('22/tcp'));

          await connection.removeImage(new Image(commitResponse.id));
        });
      });
    });

    // with container started in setUp
    group('', () {
      setUp(() async {
        createdContainer = await connection.createContainer(
            new CreateContainerRequest()..image = imageNameAndVersion);
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
          expect(containers, anyElement((c) => c.image == imageNameAndVersion));
        });

        test('containers all: true', () async {
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
      });

      group('container', () {
        test('simple', () async {
          // exercise
          final ContainerInfo container =
              await connection.container(createdContainer.container);

          // verification
          expect(container, new isInstanceOf<ContainerInfo>());
          expect(container.id, createdContainer.container.id);
          expect(container.config.cmd, ['/opt/bin/entry_point.sh']);
          expect(container.config.image, imageNameAndVersion);
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
          expect(topResponse.processes, anyElement((e) =>
              e.any((i) => i.contains('/bin/bash /opt/bin/entry_point.sh'))));
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
          expect(topResponse.processes, anyElement((e) =>
              e.any((i) => i.contains('/bin/bash /opt/bin/entry_point.sh'))));
        });
      });

      group('changes', () {
        test('simple', () async {
          // exercise
          final ChangesResponse changesResponse =
              await connection.changes(createdContainer.container);

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
              await connection.export(createdContainer.container);
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
          await connection.stats(createdContainer.container);

          // verification
          // TODO(zoechi)
        }, skip: 'check API version and skip the test when version < 1.17 when /info request is implemented');
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

          final referenceTime = new DateTime.now().toUtc();

          // exercise
          final SimpleResponse stopResponse =
              await connection.stop(createdContainer.container);
          final ContainerInfo stoppedStatus =
              await connection.container(createdContainer.container);

          print(
              'ref: ${referenceTime} finishedAt: ${stoppedStatus.state.finishedAt}');
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
          expect(restartedStatus.state.running, isFalse);
          expect(restartedStatus.state.startedAt.millisecondsSinceEpoch,
              greaterThan(
                  startedStatus.state.startedAt.millisecondsSinceEpoch));

          await new Future.delayed(const Duration(milliseconds: 100), () {});
        }, skip: 'restart seems not to work properly (also not at the console');
      });

      group('kill', () {
        test('simple', () async {
          // set up
          final ContainerInfo startedStatus =
              await connection.container(createdContainer.container);
          expect(startedStatus.state.running, isNotNull);

          final referenceTime = new DateTime.now().toUtc();

          // exercise
          final SimpleResponse killResponse = await connection.kill(
              createdContainer.container, signal: 'SIGKILL');
          await new Future.delayed(const Duration(milliseconds: 100), () {});
          final ContainerInfo killedStatus =
              await connection.container(createdContainer.container);

          print(
              'ref: ${referenceTime} finishedAt: ${killedStatus.state.finishedAt}');

          // verification
          expect(killResponse, isNotNull);
          expect(killedStatus.state.running, isFalse);
          expect(killedStatus.state.exitCode, -1);
          // TODO(zoechi) flaky, do a different check to verify if kill worked properly
          //expect(killedStatus.state.finishedAt.millisecondsSinceEpoch,
          //    greaterThan(referenceTime.millisecondsSinceEpoch));
          expect(killedStatus.state.finishedAt.millisecondsSinceEpoch,
              lessThan(new DateTime.now().millisecondsSinceEpoch));
        });
      });

      group('rename', () {
        test('simple', () async {
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
          expect(renamedStatus.name, 'SomeOtherName');
        }, skip: 'execute test only if Docker API version is > 1.17');
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

      group('attach', () {
        test('simple', () async {
          // exercise
          final Stream attachResponse = await connection.attach(
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
  });

  group('images', () {
    group('images', () {
      test('simple', () async {
        // exercise
        Iterable<ImageInfo> images = await connection.images();
        print('Images count: ${images.length}');

        // verification
        expect(images, isNotEmpty);
        expect(images.first.id, isNotEmpty);
        expect(images,
            anyElement((img) => img.repoTags.contains(imageNameAndVersion)));
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
        final Iterable<ImageInfo> updatedImages =
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
            await connection.createImage(imageNameAndVersion);
        expect(createImageResponse.first.status,
            'Pulling repository ${imageName}');
        expect(createImageResponse.length, greaterThan(10));
      });
    });

    group('image', () {
      test('simple', () async {
        final ImageInfo imageResponse =
            await connection.image(new Image(imageNameAndVersion));
        expect(imageResponse.config.cmd, contains('/opt/bin/entry_point.sh'));
      });
    });

    group('history', () {
      test('simple', () async {
        final Iterable<ImageHistoryResponse> imageHistoryResponse =
            await connection.history(new Image(imageNameAndVersion));
        expect(imageHistoryResponse.length, greaterThan(3));
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
      }, skip: 'complete test when `commit` is implemented');
    });

    group('tag', () {
      test('simple', () async {
        final SimpleResponse imageTagResponse = await connection.tag(
            new Image(imageNameAndVersion), 'SomeRepo', 'SomeTag');
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
            new Image(imageNameAndVersion), imageName, 'removeImage');
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

    group('auth', () {
      test('simple', () async {
//        Succeeds with real password
//        final AuthResponse authResponse = await connection.auth(
//            new AuthRequest('zoechi', 'xxxxx', 'guenter@gzoechbauer.com',
//                'https://index.docker.io/v1/'));
//        expect(authResponse, isNotNull);
//        expect(authResponse.status, 'Login Succeeded');

        expect(connection.auth(new AuthRequest('zoechi', 'xxxxx',
                'guenter@gzoechbauer.com', 'https://index.docker.io/v1/')),
            throwsA((e) => e is DockerRemoteApiError &&
                e.body == 'Wrong login/password, please try again\n'));
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
        expect(versionResponse.apiVersion, isNotEmpty);
        expect(versionResponse.architecture, isNotEmpty);
        expect(versionResponse.gitCommit, isNotEmpty);
        expect(versionResponse.goVersion, isNotEmpty);
        expect(versionResponse.kernelVersion, isNotEmpty);
        expect(versionResponse.os, isNotEmpty);
        expect(versionResponse.version, isNotEmpty);
      });
    });

    group('ping', () {
      test('simple', () async {
        final SimpleResponse pingResponse = await connection.ping();
        expect(pingResponse, isNotNull);
      });
    });
  });

  group('events', () {
    test('create', () async {
      final createdContainer = await connection.createContainer(
          new CreateContainerRequest()..image = imageNameAndVersion);
      final eventReceived = expectAsync(() {});
      connection
          .events() //until : new DateTime.now(), filters: new EventFilter()..events.addAll(DockerEvent.values))
          .then((response) {
        //expect(response.first.status, DockerEvent.containerStart);
        //eventReceived();
      });

      await new Future.delayed(const Duration(milliseconds: 500));

      for (int i = 0; i < 10; i++) {
        print(i);
        await connection.start(createdContainer.container);
        await new Future.delayed(const Duration(milliseconds: 3500));
        await connection.stop(createdContainer.container);
        await new Future.delayed(const Duration(milliseconds: 1500));
      }
    }, timeout: const Timeout(const Duration(seconds: 120)));
  });
}
