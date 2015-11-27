/// Some helpers used in tests.
library bwu_docker.test.utils;

import 'dart:async' show Future;
import 'package:bwu_docker/bwu_docker_v1x15_to_v1x19.dart';

/// Check if image exists or create it.
Future ensureImageExists(DockerConnection connection, String imageName) async {
  try {
    await connection.image(new Image(imageName));
  } on DockerRemoteApiError {
//    final Iterable<CreateImageResponse> createResponse =
    await connection.createImage(imageName);
//    for (var e in createResponse) {
//      print('${e.status} - ${e.progressDetail}');
//    }
  }
}

/// Stop and remove a container and retry two times if removing didn't succeed
/// previously.
Future removeContainer(DockerConnection connection, Container container) async {
  if (container == null) {
    return;
  }
  bool removed = false;
  if (container != null) {
    int tries = 3;
    String errorMsg = '';
    while (container != null && tries > 0) {
      try {
        connection.stop(container, timeout: 3).catchError((_) {});
        await connection.wait(container);
        await connection.removeContainer(container,
            force: true, removeVolumes: true);
        removed = true;
      } on DockerRemoteApiError catch ( error) {
        if (error.statusCode == 404) {
          removed = true;
          break;
        }
        if (error.toString().isNotEmpty) {
          errorMsg = '${error}\n${error}';
        }
        await waitMilliseconds(100);
      }
      tries--;
    }
    if (!removed) {
      print('>>> remove ${container.id} failed - ${errorMsg}');
    }
  }
}

Future waitMilliseconds(int milliseconds) {
  return new Future.delayed(new Duration(milliseconds: milliseconds));
}
