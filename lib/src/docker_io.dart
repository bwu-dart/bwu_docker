library bwu_docker.src.docker;

import 'dart:async' show Completer, Future, Stream;
import 'dart:convert' show JSON;
import 'dart:io' as io;
import 'data_structures.dart';


class DockerCommand {
  static String executable = 'docker';

  /// [includeStopped] Show all containers. Only running containers are shown by
  ///   default. The default is false.
  /// [beforeId] Show only container created before Id or Name, include
  ///   non-running ones.
  /// [since] Show only containers created since Id or Name, include non-running
  ///   ones.
  /// [filter] Provide filter values. Valid filters:
  ///     exited= - containers with exit code of
  /// [latestOnly] Show only the latest created container, include non-running
  ///   ones. The default is false.
  /// [maxResultCount] Show n last created containers, include non-running ones.
  static void ps({bool includeStopped: false, String before, String since,
      String filter, bool latestOnly: false, int maxResultCount}) {
    assert(includeStopped != null);
    assert(latestOnly != null);

    final args = ['ps', '--no-trunc', '--size'];

    if (before != null) {
      args.add('--before=${before}');
    }

    if (since != null) {
      args.add('--since=${since}');
    }

    if (filter != null) {
      args.add('--filter=${filter}');
    }

    final result = io.Process.runSync(executable, args);
    if (io.exitCode == 0) {
      try {
        return JSON.decode(result.stdout);
      } catch (e) {
        print(result.stdout);
        print(result.stderr);
        rethrow;
      }
    }
    throw result;
  }
  static List inspect(String id) {
    assert(id != null && id.isNotEmpty);
    final args = ['inspect', id];
    final result = io.Process.runSync(executable, args);
    if (io.exitCode == 0) {
      try {
        return JSON.decode(result.stdout);
      } catch (e) {
        print(result.stdout);
        print(result.stderr);
        rethrow;
      }
    }
    throw result;
  }

  static ContainerInfo inspectContainer(String id,
      {String executable: 'docker'}) {
    final json = inspect(id);
    if (json[0]['Image'] == null) {
      throw '"${id}" is not a container id.';
    }
    return new ContainerInfo(json[0]);
  }

  static ImageInfo inspectImage(String id, {String executable: 'docker'}) {
    final json = inspect(id);
    if (json[0]['Container'] == null) {
      throw '"${id}" is not an image id.';
    }
    return new ImageInfo(json[0]);
  }
}

class ContainerProcess {
  final String executable;
  final Set<Port> ports = new Set<Port>();
  final String imageName;
  final String imageVersion;
  bool runAsDaemon;
  String _id;
  String get id => _id;

//  DockerProcess _process;
//  DockerProcess get process => _process;

  ContainerProcess(this.imageName, {this.imageVersion: 'latest',
      this.executable: 'docker', this.runAsDaemon: true}) {
    assert(imageName != null && imageName.isNotEmpty);
    assert(imageVersion != null && imageVersion.isNotEmpty);
    assert(executable != null && executable.isNotEmpty);
    assert(runAsDaemon != null);
  }

  // TODO(zoechi) write a test
  factory ContainerProcess.ContainerProcess(String id, {String executable: 'docker'}) {
    assert(id != null && id.isNotEmpty);
    assert(executable != null && executable.isNotEmpty);
    final args = ['inspect', id];
    final result = io.Process.runSync(executable, args);
    if (io.exitCode == 0) {
      final info = JSON.decode(result.stdout);
      //return new Docker(info[''], executable,  = info['id'];
    }
    return result;
  }

  io.ProcessResult run() {
    final args = ['run'];
    if (runAsDaemon) {
      args.add('-d');
    }
    ports.forEach((p) {
      args.add('-p=${p.toDockerArgument()}');
    });
    args.add('${imageName}:${imageVersion}');
    final result = io.Process.runSync(executable, args);
    if (io.exitCode == 0) {
      _id = result.stdout.split('\n').first;
    }
    return result;
  }

  io.ProcessResult stop() {
    final args = ['stop', id];
    if (id == null) {
      return null;
    }
    final result = io.Process.runSync(executable, args);
    if (io.exitCode == 0) {
      _id = null;
    }
    return result;
  }

//  DockerProcess runSomethingAsync() {
//      if (_process != null) {
//        throw 'Docker process already running. Stop the process before you start it again';
//      } else {
//        final args = ['run'];
//        if (isDaemon) {
//          args.add('-d');
//        }
//        ports.forEach((p) {
//          args.add('-p=${p.toDockerArgument()}');
//        });
//        args.add('${imageName}:${imageVersion}');
//        _process = new DockerProcess()
//          .runSync(executable, args);
//        return _process;
//      }
//    }
//  }

  // docker run -d -p 4444:4444 selenium/standalone-chrome:2.45.0

}



class BackgroundProcess {
  io.Process _process;
  io.Process get process => _process;

  Stream<List<int>> _stdoutStream;
  Stream<List<int>> get stdout => _stdoutStream;

  Stream<List<int>> _stderrStream;
  Stream<List<int>> get stderr => _stderrStream;

  Future<int> _exitCode;
  Future<int> get exitCode => _exitCode;

  BackgroundProcess();

  Completer<bool> _startedCompleter;

  Future<bool> get onStarted {
    if (_startedCompleter == null) {
      _startedCompleter = new Completer<bool>();
    }
    return _startedCompleter.future;
  }

  Future _run(String executable, List<String> args,
      {String workingDirectory}) async {
    if (_startedCompleter != null && !_startedCompleter.isCompleted) {
      _startedCompleter.completeError(false);
    }
    _startedCompleter = new Completer<bool>();
    if (process != null) {
      return process;
    }
    print('execute: ${executable} ${args.join(' ')}');
    try {
      _process = await io.Process.start(executable, args,
          workingDirectory: workingDirectory);
      _exitCode = process.exitCode;
      process.exitCode.then((exitCode) {
        _process = null;
      });
      _stdoutStream = process.stdout.asBroadcastStream();
      _stderrStream = process.stderr.asBroadcastStream();

    } catch (e) {
      _process = null;
    } finally {
      _startedCompleter.complete(_process != null);
    }


//    stdout.listen(print);
//    stderr.listen(print);
  }

  bool _stop() {
    if (_startedCompleter != null) {
      if (!_startedCompleter.isCompleted) {
        _startedCompleter.completeError(false);
      }
      _startedCompleter = null;
    }
    if (process != null) {
      return process.kill(io.ProcessSignal.SIGTERM);
    }
    return false;
  }
}

class DockerProcess extends BackgroundProcess {
  DockerProcess();
}

class NCatSocketProcess extends BackgroundProcess {
  NCatSocketProcess();

  Future run(int port, {String socket: 'unix:///var/run/docker.sock'}) {
    assert(port != null && port > 1000);
    assert(socket != null && socket.isNotEmpty);
    return _run('ncat', ['-vlk', port, '-c', 'ncat -U ${socket}']);
  }

  bool stop() => _stop();
}
