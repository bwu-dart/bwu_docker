@TestOn('vm')
library bwu_docker.test.docker;

import 'dart:io' show BytesBuilder;
import 'dart:convert' show JSON, UTF8;
import 'dart:async' show Completer, Future, Stream, StreamSubscription;
import 'package:test/test.dart';
import 'package:bwu_docker/src/remote_api.dart';
import 'package:bwu_docker/src/data_structures.dart';

const imageName = 'selenium/standalone-chrome';
const imageTag = '2.45.0';
const entryPoint = '/opt/bin/entry_point.sh';
 const runningProcess = '/bin/bash ${entryPoint}';
 const dockerPort = 2375;

// Docker-in-Docker to allow to test with different Docker version
// docker run --privileged -d -p 1234:1234 -e PORT=1234 jpetazzo/dind
//const imageName = 'busybox';
//const imageTag = 'buildroot-2014.02';
//const entryPoint = '/bin/sh';
//const runningProcess = '/bin/sh';
//const dockerPort = 1234;

const imageNameAndTag = '${imageName}:${imageTag}';

void main([List<String> args]) {
  //initLogging(args);

  DockerConnection connection;
  CreateResponse createdContainer;
  VersionResponse dockerVersion;

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

  final checkMinVersion = (Version supportedVersion) {
    if (dockerVersion.apiVersion < supportedVersion) {
      print(
          'Test skipped because this command is not supported in versions below ${supportedVersion}.');
      return false;
    }
    return true;
  };

  setUp(() async {
    connection = new DockerConnection('localhost', dockerPort);
    await connection.init();
    assert(connection.dockerVersion != null);
    try {
      await connection.image(new Image(imageNameAndTag));
    } on DockerRemoteApiError {
      final createResponse = await connection.createImage(imageNameAndTag);
      for (var e in createResponse) {
        print('${e.status} - ${e.progressDetail}');
      }
    }
    dockerVersion = await connection.version();
//    print(imageResponse);
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
              new CreateContainerRequest()..image = imageNameAndTag);

          // verification
          expect(createdContainer.container, new isInstanceOf<Container>());
          expect(createdContainer.container.id, isNotEmpty);
        });

        test('with name', () async {
          final supportedVersion = new Version.fromString('1.17');
          if (!checkMinVersion(supportedVersion)) {
            return;
          }

          // set up
          const containerName = '/dummy_name';

          // exercise
          createdContainer = await connection.createContainer(
              new CreateContainerRequest()..image = imageNameAndTag,
              name: 'dummy_name');
          expect(createdContainer.container, new isInstanceOf<Container>());
          expect(createdContainer.container.id, isNotEmpty);
//          print(createdContainer.container.id);

          final Iterable<Container> containers = await connection.containers(
              filters: {'name': [containerName]}, all: true);

//          print(containers);
          // verification
          expect(containers.length, greaterThan(0));
          expect(
              containers, everyElement((c) => c.names.contains(containerName)));
        });
      });

      group('logs', () {
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

//          print(buf.length);
//          print(buf.toBytes());

          // verification
          expect(buf, isNotNull);
        }, skip: 'find a way to produce log output, currently the returned data is always empty');
      });

      group('start', () {
        test('simple', () async {
          // set up
          createdContainer = await connection.createContainer(
              new CreateContainerRequest()..image = imageNameAndTag);

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
        test('simple', () async {
          // set up
          createdContainer = await connection.createContainer(
              new CreateContainerRequest()..image = imageNameAndTag);

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
              attachStdin: true, tty: true,
              //cmd: ['/bin/sh -c "echo sometext > /tmp/somefile.txt"', '/bin/sh -c ls -la']);
              cmd: ['echo hallo']);
          final startResponse = await connection.execStart(createdExec);

          await for(var x in startResponse.stdout) {
            print('x: ${UTF8.decode(x)}');
          }
          await new Future.delayed(const Duration(
              milliseconds: 500)); // TODO(zoechi) check if necessary

          print('4');
          // exercise
          final ChangesResponse changesResponse =
              await connection.changes(createdContainer.container);
          print('changes: ${changesResponse.changes}');
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
          final supportedVersion = new Version.fromString('1.17');
          if (!checkMinVersion(supportedVersion)) {
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
        }, skip: 'restart seems not to work properly (also not at the console)');
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

      group('attach', () {
        test('simple', () async {
          final supportedVersion = new Version.fromString('1.17');
          if (!checkMinVersion(supportedVersion)) {
            return;
          }

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
      }, skip: 'complete test when `commit` is implemented');
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
        await for (var v in startResponse) {
          print('startResonse: ${v}');
        }
      });
    });

    // TODO(zoechi) implement test for execStart()
    // TODO(zoechi) implement test for execResize()
    // TODO(zoechi) implement test for execInspect()
  });

  group('events', () {
    test('filter start/die/stop', () async {
      final CreateResponse createdContainer = await connection.createContainer(
          new CreateContainerRequest()..image = imageNameAndTag);
      final startReceived = expectAsync(() {});
      //final dieReceived = expectAsync(() {});
      final stopReceived = expectAsync(() {});
      StreamSubscription subscription;
      subscription = connection.events(filters: new EventsFilter()
        ..events.addAll([ContainerEvent.die])
        ..containers.add(createdContainer.container)).listen((event) {
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

  group('version', () {
    test('create', () {
      final v1 = new Version.fromString('1.2.3');
      expect(v1.major, 1);
      expect(v1.minor, 2);
      expect(v1.patch, 3);

      final v2 = new Version.fromString('10.20.30');
      expect(v2.major, 10);
      expect(v2.minor, 20);
      expect(v2.patch, 30);

      final v3 = new Version.fromString('1.2');
      expect(v3.major, 1);
      expect(v3.minor, 2);
      expect(v3.patch, null);
    });

    test('create invalid', () {
      expect(() => new Version.fromString('1'), throws);
      expect(() => new Version.fromString('.2'), throws);
      expect(() => new Version.fromString('..2'), throws);
      expect(() => new Version.fromString('1..2'), throws);
      expect(() => new Version.fromString('1..'), throws);
      expect(() => new Version.fromString('.'), throws);
      expect(() => new Version.fromString('..'), throws);
      expect(() => new Version.fromString('...'), throws);
      expect(() => new Version.fromString('0.1.-1'), throws);
      expect(() => new Version.fromString('1.2.3.4'), throws);
      expect(() => new Version.fromString('1.2.a'), throws);
      expect(() => new Version.fromString('1.2.3a'), throws);
      expect(() => new Version.fromString('1.2.3-a'), throws);
    });

    test('equals', () {
      expect(new Version.fromString('1.1.1') == new Version.fromString('1.1.1'),
          true);
      expect(new Version.fromString('1.2.3') == new Version.fromString('1.2.3'),
          true);
      expect(new Version.fromString('3.2.1') == new Version.fromString('3.2.1'),
          true);
      expect(new Version.fromString('0.1.2') == new Version.fromString('0.1.2'),
          true);
      expect(new Version.fromString('0.0.1') == new Version.fromString('0.0.1'),
          true);
      expect(new Version.fromString('0.0.0') == new Version.fromString('0.0.0'),
          true);
      expect(new Version.fromString('10.20.30') ==
          new Version.fromString('10.20.30'), true);
      expect(
          new Version.fromString('1.1') == new Version.fromString('1.1'), true);
      expect(
          new Version.fromString('1.2') == new Version.fromString('1.2'), true);
      expect(
          new Version.fromString('2.1') == new Version.fromString('2.1'), true);
      expect(
          new Version.fromString('0.1') == new Version.fromString('0.1'), true);
      expect(
          new Version.fromString('0.0') == new Version.fromString('0.0'), true);

      expect(new Version.fromString('1.2.3') == new Version.fromString('0.0.0'),
          false);
      expect(new Version.fromString('0.0.0') == new Version.fromString('1.2.3'),
          false);
      expect(new Version.fromString('1.2') == new Version.fromString('0.0'),
          false);
      expect(new Version.fromString('0.0.0') == new Version.fromString('0.0'),
          false);
    });

    test('greater than', () {
      expect(new Version.fromString('0.0.1') > new Version.fromString('0.0.0'),
          true);
      expect(new Version.fromString('0.1.0') > new Version.fromString('0.0.1'),
          true);
      expect(new Version.fromString('1.0.0') > new Version.fromString('0.0.1'),
          true);
      expect(new Version.fromString('10.0.0') > new Version.fromString('9.0.0'),
          true);
      expect(new Version.fromString('0.10.0') > new Version.fromString('0.9.0'),
          true);
      expect(
          new Version.fromString('10.0') > new Version.fromString('9.0'), true);
      expect(
          new Version.fromString('0.10') > new Version.fromString('0.9'), true);

      expect(new Version.fromString('0.0.0') > new Version.fromString('0.0.1'),
          false);
      expect(new Version.fromString('0.0.1') > new Version.fromString('0.1.0'),
          false);
      expect(new Version.fromString('0.0.1') > new Version.fromString('1.0.0'),
          false);
      expect(new Version.fromString('9.0.0') > new Version.fromString('10.0.0'),
          false);
      expect(new Version.fromString('0.9.0') > new Version.fromString('0.10.0'),
          false);
      expect(new Version.fromString('0.0.9') > new Version.fromString('0.0.10'),
          false);
      expect(new Version.fromString('9.0') > new Version.fromString('10.0'),
          false);
      expect(new Version.fromString('0.9') > new Version.fromString('0.10'),
          false);
    });

    test('less than', () {
      expect(new Version.fromString('0.0.0') < new Version.fromString('0.0.1'),
          true);
      expect(new Version.fromString('0.0.1') < new Version.fromString('0.1.0'),
          true);
      expect(new Version.fromString('0.0.1') < new Version.fromString('1.0.0'),
          true);
      expect(new Version.fromString('9.0.0') < new Version.fromString('10.0.0'),
          true);
      expect(new Version.fromString('0.9.0') < new Version.fromString('0.10.0'),
          true);
      expect(new Version.fromString('0.0.9') < new Version.fromString('0.0.10'),
          true);
      expect(
          new Version.fromString('9.0') < new Version.fromString('10.0'), true);
      expect(
          new Version.fromString('0.9') < new Version.fromString('0.10'), true);

      expect(new Version.fromString('0.0.1') > new Version.fromString('0.0.0'),
          true);
      expect(new Version.fromString('0.1.0') > new Version.fromString('0.0.1'),
          true);
      expect(new Version.fromString('1.0.0') > new Version.fromString('0.0.1'),
          true);
      expect(new Version.fromString('10.0.0') > new Version.fromString('9.0.0'),
          true);
      expect(new Version.fromString('0.10.0') > new Version.fromString('0.9.0'),
          true);
      expect(
          new Version.fromString('10.0') > new Version.fromString('9.0'), true);
      expect(
          new Version.fromString('0.10') > new Version.fromString('0.9'), true);
    });
  });
}
