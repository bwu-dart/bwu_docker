# Dart client for the Docker remote API

[![Star this Repo](https://img.shields.io/github/stars/bwu-dart/bwu_docker.svg?style=flat)](https://github.com/bwu-dart/bwu_docker)
[![Pub Package](https://img.shields.io/pub/v/bwu_docker.svg?style=flat)](https://pub.dartlang.org/packages/bwu_docker)
[![Build Status](https://travis-ci.org/bwu-dart/bwu_docker.svg?branch=master)](https://travis-ci.org/bwu-dart/bwu_docker)
[![Coverage Status](https://coveralls.io/repos/bwu-dart/bwu_docker/badge.svg?branch=master)](https://coveralls.io/r/bwu-dart/bwu_docker)

See [Docker Remote API v1.18](https://docs.docker.com/reference/api/docker_remote_api_v1.18/#image-tarball-format) 
for more details.

This package provides a typed interface to the Docker REST API and deserializes
JSON response to Dart classes.

The intention is to make it easy to automate Docker related tasks from 
[Grinder](https://pub.dartlang.org/packages/grinder) or other scripts.
This package also makes it easy to build a dashboard for the Docker service.

## Usage

See example below or the 
[unit tests](https://github.com/bwu-dart/bwu_docker/blob/master/test/remote_api_test.dart).

Ensure you have Docker listening on a TCP port (for more details see 
[Bind Docker to another host/port or a Unix socket](https://docs.docker.com/articles/basics/#bind-docker-to-another-hostport-or-a-unix-socket)),
because Dart currently can't communicate using Unix sockets (see 
[Dart Issue 21403 - Support Unix Sockets in dart:io](http://dartbug.com/21403) for details).


## Supported commands

### Containers
- **attach** (Attach to a container)
- **changes** (Changes to a containers file system)
- **container** (Inspect a container)
- **containers** (List containers)
- **copy** (Copy files or folders from a container)
- **create** (Create a container)
- **export** (Export a container)
- **kill** (Kill a container)
- **logs** (Get container logs)
- **pause** (Pause a container)
- **top** (List processes running inside a container) 
- **rename** (Rename a container)
- **remove** (Remove a container)
- **resize** (Resize a container TTY)
- **restart** (Restart a container)
- **start** (Start a container)
- **stats** (Get container stats based on resource usage)
- **stop** (Stop a container)
- **unpause** (Unpause a container)
- **wait** (Wait a container)

### Images
- **build** (missing test) (Build image from a Dockerfile)
- **create** (Create an image)
- **image** (Inspect an image)
- **images** (List images)
- **history** (Get the history of an image)
- **push** (missing test) (Push an image into a repository)
- **tag** (Tag an image into a repository)
- **remove** (Remove an image)
- **search** (Search images)

### Misc
- **auth** (Check auth configuration)
- **commit** (Create a new image from a containers changes)
- **events** (Monitor Dockers events)
- **exec create** (Set up an exec instance)
- **exec inspect** (Inspect an exec command) 
- **exec resize** (missing test) (Resize the tty session) 
- **exec start** (Start an exec instance)
- **get** (Get a tarball containing all images in a repository)
- **get all** (missing test) (Get a tarball containing all images)
- **info** (Display system-wide information)
- **load** (missing test) (Load a tarball with a set of images and tags into Docker)
- **ping** (Ping the docker server)
- **version** (Show the Docker version information)

## Feedback

I'm not a Docker specialist. If something isn't working as expected or you are
missing a feature just create a bug report in the 
[GitHub repo](https://github.com/bwu-dart/bwu_docker/issues) or even better, 
create a pull request.

## TODO
- container **attachWs** (Attach to a container using websocket)
- image **build** (missing test) (Build image from a Dockerfile)
- image **push** (missing test) (Push an image into a repository)
- misc **get all** (missing test) (Get a tarball containing all images)
- misc **load** (missing test) (Load a tarball with a set of images and tags into Docker)
- exec **resize** (missing test) (Resize the tty session) 
 



## Example

```dart
library bwu_docker.example.images;

import 'package:bwu_docker/bwu_docker.dart';

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
```

For more examples check out the [unit tests](https://github.com/bwu-dart/bwu_docker/blob/master/test/remote_api_test.dart).

Also check out the [BWU Docker wiki pages](https://github.com/bwu-dart/bwu_docker/wiki).
