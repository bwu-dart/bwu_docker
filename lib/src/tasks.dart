library bwu_docker.src.tasks;

import 'dart:async' show Future;

import 'package:bwu_docker/bwu_docker.dart';
import 'dart:collection';

/// Stops and removes all containers and removes all images.
///
///     !!! Caution !!!
///
/// this function completely purges everything from the Docker service.
///
/// This is to clean up the Docker instance where I run the Docker tests.
/// I use Docker-in-Docker for this.
/// Returns a map
/// `{
///     'Stopped': <Container>[], // stopped containers
///     'RemovedContainers': <Container>[], removed containers,
///     'RemovedImages': <ImageInfo>, // removed images
/// }`
/// containing the collections of
/// - running containers which were stopped
/// - containers which were removed
/// - images which were removed
Future<PurgeAllResult> purgeAll(DockerConnection connection) async {
  return new PurgeAllResult(await stopAllContainers(connection),
      await removeAllExitedContainers(connection),
      await removeAllImages(connection));
}

/// Container containing information about the result of [purgeAll].
class PurgeAllResult {
  UnmodifiableListView<Container> _stoppedContainers;
  UnmodifiableListView<Container> get stoppedContainers => _stoppedContainers;

  UnmodifiableListView<Container> _removedContainers;
  UnmodifiableListView<Container> get removedContainers => _removedContainers;

  UnmodifiableListView<ImageInfo> _removedImages;
  UnmodifiableListView<ImageInfo> get removedImages => _removedImages;

  PurgeAllResult(Iterable<Container> stoppedContainers,
      Iterable<Container> removedContainers,
      Iterable<ImageInfo> removedImages) {
    _stoppedContainers = new UnmodifiableListView<Container>(stoppedContainers);
    _removedContainers = new UnmodifiableListView<Container>(removedContainers);
    _removedImages = new UnmodifiableListView<ImageInfo>(removedImages);
  }
}

/// Stop all running containers.
/// Returns the containers it tried to remove.
Future<Iterable<Container>> stopAllContainers(
    DockerConnection connection) async {
  final Iterable<Container> containers = await connection.containers();
  await Future.wait(containers.map((c) => connection.stop(c)));
  return containers;
}

/// Remove all stopped containers.
Future<Iterable<Container>> removeAllExitedContainers(
    DockerConnection connection) async {
  final Iterable<Container> stoppedContainers =
      await connection.containers(filters: {'status': ['exited']});

  await Future
      .wait(stoppedContainers.map((c) => connection.removeContainer(c)));
  return stoppedContainers;
}

/// Remove all images.
/// If images are referenced by containers they can't be removed.
Future<Iterable<ImageInfo>> removeAllImages(DockerConnection connection) async {
  final Iterable<ImageInfo> images = await connection.images();
  await Future.wait(images.map((i) => connection.removeImage(new Image(i.id))));
  return images;
}
