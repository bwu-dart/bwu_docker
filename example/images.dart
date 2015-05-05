library bwu_docker.example.images;

import 'package:bwu_docker/src/remote_api.dart';
import 'package:bwu_docker/src/data_structures.dart';

const dockerPort = 2375;

main() async {
  // initialize the connection to the Docker service
  final conn = new DockerConnection('localhost', dockerPort);
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
