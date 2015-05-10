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
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:bwu_docker/bwu_docker.dart';
import 'package:bwu_docker/tasks.dart';
import 'utils.dart' as utils;

const imageName = 'busybox';
const imageTag = 'buildroot-2014.02';
const entryPoint = '/bin/sh';
const runningProcess = '/bin/sh';

const imageNameAndTag = '${imageName}:${imageTag}';

Uri _uriUpdatePort(Uri uri, int port) {
  final result = new Uri(
      scheme: uri.scheme, userInfo: uri.userInfo, host: uri.host, port: port);
  print('${result}');
  return result;
}

main() {
  DockerConnection connection;
  CreateResponse createdContainer;

  /// setUp helper to create the image used in tests if it is not yet available.
  final ensureImageExists = () async {
    return utils.ensureImageExists(connection, imageNameAndTag);
  };

  /// setUp helper to create a container from the image used in tests.
  final createContainer = ([String name]) async {
    createdContainer = await connection.createContainer(
        new CreateContainerRequest()
      ..image = imageNameAndTag
      ..cmd = ['/bin/sh']
      ..openStdin = true
      ..tty = true, name: name);
    return createdContainer.container;
  };

  setUp(() async {
    /// Use the DinD set up with a higher port than default to not interfere
    /// with the default test DinD when testing purging all containers and
    /// images.
    var uri = Uri.parse(io.Platform.environment[dockerHostFromEnvironment]);
    uri = _uriUpdatePort(uri, uri.port + 1);
    connection =
        new DockerConnection(uri, new http.Client());
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
      final keepRunning = await createContainer('keep_running');
      await connection.start(keepRunning);

      final stopped = await createContainer('stopped');
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
      expect(containersBefore
              .firstWhere((c) => c.names.contains('/keep_running')).status,
          startsWith('Up '));
      expect(containersBefore
              .firstWhere((c) => c.names.contains('/stopped')).status,
          startsWith('Exited'));
      expect(containersBefore
          .firstWhere((c) => c.names.contains('/never_started')).status, '');

      final Iterable<ImageInfo> imagesBefore = await connection.images();
      expect(imagesBefore, isNotEmpty);

      // exercise
      final PurgeAllResult result = await purgeAll(connection);

      // verify
      expect(result.stoppedContainers,
          anyElement((c) => c.names.contains('/keep_running')));
      expect(result.stoppedContainers,
          isNot(anyElement((c) => c.names.contains('/stopped'))));
      expect(result.stoppedContainers,
          isNot(anyElement((c) => c.names.contains('/never_started'))));

      expect(result.removedContainers,
          anyElement((c) => c.names.contains('/keep_running')));
      expect(result.removedContainers,
          anyElement((c) => c.names.contains('/stopped')));
      expect(result.removedContainers,
          anyElement((c) => c.names.contains('/never_started')));

      // each container was removed
      expect(containersBefore, everyElement((c) =>
          result.removedContainers.firstWhere((r) => r.id == r.id) != null));
      // each image was removed
      expect(imagesBefore, everyElement(
          (i) => result.removedImages.firstWhere((r) => r.id == i.id) != null));

      // Docker doesn't return any containers
      final Iterable<Container> containersAfter =
          await connection.containers(all: true);
      expect(containersAfter, isEmpty);

      final Iterable<ImageInfo> imagesAfter =
          await connection.images(all: true);
      expect(imagesAfter, isEmpty);
    }, timeout: new Timeout.factor(2));
  });
}
