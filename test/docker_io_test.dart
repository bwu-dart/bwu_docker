@TestOn('vm')
library bwu_docker.test.docker;

import 'dart:io' as io;
import 'package:bwu_utils/bwu_utils_server.dart';
import 'package:bwu_utils_dev/testing_server.dart';
import 'package:bwu_docker/src/docker_io.dart';
import 'package:bwu_docker/src/data_structures.dart';


void main([List<String> args]) {
  initLogging(args);

  group('docker_io', () {
    test('simple', () async {
      // set up
      final docker = new ContainerProcess('selenium/standalone-chrome', imageVersion: '2.45.0');
      docker.ports.add(new Port(4444,4444));
      io.ProcessResult proc = docker.run();
      expect(docker.id, isNotEmpty);
      print(proc.stdout);
      print(proc.stderr);
      proc = docker.stop();
      print(proc.stdout);
      print(proc.stderr);


      // exercise

      // verification
      // tear down
    });
  });

  group('ContainerInfo', () {
    test('get by incpect', () {
      const imageName = 'selenium/standalone-chrome';
      const imageVersion ='2.45.0';
      final docker = new ContainerProcess(imageName, imageVersion: imageVersion);
      io.ProcessResult result = docker.run();
      expect(result.exitCode, 0);
      expect(docker.id, isNotEmpty);

      final ci = DockerCommand.inspectContainer(docker.id);
      expect(ci.config.imageName, imageName);
      expect(ci.config.imageVersion, imageVersion);
      result = docker.stop();
      expect(result.exitCode, 0);
    });
  });

  group('ImageInfo', () {
    test('get by incpect', () {
      const imageName = 'selenium/standalone-chrome';
      const imageVersion ='2.45.0';
      final docker = new ContainerProcess(imageName, imageVersion: imageVersion);
      io.ProcessResult result = docker.run();
      expect(result.exitCode, 0);
      expect(docker.id, isNotEmpty);

      final ci = DockerCommand.inspectContainer(docker.id);
      final ii = DockerCommand.inspectImage(ci.config.image);
      expect(ci.image, ii.id);
      result = docker.stop();
      expect(result.exitCode, 0);

    });
  });

  group('ps', () {
    test('ps', () async {
      // var result = DockerCommand.ps();
      //io.File f = new io.File('unix:///var/run/docker.sock');
      final port = await getFreeIpPort();
      final ncat = new NCatSocketProcess();
      //await ncat.run(port);
      //final io.Socket socket = await io.Socket.connect('localhost', 2375);
      //socket.listen((d) => print('data: $d'));
      //socket.add('GET /containers/json'.codeUnits);
      //final io.HttpClientRequest req = await new io.HttpClient().getUrl(Uri.parse('http://localhost:${port}/containers/json'));
      final io.HttpClientRequest req = await new io.HttpClient().getUrl(Uri.parse('http://localhost:2375/containers/json'));
      req.close();
      final io.HttpClientResponse resp = await req.done;
      print('data: ${new String.fromCharCodes(await resp.expand((e) => e).toList())}');

      ncat.stop();
    });

  });

}

