@TestOn('vm')
library bwu_docker.test.docker;

import 'dart:io' as io;
import 'package:bwu_utils_dev/testing_server.dart';
import 'package:bwu_docker/src/docker.dart';
import 'dart:convert' show UTF8;

void main([List<String> args]) {
  initLogging(args);

  group('docker', () {
    test('simple', () async {
      // set up
      final docker = new Docker('selenium/standalone-chrome', imageVersion: '2.45.0');
      docker.ports.add(new Port(4444,4444));
      io.ProcessResult proc = docker.run();
      expect(docker.id, isNotEmpty);
      print(proc.stdout);
      print(proc.stderr);
      proc = docker.stop();
      print(proc.stdout);
      print(proc.stderr);

      //print(await proc.exitCode);

      // exercise

      // verification
      // tear down
    });
  });

  group('ContainerInfo', () {
    test('get', () {
      const imageName = 'selenium/standalone-chrome';
      const imageVersion ='2.45.0';
      final docker = new Docker(imageName, imageVersion: imageVersion);
      io.ProcessResult proc = docker.run();
      expect(docker.id, isNotEmpty);

      final ci = DockerCommand.inspectContainer(docker.id);
      expect(ci.config.imageName, imageName);
      expect(ci.config.imageVersion, imageVersion);
    print('x');
    });
  });
}

