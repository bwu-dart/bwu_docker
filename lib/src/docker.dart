library bwu_docker.src.docker;

import 'dart:collection';
import 'dart:io' as io;
import 'dart:convert' show JSON;
import 'dart:async' show Completer, Future, Stream;
import 'package:intl/intl.dart';

class DockerCommand {
  static String executable = 'docker';

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
}

var dateFormat = new DateFormat('yyyy-MM-ddThh:mm:ss.SSSSSSSSSZ');

class ContainerInfo {
  String _appArmorProfile;
  String get appArmorProfile => _appArmorProfile;

  UnmodifiableListView<String> _args;
  UnmodifiableListView<String> get args => _args;

  Config _config;
  Config get config => _config;

  DateTime _created;
  DateTime get created => _created;

  String _driver;
  String get driver => _driver;

  String _execDriver;
  String get execDriver => _execDriver;

  HostConfig _hostConfig;
  HostConfig get hostConfig => _hostConfig;

  String _hostnamePath;
  String get hostnamePath => _hostnamePath;

  String _hostsPath;
  String get hostsPath => _hostsPath;

  String _id;
  String get id => _id;

  String _image;
  String get image => _image;

  String _mountLabel;
  String get mountLabel => _mountLabel;

  String _name;
  String get name => _name;

  NetworkSettings _networkSettings;
  NetworkSettings get networkSettings => _networkSettings;

  String _path;
  String get path => _path;

  String _processLabel;
  String get processLabel => _processLabel;

  String _resolvConfPath;
  String get resolvConfPath => _resolvConfPath;

  State _state;
  State get state => _state;

  Volumes _volues;
  Volumes get volues => _volues;

  VolumesRw _volumesRw;
  VolumesRw get volumesRw => _volumesRw;


  ContainerInfo(Map json) {
    _appArmorProfile = json['AppArmorProfile'];
    _args = new UnmodifiableListView<String>(json['Args']);
    _config = new Config._(json['Config']);
    _created = dateFormat.parse(json['Created'].substring(0, json['Created'].length-6)+'Z', true);
    _driver = json['Driver'];
    _execDriver = json['Exec'];
    _hostConfig = new HostConfig(json['HostConfig']);
    _hostnamePath = json['HostnamePath'];
    _hostsPath = json['HostsPath'];
    _id = json['Id'];
    _image = json['Image'];
    _mountLabel = json['MountLabel'];
    _name = json['Name'];
    _networkSettings = json['NetworkSettings'];
    _path = json['Path'];
    _processLabel = json['Process'];
    _resolvConfPath = json['ResolvConfPath'];
    _state = json['State'];
    _volues = json['Volues'];
    _volumesRw = json['RwVolumes'];
    print(json);
    assert(json.keys.length <= 20); // ensure all keys are read
  }
}

class HostConfig {
  HostConfig(Map json) {
    print('x');
  }
}

class NetworkSettings {
  NetworkSettings(Map json) {
    print('x');
  }
}

class State {
  State(Map json) {
    print('x');
  }
}

class Volumes {
  Volumes(Map json) {
    print('x');
  }
}

class VolumesRw {
  VolumesRw(Map json) {
    print('x');
  }
}



class Config {
  bool _attachStderr;
  bool get attachStderr => _attachStderr;

  bool _attachStdin;
  bool get attachStdIn => _attachStdin;

  bool _attachStdout;
  bool get attachStdout => _attachStdout;

  UnmodifiableListView<String> _cmd;
  UnmodifiableListView<String> get cmd => _cmd;

  int _cpuShares;
  int get cpuShares => _cpuShares;

  String _cpuSet;
  String get cpuSet => _cpuSet;

  String _domainName;
  String get domainName => _domainName;

  String _entryPoint;
  String get entryPoint => _entryPoint;

  UnmodifiableMapView<String, String> _env;
  UnmodifiableMapView<String, String> get env => _env;

  UnmodifiableMapView<String, UnmodifiableMapView<String, String>> _exposedPorts;
  UnmodifiableMapView<String, UnmodifiableMapView<String, String>> get exposedPorts =>
      _exposedPorts;

  String _hostName;
  String get hostName => _hostName;

  String _image;
  String get image => _image;

  String get imageName => _image.split(':')[0];
  String get imageVersion =>_image.split(':')[1];

  int _memory;
  int get memory => _memory;

  int _memorySwap;
  int get memorySwap => _memorySwap;

  bool _networkDisabled;
  bool get networkDisabled => _networkDisabled;

  String _onBuild;
  String get onBuild => _onBuild;

  bool _openStdin;
  bool get openStdin => _openStdin;

  String _portSpecs;
  String get portSpecs => _portSpecs;

  bool _stdinOnce;
  bool get stdinOnce => _stdinOnce;

  bool _tty;
  bool get tty => _tty;

  String _user;
  String get user => _user;

  List<String> _volumes;
  List<String> get volumes => _volumes;

  String _workingDir;
  String get workingDir => _workingDir;


  Config._(Map json) {
    _attachStderr = json['AttachStderr'];
    _attachStdin = json['AttachStdin'];
    _attachStdout = json['AttachStdout'];
    _cmd = new UnmodifiableListView<String>(json['Cmd']);
    _cpuShares = json['CpuShares'];
    _cpuSet = json['Cpuset'];
    _domainName = json['Domainname'];
    _entryPoint = json['Entrypoint'];
    final e = json['Env'];
    if (e != null) {
      _env = new UnmodifiableMapView<String, String>(
          new Map<String, String>.fromIterable(e.map((i) => i.split('=')),
              key: (i) => i[0], value: (i) => i.length == 2 ? i[1] : null));
    }
    _exposedPorts = _toUnmodifiableMapView(json['ExposedPorts']);
    _hostName = json['Hostname'];
    _image = json['Image'];
    _memory = json['Memory'];
    _memorySwap = json['MemorySwap'];
    _networkDisabled = json['NetworkDisabled'];
    _onBuild = json['OnBuild'];
    _openStdin = json['OpenStdin'];
    _portSpecs = json['PortSpecs'];
    _stdinOnce = json['StdinOnce'];
    _tty = json['Tty'];
    _user = json['User'];
    _volumes = new UnmodifiableListView<String>(json['_volumes']);
    _workingDir = json['WorkingDir'];
    assert(json.keys.length <= 23); // ensure all keys were read
  }

  UnmodifiableMapView _toUnmodifiableMapView(Map map) {
    return new UnmodifiableMapView(new Map.fromIterable(map.keys, key: (k) => k, value: (k) {
      if(map == null) {
        return null;
      }
      if(map[k] is Map) {
        return _toUnmodifiableMapView(map[k]);
      } else if (map[k] is List) {
        return _toUnmodifiableListView(map[k]);
      } else {
        return map[k];
      }
    }));
  }

  UnmodifiableListView _toUnmodifiableListView(List list) {
    if(list == null) {
      return null;
    }

    return new UnmodifiableListView(list.map((e) {
      if(e is Map) {
              return _toUnmodifiableMapView(e);
      } else if(e is List) {
        return _toUnmodifiableListView(e);
      } else {
        return e;
      }
    }));
  }
}


class Docker {
  final String executable;
  final Set<Port> ports = new Set<Port>();
  final String imageName;
  final String imageVersion;
  bool runAsDaemon;
  String _id;
  String get id => _id;

//  DockerProcess _process;
//  DockerProcess get process => _process;

  Docker(this.imageName, {this.imageVersion: 'latest',
      this.executable: 'docker', this.runAsDaemon: true}) {
    assert(imageName != null && imageName.isNotEmpty);
    assert(imageVersion != null && imageVersion.isNotEmpty);
    assert(executable != null && executable.isNotEmpty);
    assert(runAsDaemon != null);
  }

  factory Docker.fromId(String id, {String executable: 'docker'}) {
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
//          .._runSync(executable, args);
//        return _process;
//      }
//    }
//  }

  // docker run -d -p 4444:4444 selenium/standalone-chrome:2.45.0

}

class Port {
  final String hostIp;
  final int host;
  final int container;
  final String name;
  const Port(this.host, this.container, {this.name: null, this.hostIp});
  String toDockerArgument() {
    assert(container != null && container > 0);

    if (hostIp != null && hostIp.isNotEmpty) {
      if (host != null) {
        return '${hostIp}:${host}:${container}';
      } else {
        return '${hostIp}::${container}';
      }
    } else {
      if (host != null) {
        return '${host}:${container}';
      } else {
        return '${container}';
      }
    }
  }
}

class DockerProcess {
  io.Process _process;
  io.Process get process => _process;

  Stream<List<int>> _stdoutStream;
  Stream<List<int>> get stdout => _stdoutStream;

  Stream<List<int>> _stderrStream;
  Stream<List<int>> get stderr => _stderrStream;

  Future<int> _exitCode;
  Future<int> get exitCode => _exitCode;

  DockerProcess();

  Completer<bool> _startedCompleter;

  Future<bool> get onStarted {
    if (_startedCompleter == null) {
      _startedCompleter = new Completer<bool>();
    }
    return _startedCompleter.future;
  }

  Future _run(String executable, List<String> args,
      {String workingDirectory}) async {
    if (process != null) {
      return process;
    }
    print('execute: ${executable} ${args.join(' ')}');
    try {
      _process = await io.Process.start(executable, args,
          workingDirectory: workingDirectory);
      _exitCode = process.exitCode;
    } catch (e) {
      _process = null;
    } finally {
      _startedCompleter.complete(_process != null);
    }

    process.exitCode.then((exitCode) {
      _process = null;
    });

    _stdoutStream = process.stdout.asBroadcastStream();
    _stderrStream = process.stderr.asBroadcastStream();
    stdout.listen(print);
    stderr.listen(print);
  }

  bool _stop() {
    if (process != null) {
      return process.kill(io.ProcessSignal.SIGTERM);
    }
    return false;
  }
}
