///
/// ////////////////////////////////////////
/// ///                                  ///
/// ///       !!! Caution !!!            ///
/// ///                                  ///
/// ////////////////////////////////////////
///
/// These tests will purge the used Docker instance by removing all containers
/// (running or not) and all images:
///
/// Use [DinD](https://github.com/bwu-dart/bwu_docker/wiki/Development-tips-&-tricks#run-docker-inside-docker)
/// and ensure the used `dockerPort` points to this Docker instance.
@TestOn('vm')
library bwu_docker.test.tasks;

import 'dart:io' as io;
import 'dart:async' show Future, Stream;
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:bwu_docker/bwu_docker_v1x15_to_v1x19.dart';
import 'package:bwu_docker/tasks_v1x15_to_v1x19.dart';
import 'utils.dart' as utils;

const String imageName = 'busybox';
const String imageTag = 'buildroot-2014.02';
const String entryPoint = '/bin/sh';
const String runningProcess = '/bin/sh';

const String imageNameAndTag = '${imageName}:${imageTag}';

Uri _uriUpdatePort(Uri uri, int port) {
  final Uri result = new Uri(
      scheme: uri.scheme, userInfo: uri.userInfo, host: uri.host, port: port);
  print('${result}');
  return result;
}

void main() {
  DockerConnection connection;
  CreateResponse createdContainer;

  /// setUp helper to create the image used in tests if it is not yet available.
  Future ensureImageExists() async {
    return utils.ensureImageExists(connection, imageNameAndTag);
  }

  /// setUp helper to create a container from the image used in tests.
  Future<Container> createContainer([String name]) async {
    createdContainer =
        await connection.createContainer(new CreateContainerRequest()
          ..image = imageNameAndTag
          ..cmd = ['/bin/sh']
          ..openStdin = true
          ..tty = true, name: name);
    return createdContainer.container;
  }
  ;

  setUp(() async {
    /// Use the DinD set up with a higher port than default to not interfere
    /// with the default test DinD when testing purging all containers and
    /// images.
    Uri uri = Uri.parse(io.Platform.environment[dockerHostFromEnvironment]);
    uri = _uriUpdatePort(uri, uri.port + 1);
    connection = new DockerConnection(uri, new http.Client());
    await connection.init();
    assert(connection.dockerVersion != null);
    //await ensureImageExists();
  });

  group('purgeAll', () {
    setUp(() async {
      await purgeAll(connection);

      final Iterable<ImageInfo> imagesAfter =
          await connection.images(all: true);
      expect(imagesAfter, isEmpty);

      await ensureImageExists();
      final Container keepRunning = await createContainer('keep_running');
      await connection.start(keepRunning);

      final Container stopped = await createContainer('stopped');
      await connection.start(stopped);
      await connection.stop(stopped);

      await createContainer('never_started');
    });

    test(
        'should remove all existing running and not-running containers and all images',
        () async {
      // set up
      final Iterable<Container> containersBefore =
          await connection.containers(all: true);
      expect(
          containersBefore
              .firstWhere((Container c) => c.names.contains('/keep_running'))
              .status,
          startsWith('Up '));
      expect(
          containersBefore
              .firstWhere((Container c) => c.names.contains('/stopped'))
              .status,
          startsWith('Exited'));
      expect(
          containersBefore
              .firstWhere((Container c) => c.names.contains('/never_started'))
              .status,
          '');

      final Iterable<ImageInfo> imagesBefore = await connection.images();
      expect(imagesBefore, isNotEmpty);

      // exercise
      final PurgeAllResult result = await purgeAll(connection);

      // verify
      expect(result.stoppedContainers,
          anyElement((Container c) => c.names.contains('/keep_running')));
      expect(result.stoppedContainers,
          isNot(anyElement((Container c) => c.names.contains('/stopped'))));
      expect(
          result.stoppedContainers,
          isNot(
              anyElement((Container c) => c.names.contains('/never_started'))));

      expect(result.removedContainers,
          anyElement((Container c) => c.names.contains('/keep_running')));
      expect(result.removedContainers,
          anyElement((Container c) => c.names.contains('/stopped')));
      expect(result.removedContainers,
          anyElement((Container c) => c.names.contains('/never_started')));

      // each container was removed
      expect(
          containersBefore,
          everyElement((Container c) => result.removedContainers
                  .firstWhere((Container r) => r.id == r.id) !=
              null));
      // each image was removed
      expect(
          imagesBefore,
          everyElement((ImageInfo i) =>
              result.removedImages.firstWhere((ImageInfo r) => r.id == i.id) !=
                  null));

      // Docker doesn't return any containers
      final Iterable<Container> containersAfter =
          await connection.containers(all: true);
      expect(containersAfter, isEmpty);

      final Iterable<ImageInfo> imagesAfter =
          await connection.images(all: true);
      expect(imagesAfter, isEmpty);
    }, timeout: new Timeout.factor(2));
  }, skip: true);

  group('run', () {
    test('should parse single port from `publish` argument', () {
      final Map<String, List<PortBinding>> singlePortBindings =
          parsePublishArgument(['1000:2000']);
      expect(singlePortBindings.containsKey('2000/tcp'), isTrue);
      expect(singlePortBindings['2000/tcp'].length, 1);
      expect(singlePortBindings['2000/tcp'][0].hostIp, isNull);
      expect(singlePortBindings['2000/tcp'][0].hostPort, '1000');
    });

    test('should parse a port range from `publish` argument', () {
      final Map<String, List<PortBinding>> rangePortBindings =
          parsePublishArgument(['1000-1005:2000-2005']);
      [1000, 1001, 1002, 1003, 1004, 1005].forEach((int k) {
        final String key = '${k + 1000}/tcp';
        expect(rangePortBindings.containsKey(key), isTrue);
        expect(rangePortBindings[key].length, 1);
        expect(rangePortBindings[key][0].hostIp, isNull);
        expect(rangePortBindings[key][0].hostPort, '${k}');
      });
    });

    test('rm=true should remove the container after it stopped', () async {
      // set up
      // exercise
      final CreateResponse createResponse = await run(
          connection, imageNameAndTag,
          detach: true,
          publish: const <String>['4444:4444'],
          rm: true,
          name: 'run-dummy',
          command: ['tail', '-f', '/etc/resolv.conf']);

      // verification
      await new Future.delayed(const Duration(milliseconds: 200), () async {
        final Iterable<Container> containers =
            await connection.containers(filters: {
          'status': [ContainerStatus.running.toString()]
        });
        expect(containers,
            anyElement((Container c) => c.id == createResponse.container.id));
      });

      // exercise
      await new Future.delayed(const Duration(milliseconds: 500), () async {
        await connection.stop(createResponse.container);

        // verification
        await new Future.delayed(const Duration(milliseconds: 500), () async {
          final Iterable<Container> containers = await connection.containers();
          expect(
              containers,
              isNot(anyElement(
                  (Container c) => c.id == createResponse.container.id)));
        });
      });
    }, timeout: const Timeout(const Duration(seconds: 180)));
  });
}
