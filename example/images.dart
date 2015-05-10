library bwu_docker.example.images;

import 'dart:io' as io;
import 'package:http/http.dart' as http;
import 'package:bwu_docker/bwu_docker.dart';

main() async {
  // initialize the connection to the Docker service
  final conn =
      new DockerConnection(Uri.parse(io.Platform.environment[dockerHostFromEnvironment]), new http.Client());
  await conn.init();

  // create a container from an image
  CreateResponse created = await conn.createContainer(
      new CreateContainerRequest()
    ..image = 'busybox'
    ..hostConfig.logConfig = {'Type': 'json-file'});

  // start the container
  await conn.start(created.container);

  // load the list of containers
  Iterable<Container> containers = await conn.containers();

  // investigate response
  var found = containers.firstWhere((c) => c.id == created.container.id);
  print('found: ${found.id}, name: ${found.names.join(', ')}\n');

  print('all:');
  containers.forEach((Container c) {
    print(
        'Container ID: ${c.id}, names: ${c.names.join(', ')}, status: ${c.status}');
  });

  // clean up
  await conn.stop(created.container);
  await conn.removeContainer(created.container);
}
