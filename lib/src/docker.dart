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
    return new ContainerInfo._(json[0]);
  }

  static ImageInfo inspectImage(String id,
      {String executable: 'docker'}) {
    final json = inspect(id);
    if (json[0]['Container'] == null) {
      throw '"${id}" is not an image id.';
    }
    return new ImageInfo._(json[0]);
  }

}

final dateFormat = new DateFormat('yyyy-MM-ddThh:mm:ss.SSSSSSSSSZ');

DateTime _parseDate(String dateString) {
  if(dateString == '0001-01-01T00:00:00Z') {
    return new DateTime(1,1,1);
  }
  return dateFormat.parse(
          dateString.substring(0, dateString.length - 6) + 'Z', true);
}

class ImageInfo {
  String _architecture;
  String get architecture => _architecture;

  String _author;
  String get author => _author;

  String _comment;
  String get comment => _comment;

  Config _config;
  Config get config => _config;

  String _container;
  String get container => _container;

  Config _containerConfig;
  Config get containerConfig => _containerConfig;

  DateTime _created;
  DateTime get created => _created;

  String _dockerVersion;
  String get dockerVersion => _dockerVersion;

  String _id;
  String get id => _id;

  String _os;
  String get os => _os;

  String _parent;
  String get parent => _parent;


  int _size;
  int get size => _size;

  int _virtualSize;
  int get virtualSize => _virtualSize;


  ImageInfo._(Map json) {
    if(json == null) {
      return;
    }
    _architecture = json['Architecture'];
    _author = json['Author'];
    _comment = json['Comment'];
    _config = new Config._(json['Config']);
    _container = json['Container'];
    _containerConfig = new Config._(json['ContainerConfig']);
    _created = _parseDate(json['Created']);
    _dockerVersion = json['DockerVersion'];
    _id = json['Id'];
    _os = json['Os'];
    _parent = json['Parent'];
    _size = json['Size'];
    _virtualSize = json['VirtualSize'];
    assert(json.keys.length <= 13); // ensure all keys were read
  }
}

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

  Volumes _volumes;
  Volumes get volumes => _volumes;

  VolumesRw _volumesRw;
  VolumesRw get volumesRw => _volumesRw;

  ContainerInfo._(Map json) {
    _appArmorProfile = json['AppArmorProfile'];
    _args = new UnmodifiableListView<String>(json['Args']);
    _config = new Config._(json['Config']);
    _created = _parseDate(json['Created']);
    _driver = json['Driver'];
    _execDriver = json['ExecDriver'];
    _hostConfig = new HostConfig._(json['HostConfig']);
    _hostnamePath = json['HostnamePath'];
    _hostsPath = json['HostsPath'];
    _id = json['Id'];
    _image = json['Image'];
    _mountLabel = json['MountLabel'];
    _name = json['Name'];
    _networkSettings = new NetworkSettings._(json['NetworkSettings']);
    _path = json['Path'];
    _processLabel = json['ProcessLabel'];
    _resolvConfPath = json['ResolvConfPath'];
    _state = new State._(json['State']);
    _volumes = new Volumes._(json['Volumes']);
    _volumesRw = new VolumesRw._(json['VolumesRW']);
    assert(json.keys.length <= 20); // ensure all keys are read
  }
}

class HostConfig {
  String _binds;
  String get binds => _binds;

  String _capAdd;
  String get capAdd => _capAdd;

  String _capDrop;
  String get capDrop => _capDrop;

  String _containerIdFile;
  String get containerIdFile => _containerIdFile;

  UnmodifiableListView<String> _devices;
  UnmodifiableListView<String> get devices => _devices;

  String _dns;
  String get dns => _dns;

  String _dnsSearch;
  String get dnsSearch => _dnsSearch;

  UnmodifiableListView<String> _extraHosts;
  UnmodifiableListView<String> get extraHosts => _extraHosts;

  UnmodifiableListView<String> _links;
  UnmodifiableListView<String> get links => _links;

  UnmodifiableListView<String> _lxcConf;
  UnmodifiableListView<String> get lxcConf => _lxcConf;

  String _networkMode;
  String get networkMode => _networkMode;

  UnmodifiableMapView _portBindings;
  UnmodifiableMapView get portBindings => _portBindings;

  bool _privileged;
  bool get privileged => _privileged;

  bool _publishAllPorts;
  bool get publishAllPorts => _publishAllPorts;

  UnmodifiableMapView _restartPolicy;
  UnmodifiableMapView get restartPolicy => _restartPolicy;

  String _securityOpt;
  String get securityOpt => _securityOpt;

  UnmodifiableMapView _volumesFrom;
  UnmodifiableMapView get volumesFrom => _volumesFrom;

  HostConfig._(Map json) {
    _binds = json['Binds'];
    _capAdd = json['CapAdd'];
    _capDrop = json['CapDrop'];
    _containerIdFile = json['ContainerIDFile'];
    _devices = new UnmodifiableListView(json['Devices']);
    _dns = json['Dns'];
    _dnsSearch = json['DnsSearch'];
    _extraHosts = new UnmodifiableListView(json['ExtraHosts']);
    _links = new UnmodifiableListView(json['Links']);
    _lxcConf = new UnmodifiableListView(json['LxcConf']);
    _networkMode = json['NetworkMode'];
    _portBindings = _toUnmodifiableMapView(json['PortBindings']);
    _privileged = json['Privileged'];
    _publishAllPorts = json['PublishAllPorts'];
    _restartPolicy = _toUnmodifiableMapView(json['RestartPolicy']);
    _securityOpt = json['SecurityOpt'];
    _volumesFrom = json['VolumesFrom'];
    assert(json.keys.length <= 17); // ensure all keys were read
  }
}

class NetworkSettings {
  String _bridge;
  String get bridge => _bridge;

  String _gateway;
  String get gateway => _gateway;

  String _ipAddress;
  String get ipAddress => _ipAddress;

  int _ipPrefixLen;
  int get ipPrefixLen => _ipPrefixLen;

  String _macAddress;
  String get macAddress => _macAddress;

  UnmodifiableMapView _portMapping;
  UnmodifiableMapView get portMapping => _portMapping;

  UnmodifiableMapView _ports;
  UnmodifiableMapView get ports => _ports;

  NetworkSettings._(Map json) {
    _bridge = json['Bridge'];
    _gateway = json['Gateway'];
    _ipAddress = json['IPAddress'];
    _ipPrefixLen = json['IPPrefixLen'];
    _macAddress = json['MacAddress'];
    _portMapping = _toUnmodifiableMapView(json['PortMapping']);
    _ports = _toUnmodifiableMapView(json['Ports']);
    assert(json.keys.length <= 7); // ensure all keys were read
  }
}
class State {
  int _exitCode;
  int get exitCode => _exitCode;

  DateTime _finishedAt;
  DateTime get finishedAt => _finishedAt;

  bool _paused;
  bool get paused => _paused;

  int _pid;
  int get pid => _pid;

  bool _restarting;
  bool get restarting => _restarting;

  bool _running;
  bool get running => _running;

  DateTime _startedAt;
  DateTime get startedAt => _startedAt;


  State._(Map json) {
    _exitCode = json['ExitCode'];
    _finishedAt = _parseDate(json['FinishedAt']);
    _paused = json['Paused'];
    _pid = json['Pid'];
    _restarting = json['Restarting'];
    _running = json['Running'];
    _startedAt = _parseDate(json['StartedAt']);
    assert(json.keys.length <= 7); // ensure all keys were read
  }
}

class Volumes {
  Volumes._(Map json) {
    if(json == null) {
      return;
    }
    assert(json.keys.length <= 0); // ensure all keys were read
  }
}

class VolumesRw {
  VolumesRw._(Map json) {
    if(json == null) {
      return;
    }
    assert(json.keys.length <= 0); // ensure all keys were read
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
  String get imageVersion => _image.split(':')[1];

  int _memory;
  int get memory => _memory;

  int _memorySwap;
  int get memorySwap => _memorySwap;

  bool _networkDisabled;
  bool get networkDisabled => _networkDisabled;

  UnmodifiableListView<String> _onBuild;
  UnmodifiableListView<String> get onBuild => _onBuild;

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
    _onBuild = new UnmodifiableListView(json['OnBuild']);
    _openStdin = json['OpenStdin'];
    _portSpecs = json['PortSpecs'];
    _stdinOnce = json['StdinOnce'];
    _tty = json['Tty'];
    _user = json['User'];
    _volumes = new UnmodifiableListView<String>(json['_volumes']);
    _workingDir = json['WorkingDir'];
    assert(json.keys.length <= 23); // ensure all keys were read
  }
}

UnmodifiableMapView _toUnmodifiableMapView(Map map) {
  if(map == null) {
    return null;
  }
  return new UnmodifiableMapView(new Map.fromIterable(map.keys,
      key: (k) => k, value: (k) {
    if (map == null) {
      return null;
    }
    if (map[k] is Map) {
      return _toUnmodifiableMapView(map[k]);
    } else if (map[k] is List) {
      return _toUnmodifiableListView(map[k]);
    } else {
      return map[k];
    }
  }));
}

UnmodifiableListView _toUnmodifiableListView(List list) {
  if (list == null) {
    return null;
  }

  return new UnmodifiableListView(list.map((e) {
    if (e is Map) {
      return _toUnmodifiableMapView(e);
    } else if (e is List) {
      return _toUnmodifiableListView(e);
    } else {
      return e;
    }
  }));
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
//    stdout.listen(print);
//    stderr.listen(print);
  }

  bool _stop() {
    if (process != null) {
      return process.kill(io.ProcessSignal.SIGTERM);
    }
    return false;
  }
}
