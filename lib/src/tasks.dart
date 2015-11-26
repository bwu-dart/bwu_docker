library bwu_docker.src.tasks;

import 'dart:async' show Future, StreamSubscription;

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
  return new PurgeAllResult(
      await stopAllContainers(connection),
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

  PurgeAllResult(
      Iterable<Container> stoppedContainers,
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
      await connection.containers(filters: {
    'status': ['exited']
  });

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

/// Provides a "run" command similar to the Docker command line client.
/// TODO(zoechi) This implementation is incomplete and supports only a very
/// limited set of arguments.
Future<CreateResponse> run(DockerConnection connection, String image,
    {List<String> attach: const [],
    List<String> addHost,
    List<String> command,
    bool detach: false,
    List<String> link,
    String name,
    bool privileged: false,
    bool publishAll: false,
    List<String> publish,
    bool rm: false,
    List<String> volume}) async {
  assert(connection != null);
  assert(image != null && image.isNotEmpty);

  assert(attach != null);
  attach = attach.map((e) => e.toLowerCase()).toList();
  assert(attach.every((e) => const ['stdin', 'stdout', 'stderr'].contains(e)));
  assert(detach != null);
  assert(publishAll != null);
  assert(privileged != null);
  assert(rm != null);

  final createContainerRequest = new CreateContainerRequest()
    ..image = image
    ..hostConfig = new HostConfigRequest();

  if (addHost != null && addHost.isNotEmpty) {
    createContainerRequest.hostConfig.extraHosts = addHost;
  }

  if (command != null && command.isNotEmpty) {
    createContainerRequest.cmd = command;
  }

  if (link != null && link.isNotEmpty) {
    createContainerRequest.hostConfig.links = link;
  }

  if (privileged) {
    createContainerRequest.hostConfig.privileged = privileged;
  }

  if (publishAll) {
    createContainerRequest.hostConfig.publishAllPorts = publishAll;
  }

  if (publish != null && publish.isNotEmpty) {
    assert(publish.every((String p) => p != null && p.isNotEmpty));
    final Map<String, List<PortBinding>> portBindings =
        parsePublishArgument(publish);
    createContainerRequest.hostConfig.portBindings = portBindings;
    createContainerRequest.exposedPorts.addAll(new Map.fromIterable(
        portBindings.keys,
        key: (k) => k,
        value: (_) => const {}));
  }

  if (volume != null && volume.isNotEmpty) {
    createContainerRequest.hostConfig.binds = volume;
  }

  createContainerRequest.attachStdin = attach.contains('stdin') && !detach;
  createContainerRequest.attachStdout = attach.contains('stdout') && !detach;
  createContainerRequest.attachStderr = attach.contains('stderr') && !detach;

  await _ensureImageExists(connection, image);

  final CreateResponse createdResponse =
      await connection.createContainer(createContainerRequest, name: name);

  // If `rm` is `true` listen for events which indicate the container was
  // stopped. Check again after some delay and then remove the container.
  if (rm) {
    StreamSubscription eventsSubscription;
    eventsSubscription = connection.events(filters: new EventsFilter()
      ..events.addAll([ContainerEvent.stop, ContainerEvent.kill, ContainerEvent.die])
      ..containers.add(createdResponse.container)).listen((event) {
      new Future.delayed(const Duration(milliseconds: 200), () async {
        final Iterable<Container> containers =
            await connection.containers(filters: {
          'status': [ContainerStatus.exited.toString()]
        });
        if (containers.any((c) => c.id == createdResponse.container.id)) {
          try {
            await connection.removeContainer(createdResponse.container);
          } catch (e) {
            print(e);
          }
          eventsSubscription.cancel();
        }
      });
    });
  }

  await connection.start(createdResponse.container);
  return createdResponse;
}

/// Creates a [PortBindings] map from a "publish" argument supported by the
/// command line client. For example `4444:4444' or `2000-2005:3000-3005`.
// TODO(zoechi) complete incomplete implementation and tests
Map<String, List<PortBinding>> parsePublishArgument(List<String> publish) {
  final Map<String, List<PortBinding>> portBindings =
      <String, List<PortBinding>>{};

  publish.forEach((p) {
    String hostIp;
    String hostPort;
    String containerPort;
    String protocol = '/tcp';

    final List<String> parts = p.split(':');
    if (parts.length == 1) {
      containerPort = parts[0];
    } else if (parts.length == 2) {
      hostPort = parts[0];
      containerPort = parts[1];
    } else if (parts.length == 3) {
      hostIp = parts[0];
      hostPort = parts[1];
      containerPort = parts[2];
    } else {
      throw new ArgumentError.value(p, 'publish', 'Invalid value.');
    }

    if (containerPort == null ||
        containerPort.isEmpty) throw new ArgumentError.value(
        p, 'publish', 'Invalid value.');
    if (containerPort.contains('-')) {
      final List<String> containerPortsRange = containerPort.split('-');
      if (containerPortsRange.length != 2 ||
          containerPortsRange.any((String p) => p.isEmpty)) {
        throw new ArgumentError.value(
            containerPort, 'publish', 'Invalid container port range.');
      }
      int containerPortsFrom = int.parse(containerPortsRange[0]);
      int containerPortsTo;
      if (containerPortsRange[1].contains('/')) {
        final List<String> containerPortParts =
            containerPortsRange[1].split('/');
        containerPortsTo = int.parse(containerPortParts[0]);
        protocol = '/${containerPortParts[1]}';
      } else {
        containerPortsTo = int.parse(containerPortsRange[1]);
      }

      int hostPortsFrom;
      int hostPortsTo;

      if (hostPort != null && hostPort.isNotEmpty) {
        final hostPortsRange = hostPort.split('-');

        if (hostPortsRange.length != 2 ||
            hostPortsRange.any((p) => p.isEmpty)) {
          throw new ArgumentError.value(
              hostPort, 'publish', 'Invalid host port range.');
        }
        hostPortsFrom = int.parse(hostPortsRange[0]);
        hostPortsTo = int.parse(hostPortsRange[1]);

        if ((containerPortsTo - containerPortsFrom) !=
            (hostPortsTo - hostPortsFrom)) {
          throw new ArgumentError.value(publish, 'publish',
              'Container port rang and host port range must contain the same number of ports.');
        }
      }

      for (int i = 0; i <= containerPortsTo - containerPortsFrom; i++) {
        final portBinding = new PortBindingRequest();

        if (hostPortsFrom != null) {
          portBinding.hostPort = '${hostPortsFrom + i}';
        }
        if (hostIp != null) {
          portBinding.hostIp = hostIp;
        }
        portBindings['${containerPortsFrom + i}${protocol}'] = [portBinding];
      }
    } else {
      final PortBindingRequest portBinding = new PortBindingRequest();

      if (containerPort.contains('/')) {
        final List<String> containerPortParts = containerPort.split('/');
        containerPort = containerPortParts[0];
        protocol = '/${containerPortParts[1]}';
      }

      if (hostPort != null) {
        portBinding.hostPort = '${hostPort}';
      }
      if (hostIp != null) {
        portBinding.hostIp = hostIp;
      }
      portBindings['${containerPort}${protocol}'] = [portBinding];
    }
  });
  return portBindings;
}

/// Check if image exists or create it and wait until it is available.
Future _ensureImageExists(DockerConnection connection, String imageName) async {
  try {
    await connection.image(new Image(imageName));
  } on DockerRemoteApiError {
    final Iterable<CreateImageResponse> createResponse =
        await connection.createImage(imageName);
    for (var e in createResponse) {
      print('${e.status} - ${e.progressDetail}');
    }
  }
}
