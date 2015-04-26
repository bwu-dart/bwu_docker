@TestOn('vm')
library bwu_docker.test.docker;

import 'dart:io' as io;
import 'package:bwu_utils/bwu_utils_server.dart';
import 'package:bwu_utils_dev/testing_server.dart';
import 'package:bwu_docker/src/remote_api.dart';
import 'package:bwu_docker/src/data_structures.dart';



void main([List<String> args]) {
  initLogging(args);

  group('remote_api', () {
    test('create', () async {
      // set up
      final imageName = 'selenium/standalone-chrome';
      final imageVersion = '2.45.0';
      //final port = getFreeIpPort();
      final connection = new DockerConnection('localhost' ,2375);

      // exercise
      var response = await connection.create(new CreateContainerRequest()..image = '${imageName}:${imageVersion}');

      // verification
      expect(response.container, new isInstanceOf<Container>());
      expect(response.container.id, isNotEmpty);

      // tear down
    });

    test('create', () async {
      // set up
      final imageName = 'selenium/standalone-chrome';
      final imageVersion = '2.45.0';
      //final port = getFreeIpPort();
      final connection = new DockerConnection('localhost' ,2375);
      var container = await connection.create(new CreateContainerRequest()..image = '${imageName}:${imageVersion}');
      expect(container.container, new isInstanceOf<Container>());
      expect(container.container.id, isNotEmpty);

      // exercise
      var response = await connection.start(container.container);
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
    }, skip: 'wip');
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

    },skip: 'wip');
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
    },skip: 'wip');

  });

}

