library bwu_docker.src.data_structures;

import 'dart:collection';
//import 'package:quiver/core.dart';

final containerNameRegex = new RegExp(r'^/?[a-zA-Z0-9_-]+$');

/// Enum of API versions currently considered for API differences.
class ApiVersion {
  static final v1_15 = new Version(1, 15, null);
  static final v1_17 = new Version(1, 17, null);
  static final v1_18 = new Version(1, 18, null);
  static final v1_19 = new Version(1, 19, null);

  final ApiVersion value;

  ApiVersion(this.value);
}

/// Ensure all provided JSON keys are actually supported.
void _checkSurplusItems(Version apiVersion, Map<Version, List<String>> expected,
    Iterable<String> actual) {
  assert(expected != null);
  assert(actual != null);
  if (apiVersion == null || expected.isEmpty) {
    return;
  }
  List<String> expectedForVersion = expected[apiVersion];
  if (expectedForVersion == null) {
    if (expected.length == 1) {
      expectedForVersion = expected.values.first;
    } else {
      var ascSortedKeys = expected.keys.toList()..sort();
      expectedForVersion =
          expected[ascSortedKeys..lastWhere((k) => k < apiVersion)];
      if (expectedForVersion == null) {
        expectedForVersion = expected[ascSortedKeys.first];
      }
    }
  }
  assert(actual.every((k) {
    if (!expectedForVersion.contains(k)) {
      print('Unsupported key: "${k}"');
      return false;
    }
    return true;
  }));
}

DateTime _parseDate(dynamic dateValue) {
  if (dateValue == null) {
    return null;
  }
  if (dateValue is String) {
    if (dateValue == '0001-01-01T00:00:00Z') {
      return new DateTime(1, 1, 1);
    }

    try {
      final years = int.parse((dateValue as String).substring(0, 4));
      final months = int.parse(dateValue.substring(5, 7));
      final days = int.parse(dateValue.substring(8, 10));
      final hours = int.parse(dateValue.substring(11, 13));
      final minutes = int.parse(dateValue.substring(14, 16));
      final seconds = int.parse(dateValue.substring(17, 19));
      final milliseconds = int.parse(dateValue.substring(20, 23));
      return new DateTime.utc(
          years, months, days, hours, minutes, seconds, milliseconds);
    } catch (_) {
      print('parsing "${dateValue}" failed.');
      rethrow;
    }
  } else if (dateValue is int) {
    return new DateTime.fromMillisecondsSinceEpoch(dateValue * 1000,
        isUtc: true);
  }
  throw 'Unsupported type "${dateValue.runtimeType}" passed.';
}

bool _parseBool(dynamic boolValue) {
  if (boolValue == null) {
    return null;
  }
  if (boolValue is bool) {
    return boolValue;
  }
  if (boolValue is int) {
    return boolValue == 1;
  }
  if (boolValue is String) {
    if (boolValue.toLowerCase() == 'true') {
      return true;
    } else if (boolValue.toLowerCase() == 'false') {
      return false;
    }
  }

  throw new FormatException(
      'Value "${boolValue}" can not be converted to bool.');
}

Map<String, String> _parseLabels(Map<String, List<String>> json) {
  if (json == null) {
    return null;
  }
  final l =
      json['Labels'] != null ? json['Labels'].map((l) => l.split('=')) : null;
  return l == null
      ? null
      : _toUnmodifiableMapView(new Map.fromIterable(l,
          key: (l) => l[0], value: (l) => l.length == 2 ? l[1] : null));
}

UnmodifiableMapView _toUnmodifiableMapView(Map map) {
  if (map == null) {
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

UnmodifiableListView _toUnmodifiableListView(Iterable list) {
  if (list == null) {
    return null;
  }
  if (list.length == 0) {
    return new UnmodifiableListView(const []);
  }

  return new UnmodifiableListView(list.map((e) {
    if (e is Map) {
      return _toUnmodifiableMapView(e);
    } else if (e is List) {
      return _toUnmodifiableListView(e);
    } else {
      return e;
    }
  }).toList());
}

/// Error thrown
class DockerRemoteApiError {
  final int statusCode;
  final String reason;
  final String body;

  DockerRemoteApiError(this.statusCode, this.reason, this.body);

  @override
  String toString() =>
      '${super.toString()} - StatusCode: ${statusCode}, Reason: ${reason}, Body: ${body}';
}

/// The response to the inspectExec command
class ExecInfo {
  String _id;
  String get id => _id;

  bool _running;
  bool get running => _running;

  int _exitCode;
  int get exitCode => _exitCode;

  ProcessConfig _processConfig;
  ProcessConfig get processConfig => _processConfig;

  bool _openStdin;
  bool get openStdin => _openStdin;

  bool _openStderr;
  bool get openStderr => _openStderr;

  bool _openStdout;
  bool get openStdout => _openStdout;

  ContainerInfo _container;
  ContainerInfo get container => _container;

  ExecInfo.fromJson(Map json, Version apiVersion) {
    _id = json['ID'];
    _running = json['Running'];
    _exitCode = json['ExitCode'];
    _processConfig =
        new ProcessConfig.fromJson(json['ProcessConfig'], apiVersion);
    _openStdin = json['OpenStdin'];
    _openStderr = json['OpenStderr'];
    _openStdout = json['OpenStdout'];
    _container = new ContainerInfo.fromJson(json['Container'], apiVersion);

    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'ID',
        'Running',
        'ProcessConfig',
        'ExitCode',
        'OpenStdin',
        'OpenStderr',
        'OpenStdout',
        'Container',
      ]
    }, json.keys);
  }
}

class ProcessConfig {
  bool _privileged;
  bool get privileged => _privileged;

  String _user;
  String get user => _user;

  bool _tty;
  bool get tty => _tty;

  String _entrypoint;
  String get entrypoint => _entrypoint;

  UnmodifiableListView<String> _arguments;
  UnmodifiableListView<String> get arguments => _arguments;

  ProcessConfig.fromJson(Map json, Version apiVersion) {
    _privileged = json['privileged'];
    _user = json['user'];
    _tty = json['tty'];
    _entrypoint = json['entrypoint'];
    _arguments = _toUnmodifiableListView(json['arguments']);
    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'privileged',
        'user',
        'tty',
        'entrypoint',
        'arguments'
      ]
    }, json.keys);
  }
}

/// The response to the exec command
class Exec {
  String _id;
  String get id => _id;

  Exec.fromJson(Map json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _id = json['Id'];
    _checkSurplusItems(apiVersion, {ApiVersion.v1_15: const ['Id']}, json.keys);
  }
}

/// Base class for all kinds of Docker events
abstract class DockerEventBase {
  const DockerEventBase();
}

/// Container related Docker events
/// [More details about container events](https://docs.docker.com/reference/api/images/event_state.png)
class ContainerEvent extends DockerEventBase {
  static const create = const ContainerEvent._(1, 'create');
  static const destroy = const ContainerEvent._(2, 'destroy');
  static const die = const ContainerEvent._(3, 'die');
  static const execCreate = const ContainerEvent._(4, 'exec_create');
  static const execStart = const ContainerEvent._(5, 'exec_start');
  static const export = const ContainerEvent._(6, 'export');
  static const kill = const ContainerEvent._(7, 'kill');
  static const outOfMemory = const ContainerEvent._(7, 'oom');
  static const pause = const ContainerEvent._(8, 'pause');
  static const restart = const ContainerEvent._(9, 'restart');
  static const start = const ContainerEvent._(10, 'start');
  static const stop = const ContainerEvent._(11, 'stop');
  static const unpause = const ContainerEvent._(11, 'unpause');

  static const values = const [
    create,
    destroy,
    die,
    execCreate,
    execStart,
    export,
    kill,
    outOfMemory,
    pause,
    restart,
    start,
    stop,
    unpause
  ];

  final int value;
  final String _asString;

  const ContainerEvent._(this.value, this._asString) : super();

  @override
  String toString() => _asString;
}

/// Image related Docker events
class ImageEvent extends DockerEventBase {
  static const untag = const ImageEvent._(101, 'untag');
  static const delete = const ImageEvent._(102, 'delete');

  static const values = const [untag, delete];

  final int value;
  final String _asString;

  const ImageEvent._(this.value, this._asString) : super();

  @override
  String toString() => _asString;
}

/// All Docker events in one enum
class DockerEvent {
  static const containerCreate = ContainerEvent.create;
  static const containerDestroy = ContainerEvent.destroy;
  static const containerDie = ContainerEvent.die;
  static const containerExecCreate = ContainerEvent.execCreate;
  static const containerExecStart = ContainerEvent.execStart;
  static const containerExport = ContainerEvent.export;
  static const containerKill = ContainerEvent.kill;
  static const containerOutOfMemory = ContainerEvent.outOfMemory;
  static const containerPause = ContainerEvent.pause;
  static const containerRestart = ContainerEvent.restart;
  static const containerStart = ContainerEvent.start;
  static const containerStop = ContainerEvent.stop;
  static const containerUnpause = ContainerEvent.unpause;

  static const imageUntag = ImageEvent.untag;
  static const imageDelete = ImageEvent.delete;

  static const values = const [
    containerCreate,
    containerDestroy,
    containerDie,
    containerExecCreate,
    containerExecStart,
    containerExport,
    containerKill,
    containerOutOfMemory,
    containerPause,
    containerRestart,
    containerStart,
    containerStop,
    containerUnpause,
    imageUntag,
    imageDelete,
  ];

  final DockerEvent value;
  const DockerEvent(this.value);
  @override toString() => value.toString();
}

/// An item of the response to the events request.
class EventsResponse {
  DockerEventBase _status;
  DockerEventBase get status => _status;

  String _id;
  String get id => _id;

  String _from;
  String get from => _from;

  DateTime _time;
  DateTime get time => _time;

  EventsResponse.fromJson(Map json, Version apiVersion) {
    if (json['status'] != null) {
      try {
        _status = DockerEvent.values
            .firstWhere((e) => e.toString() == json['status']);
      } catch (e) {
        print('${e}');
      }
    }
    _id = json['id'];
    _from = json['from'];
    _time = _parseDate(json['time']);
    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const ['status', 'id', 'from', 'time']
    }, json.keys);
  }
}

/// The filter argument to the events request.
class EventsFilter {
  final List<DockerEventBase> events = [];
  final List<Image> images = [];
  final List<Container> containers = [];

  Map toJson() {
    final json = {};
    if (events.isNotEmpty) {
      json['event'] = events.map((e) => e.toString()).toList();
    }
    if (images.isNotEmpty) {
      json['image'] = images.map((e) => e.name).toList();
    }
    if (containers.isNotEmpty) {
      json['container'] = containers.map((e) => e.id).toList();
    }
    return json;
  }
}

/// Response to a commit request.
class CommitResponse {
  String _id;
  String get id => _id;

  UnmodifiableListView<String> _warnings;
  UnmodifiableListView<String> get warnings => _warnings;

  CommitResponse.fromJson(Map json, Version apiVersion) {
    _id = json['Id'];
    _warnings = _toUnmodifiableListView(json['Warnings']);
    _checkSurplusItems(
        apiVersion, {ApiVersion.v1_15: const ['Id', 'Warnings']}, json.keys);
  }
}

/// Commit request
class CommitRequest {
  final String hostName;
  final String domainName;
  final String user;
  final bool attachStdin;
  final bool attachStdout;
  final bool attachStderr;
  List<PortArgument> _portSpecs;
  List<PortArgument> get portSpecs => _portSpecs;
  final bool tty;
  final bool openStdin;
  final bool stdinOnce;
  UnmodifiableMapView<String, String> _env;
  UnmodifiableMapView<String, String> get env => _env;

  UnmodifiableListView<String> _cmd;
  UnmodifiableListView<String> get cmd => _cmd;

  final Volumes volumes;
  final String workingDir;
  final bool networkingDisabled;

  UnmodifiableMapView<String, Map> _name;
  UnmodifiableMapView<String, Map> get name => _name;

  CommitRequest({this.hostName, this.domainName, this.user, this.attachStdin,
      this.attachStdout, this.attachStderr, List<PortArgument> portSpecs,
      this.tty, this.openStdin, this.stdinOnce, Map<String, String> env,
      List<String> cmd, this.volumes, this.workingDir, this.networkingDisabled,
      Map<String, Map> exposedPorts}) {
    _portSpecs = _toUnmodifiableListView(portSpecs);
    _env = _toUnmodifiableMapView(env);
    _name = _toUnmodifiableMapView(exposedPorts);
  }

  Map toJson() {
    final json = {};
    if (hostName != null) json['Hostname'] = hostName;
    if (domainName != null) json['Domainname'] = domainName;
    if (user != null) json['User'] = user;
    if (attachStdin != null) json['AttachStdin'] = attachStdin;
    if (attachStdout != null) json['AttachStdout'] = attachStdout;
    if (attachStderr != null) json['AttachStderr'] = attachStderr;
    if (portSpecs != null) json['PortSpecs'] = portSpecs;
    if (tty != null) json['Tty'] = tty;
    if (openStdin != null) json['OpenStdin'] = openStdin;
    if (stdinOnce != null) json['StdinOnce'] = stdinOnce;
    if (env != null) json['Env'] = env;
    if (cmd != null) json['Cmd'] = cmd;
    if (volumes != null) json['Volumes'] = volumes.toJson();
    if (workingDir != null) json['WorkingDir'] = workingDir;
    if (networkingDisabled != null) json['NetworkDisabled'] =
        networkingDisabled;
    if (name != null) json['ExposedPorts'] = name;
    return json;
  }
}

class Version implements Comparable {
  final int major;
  final int minor;
  final int patch;

  Version(this.major, this.minor, this.patch) {
    if (major == null || major < 0) {
      throw new ArgumentError('"major" must not be null and must not be < 0.');
    }
    if (minor == null || minor < 0) {
      throw new ArgumentError('"minor" must not be null and must not be < 0.');
    }
    if (patch != null && patch < 0) {
      throw new ArgumentError('If "patch" is provided the value must be >= 0.');
    }
  }

  factory Version.fromString(String version) {
    assert(version != null && version.isNotEmpty);
    final parts = version.split('.');
    int major = 0;
    int minor = 0;
    int patch;

    if (parts.length < 2) {
      throw 'Unsupported version string format "${version}".';
    }

    if (parts.length >= 1) {
      major = int.parse(parts[0]);
    }
    if (parts.length >= 2) {
      minor = int.parse(parts[1]);
    }
    if (parts.length >= 3) {
      patch = int.parse(parts[2]);
    }
    if (parts.length >= 4) {
      throw 'Unsupported version string format "${version}".';
    }
    return new Version(major, minor, patch);
  }

  @override
  bool operator ==(other) {
    if (other is! Version) {
      return false;
    }
    final o = other as Version;
    return o.major == major &&
        o.minor == minor &&
        ((o.patch == null && patch == null) || (o.patch == patch));
  }

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() => '${major}.${minor}${patch != null ? '.${patch}' : ''}';

  bool operator <(Version other) {
    assert(other != null);
    if (major < other.major) {
      return true;
    } else if (major > other.major) {
      return false;
    }
    if (minor < other.minor) {
      return true;
    } else if (minor > other.minor) {
      return false;
    }
    if (patch == null && other.patch == null) {
      return false;
    }
    if (patch == null || other.patch == null) {
      throw 'Only version with an equal number of parts can be compared.';
    }
    if (patch < other.patch) {
      return true;
    }
    return false;
  }

  bool operator >(Version other) {
    return other != this && !(this < other);
  }

  bool operator >=(Version other) {
    return this == other || this > other;
  }

  bool operator <=(Version other) {
    return this == other || this < other;
  }

  @override
  int compareTo(Version other) {
    if (this < other) {
      return -1;
    } else if (this == other) {
      return 0;
    }
    return 1;
  }

  static int compare(Comparable a, Comparable b) => a.compareTo(b);
}

/// Response to the version request.
class VersionResponse {
  Version _version;
  Version get version => _version;

  String _os;
  String get os => _os;

  String _kernelVersion;
  String get kernelVersion => _kernelVersion;

  String _goVersion;
  String get goVersion => _goVersion;

  String _gitCommit;
  String get gitCommit => _gitCommit;

  String _architecture;
  String get architecture => _architecture;

  Version _apiVersion;
  Version get apiVersion => _apiVersion;

  VersionResponse.fromJson(Map json, Version apiVersion) {
    _version = new Version.fromString(json['Version']);
    _os = json['Os'];
    _kernelVersion = json['KernelVersion'];
    _goVersion = json['GoVersion'];
    _gitCommit = json['GitCommit'];
    _architecture = json['Arch'];
    _apiVersion = new Version.fromString(json['ApiVersion']);
    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'Version',
        'Os',
        'KernelVersion',
        'GoVersion',
        'GitCommit',
        'Arch',
        'ApiVersion'
      ]
    }, json.keys);
  }
}

/// Response to the info request.
class InfoResponse {
  int _containers;
  int get containers => _containers;

  bool _cpuCfsPeriod;
  bool get cpuCfsPeriod => _cpuCfsPeriod;

  bool _cpuCfsQuota;
  bool get cpuCfsQuota => _cpuCfsQuota;

  bool _debug;
  bool get debug => _debug;

  String _dockerRootDir;
  String get dockerRootDir => _dockerRootDir;

  String _driver;
  String get driver => _driver;

  UnmodifiableListView<List<List>> _driverStatus;
  UnmodifiableListView<List<List>> get driverStatus => _driverStatus;

  String _executionDriver;
  String get executionDriver => _executionDriver;

  bool _experimentalBuild;
  bool get experimentalBuild => _experimentalBuild;

  int _fdCount;
  int get fdCount => _fdCount;

  int _goroutinesCount;
  int get goroutinesCount => _goroutinesCount;

  String _httpProxy;
  String get httpProxy => _httpProxy;

  String _httpsProxy;
  String get httpsProxy => _httpsProxy;

  String _id;
  String get id => _id;

  int _images;
  int get images => _images;

  UnmodifiableListView<String> _indexServerAddress;
  UnmodifiableListView<String> get indexServerAddress => _indexServerAddress;

  String _initPath;
  String get initPath => _initPath;

  String _initSha1;
  String get initSha1 => _initSha1;

  bool _ipv4Forwarding;
  bool get ipv4Forwarding => _ipv4Forwarding;

  String _kernelVersion;
  String get kernelVersion => _kernelVersion;

  UnmodifiableMapView<String, String> _labels;
  UnmodifiableMapView<String, String> get labels => _labels;

  String _loggingDriver;
  String get loggingDriver => _loggingDriver;

  bool _memoryLimit;
  bool get memoryLimit => _memoryLimit;

  int _memTotal;
  int get memTotal => _memTotal;

  String _name;
  String get name => _name;

  int _cpuCount;
  int get cpuCount => _cpuCount;

  int _eventsListenersCount;
  int get eventsListenersCount => _eventsListenersCount;

  String _noProxy;
  String get noProxy => _noProxy;

  bool _oomKillDisable;
  bool get oomKillDisable => _oomKillDisable;

  String _operatingSystem;
  String get operatingSystem => _operatingSystem;

  RegistryConfigs _registryConfigs;
  RegistryConfigs get registryConfigs => _registryConfigs;

  bool _swapLimit;
  bool get swapLimit => _swapLimit;

  DateTime _systemTime;
  DateTime get systemTime => _systemTime;

  InfoResponse.fromJson(Map json, Version apiVersion) {
    _containers = json['Containers'];
    _cpuCfsPeriod = json['CpuCfsPeriod'];
    _cpuCfsQuota = json['CpuCfsQuota'];
    _debug = _parseBool(json['Debug']);
    _dockerRootDir = json['DockerRootDir'];
    _driver = json['Driver'];
    _driverStatus = _toUnmodifiableListView(json['DriverStatus']);
    _executionDriver = json['ExecutionDriver'];
    _experimentalBuild = json['ExperimentalBuild'];
    _httpProxy = json['HttpProxy'];
    _httpsProxy = json['HttpsProxy'];
    _id = json['ID'];
    _images = json['Images'];
    _indexServerAddress = json['IndexServerAddress'] is String
        ? _toUnmodifiableListView([json['IndexServerAddress']])
        : _toUnmodifiableListView(json['IndexServerAddress']);
    _initPath = json['InitPath'];
    _initSha1 = json['InitSha1'];
    _ipv4Forwarding = _parseBool(json['IPv4Forwarding']);
    _kernelVersion = json['KernelVersion'];
    _labels = _parseLabels(json['Labels']);
    _loggingDriver = json['LoggingDriver'];
    _memoryLimit = _parseBool(json['MemoryLimit']);
    _memTotal = json['MemTotal'];
    _name = json['Name'];
    _cpuCount = json['NCPU'];
    _eventsListenersCount = json['NEventsListener'];
    _fdCount = json['NFd'];
    _goroutinesCount = json['NGoroutines'];
    _noProxy = json['NoProxy'];
    _oomKillDisable = json['OomKillDisable'];
    _operatingSystem = json['OperatingSystem'];
    _registryConfigs =
        new RegistryConfigs.fromJson(json['RegistryConfigs'], apiVersion);
    _swapLimit = _parseBool(json['SwapLimit']);
    _systemTime = _parseDate(json['SystemTime']);

    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'Containers',
        'Debug',
        'DockerRootDir',
        'Driver',
        'DriverStatus',
        'ExecutionDriver',
        'HttpProxy',
        'HttpsProxy',
        'ID',
        'Images',
        'IndexServerAddress',
        'InitPath',
        'InitSha1',
        'IPv4Forwarding',
        'KernelVersion',
        'Labels',
        'MemoryLimit',
        'MemTotal',
        'Name',
        'NCPU',
        'NEventsListener',
        'NFd',
        'NGoroutines',
        'OperatingSystem',
        'SwapLimit',
        'SystemTime'
      ],
      ApiVersion.v1_18: const [
        'Containers',
        'Debug',
        'DockerRootDir',
        'Driver',
        'DriverStatus',
        'ExecutionDriver',
        'HttpProxy',
        'HttpsProxy',
        'ID',
        'Images',
        'IndexServerAddress',
        'InitPath',
        'InitSha1',
        'IPv4Forwarding',
        'KernelVersion',
        'Labels',
        'MemoryLimit',
        'MemTotal',
        'Name',
        'NCPU',
        'NEventsListener',
        'NFd',
        'NGoroutines',
        'OperatingSystem',
        'RegistryConfig',
        'SwapLimit',
        'SystemTime'
      ],
      ApiVersion.v1_19: const [
        'Containers',
        'CpuCfsPeriod',
        'CpuCfsQuota',
        'Debug',
        'DockerRootDir',
        'Driver',
        'DriverStatus',
        'ExecutionDriver',
        'ExperimentalBuild',
        'HttpProxy',
        'HttpsProxy',
        'ID',
        'Images',
        'IndexServerAddress',
        'InitPath',
        'InitSha1',
        'IPv4Forwarding',
        'KernelVersion',
        'Labels',
        'LoggingDriver',
        'MemoryLimit',
        'MemTotal',
        'Name',
        'NCPU',
        'NEventsListener',
        'NFd',
        'NGoroutines',
        'NoProxy',
        'OomKillDisable',
        'OperatingSystem',
        'RegistryConfig',
        'SwapLimit',
        'SystemTime'
      ],
    }, json.keys);
  }
}

class RegistryConfigs {
  UnmodifiableMapView _indexConfigs;
  UnmodifiableMapView get indexConfigs => _indexConfigs;

  UnmodifiableListView<String> _insecureRegistryCidrs;
  UnmodifiableListView<String> get insecureRegistryCidrs =>
      _insecureRegistryCidrs;

  RegistryConfigs.fromJson(Map json, Version apiVersion) {
    if (json == null) {
      return;
    }

    _indexConfigs = _toUnmodifiableMapView(json['IndexConfigs']);
    _insecureRegistryCidrs =
        _toUnmodifiableListView(json['InsecureRegistryCIDRs']);

    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_18: const ['IndexConfigs', 'InsecureRegistryCIDRs']
    }, json.keys);
  }
}

/// Argument for the auth request.
class AuthRequest {
  String _userName;
  String get userName => _userName;

  String _password;
  String get password => _password;

  String _email;
  String get email => _email;

  String _serverAddress;
  String get serverAddress => _serverAddress;

  AuthRequest(
      this._userName, this._password, this._email, this._serverAddress) {
    assert(userName.isNotEmpty);
    assert(password.isNotEmpty);
    assert(email.isNotEmpty);
    assert(serverAddress.isNotEmpty);
  }

  Map toJson() {
    return {
      'username': userName,
      'password': password,
      'email': email,
      'serveraddress': serverAddress
    };
  }
}

/// An item of the response to search.
class SearchResponse {
  String _description;
  String get description => _description;

  bool _isOfficial;
  bool get isOfficial => _isOfficial;

  bool _isAutomated;
  bool get isAutomated => _isAutomated;

  String _name;
  String get name => _name;

  int _starCount;
  int get starCount => _starCount;

  SearchResponse.fromJson(Map json, Version apiVersion) {
    _description = json['description'];
    _isOfficial = json['is_official'];
    if (json['is_trusted'] != null) {
      _isAutomated = json['is_trusted'];
    } else {
      _isAutomated = json['is_automated'];
    }
    _name = json['name'];
    _starCount = json['star_count'];
    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'description',
        'is_official',
        'is_trusted',
        'is_automated',
        'name',
        'star_count'
      ]
    }, json.keys);
  }
}

/// An item of the response to removeImage.
class ImageRemoveResponse {
  String _untagged;
  String get untagged => _untagged;

  String _deleted;
  String get deleted => _deleted;

  ImageRemoveResponse.fromJson(Map json, Version apiVersion) {
    _untagged = json['Untagged'];
    _deleted = json['Deleted'];
    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const ['Untagged', 'Deleted']
    }, json.keys);
  }
}

/// An item of the response to images/(name)/push.
class ImagePushResponse {
  String _status;
  String get status => _status;

  String _progress;
  String get progress => _progress;

  UnmodifiableMapView _progressDetail;
  UnmodifiableMapView get progressDetail => _progressDetail;

  String _error;
  String get error => _error;

  ImagePushResponse.fromJson(Map json, Version apiVersion) {
    final json = {};
    _status = json['status'];
    _progress = json['progress'];
    _progressDetail = _toUnmodifiableMapView(json['progressDetail']);
    _error = json['error'];
    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const ['status', 'progress', 'progressDetail', 'error']
    }, json.keys);
  }
}

/// The response to an images/(name)/history request.
class ImageHistoryResponse {
  String _id;
  String get id => _id;

  String _comment;
  String get comment => _comment;

  DateTime _created;
  DateTime get created => _created;

  String _createdBy;
  String get createdBy => _createdBy;

  int _size;
  int get size => _size;

  UnmodifiableListView<String> _tags;
  UnmodifiableListView<String> get tags => _tags;

  ImageHistoryResponse.fromJson(Map json, Version apiVersion) {
    _id = json['Id'];
    _comment = json['Comment'];
    _created = _parseDate(json['Created']);
    _createdBy = json['CreatedBy'];
    _size = json['Size'];
    _tags = _toUnmodifiableListView(json['Tags']);
    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const ['Id', 'Created', 'CreatedBy', 'Size', 'Tags'],
      ApiVersion.v1_19: const [
        'Id',
        'Comment',
        'Created',
        'CreatedBy',
        'Size',
        'Tags'
      ],
    }, json.keys);
  }
}

/// A reference to an image.
class Image {
  final String name;

  Image(this.name) {
    assert(name != null && name.isNotEmpty);
  }
}

/// An item of an image create response
class CreateImageResponse {
  String _status;
  String get status => _status;

  UnmodifiableMapView<String, Map> _progressDetail;
  UnmodifiableMapView<String, Map> get progressDetail => _progressDetail;

  String _id;
  String get id => _id;

  String _progress;
  String get progress => _progress;

  CreateImageResponse.fromJson(Map json, Version apiVersion) {
    _status = json['status'];
    _progressDetail = _toUnmodifiableMapView(json['progressDetail']);
    _id = json['id'];
    _progress = json['progress'];
    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const ['status', 'progressDetail', 'id', 'progress'],
    }, json.keys);
  }
}

class ConfigFile {
  AuthConfig _auths;
  AuthConfig get auths => _auths;

  UnmodifiableMapView<String, String> _httpHeaders;
  UnmodifiableMapView<String, String> get httpHeaders => _httpHeaders;

  String _fileName;
  String get fileName => _fileName;

  ConfigFile(this._auths, {Map<String, String> httpHeaders}) {
    assert(auths != null);
    _httpHeaders = _toUnmodifiableMapView(httpHeaders);
  }

  Map toJson() {
    final json = {};
    if (auths != null) json['auths'] = auths.toJson();
    if (httpHeaders != null) json['HttpHeaders'] = _httpHeaders;
    return json;
  }
}

/// Passed as `X-Registry-Auth` header in requests that need authentication to a
/// registry.
/// Since API version 1.2, the auth configuration is now handled client side,
/// so the client has to send the authConfig as a POST in `/images/(name)/push`.
/// authConfig, set as the `X-Registry-Auth header`, is currently a Base64
/// encoded (JSON) string with the following structure:
/// `{"username": "string", "password": "string", "email": "string", "serveraddress" : "string", "auth": ""}`.
/// Notice that `auth` is to be left empty, `serveraddress` is a domain/ip
/// without protocol, and that double quotes (instead of single ones) are
/// required.
class AuthConfig {
  final String userName;
  final String password;
  final String auth;
  final String email;
  final String serverAddress;
  const AuthConfig({this.userName, this.password, this.auth, this.email,
      this.serverAddress});

  Map toJson() {
    final json = {};
    if (userName != null) json['userName'] = userName;
    if (password != null) json['password;'] = password;
    json['auth;'] = auth;
    json['email;'] = email;
    if (serverAddress != null) json['serverAddress'] = serverAddress;
    return json;
  }
}

/// To create proper JSON for a requested path for a copy request.
class CopyRequestPath {
  String _path;
  String get path => _path;

  CopyRequestPath(this._path) {
    assert(path != null && path.isNotEmpty);
  }

  Map toJson() {
    return {'Resource': path};
  }
}

/// The response to a wait request.
class WaitResponse {
  int _statusCode;
  int get statusCode => _statusCode;

  WaitResponse.fromJson(Map json, Version apiVersion) {
    _statusCode = json['StatusCode'];
  }
}

class StatsResponseNetwork {
  int _rxDropped;
  int get rxDropped => _rxDropped;

  int _rxBytes;
  int get rxBytes => _rxBytes;

  int _rxErrors;
  int get rxErrors => _rxErrors;

  int _txPackets;
  int get txPackets => _txPackets;

  int _txDropped;
  int get txDropped => _txDropped;

  int _rxPackets;
  int get rxPackets => _rxPackets;

  int _txErrors;
  int get txErrors => _txErrors;

  int _txBytes;
  int get txBytes => _txBytes;

  StatsResponseNetwork.fromJson(Map json, Version apiVersion) {
    _rxDropped = json['rx_dropped'];
    _rxBytes = json['rx_bytes'];
    _rxErrors = json['rx_errors'];
    _txPackets = json['tx_packets'];
    _txDropped = json['tx_dropped'];
    _rxPackets = json['rx_packets'];
    _txErrors = json['tx_errors'];
    _txBytes = json['tx_bytes'];
    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'rx_dropped',
        'rx_bytes',
        'rx_errors',
        'tx_packets',
        'tx_dropped',
        'rx_packets',
        'tx_errors',
        'tx_bytes'
      ]
    }, json.keys);
  }
}

class StatsResponseMemoryStats {
  StatsResponseMemoryStatsStats _stats;
  StatsResponseMemoryStatsStats get stats => _stats;

  int _maxUsage;
  int get maxUsage => _maxUsage;

  int _usage;
  int get usage => _usage;

  int _failCount;
  int get failCount => _failCount;

  int _limit;
  int get limit => _limit;

  StatsResponseMemoryStats.fromJson(Map json, Version apiVersion) {
    _stats =
        new StatsResponseMemoryStatsStats.fromJson(json['stats'], apiVersion);
    _maxUsage = json['max_usage'];
    _usage = json['usage'];
    _failCount = json['failcnt'];
    _limit = json['limit'];
    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'stats',
        'max_usage',
        'usage',
        'failcnt',
        'limit'
      ]
    }, json.keys);
  }
}

class StatsResponseMemoryStatsStats {
  int _totalPgmajFault;
  int get totalPgmajFault => _totalPgmajFault;

  int _cache;
  int get cache => _cache;

  int _mappedFile;
  int get mappedFile => _mappedFile;

  int _totalInactiveFile;
  int get totalInactiveFile => _totalInactiveFile;

  int _pgpgOut;
  int get pgpgOut => _pgpgOut;

  int _rss;
  int get rss => _rss;

  int _totalMappedFile;
  int get totalMappedFile => _totalMappedFile;

  int _writeBack;
  int get writeBack => _writeBack;

  int _unevictable;
  int get unevictable => _unevictable;

  int _pgpgIn;
  int get pgpgIn => _pgpgIn;

  int _totalUnevictable;
  int get totalUnevictable => _totalUnevictable;

  int _pgmajFault;
  int get pgmajFault => _pgmajFault;

  int _totalRss;
  int get totalRss => _totalRss;

  int _totalRssHuge;
  int get totalRssHuge => _totalRssHuge;

  int _totalWriteback;
  int get totalWriteback => _totalWriteback;

  int _totalInactiveAnon;
  int get totalInactiveAnon => _totalInactiveAnon;

  int _rssHuge;
  int get rssHuge => _rssHuge;

  int _hierarchicalMemoryLimit;
  int get hierarchicalMemoryLimit => _hierarchicalMemoryLimit;

  int _totalPgFault;
  int get totalPgFault => _totalPgFault;

  int _totalActiveFile;
  int get totalActiveFile => _totalActiveFile;

  int _activeAnon;
  int get activeAnon => _activeAnon;

  int _totalActiveAnon;
  int get totalActiveAnon => _totalActiveAnon;

  int _totalPgpgOut;
  int get totalPgpgOut => _totalPgpgOut;

  int _totalCache;
  int get totalCache => _totalCache;

  int _inactiveAnon;
  int get inactiveAnon => _inactiveAnon;

  int _activeFile;
  int get activeFile => _activeFile;

  int _pgFault;
  int get pgFault => _pgFault;

  int _inactiveFile;
  int get inactiveFile => _inactiveFile;

  int _totalPgpgIn;
  int get totalPgpgIn => _totalPgpgIn;

  StatsResponseMemoryStatsStats.fromJson(Map json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _totalPgmajFault = json['total_pgmajfault'];
    _cache = json['cache'];
    _mappedFile = json['mapped_file'];
    _totalInactiveFile = json['total_inactive_file'];
    _pgpgOut = json['pgpgout'];
    _rss = json['rss'];
    _totalMappedFile = json['total_mapped_file'];
    _writeBack = json['writeback'];
    _unevictable = json['unevictable'];
    _pgpgIn = json['pgpgin'];
    _totalUnevictable = json['total_unevictable'];
    _pgmajFault = json['pgmajfault'];
    _totalRss = json['total_rss'];
    _totalRssHuge = json['total_rss_huge'];
    _totalWriteback = json['total_writeback'];
    _totalInactiveAnon = json['total_inactive_anon'];
    _rssHuge = json['rss_huge'];
    _hierarchicalMemoryLimit = json['hierarchical_memory_limit'];
    _totalPgFault = json['total_pgfault'];
    _totalActiveFile = json['total_active_file'];
    _activeAnon = json['active_anon'];
    _totalActiveAnon = json['total_active_anon'];
    _totalPgpgOut = json['total_pgpgout'];
    _totalCache = json['total_cache'];
    _inactiveAnon = json['inactive_anon'];
    _activeFile = json['active_file'];
    _pgFault = json['pgfault'];
    _inactiveFile = json['inactive_file'];
    _totalPgpgIn = json['total_pgpgin'];
    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'total_pgmajfault',
        'cache',
        'mapped_file',
        'total_inactive_file',
        'pgpgout',
        'rss',
        'total_mapped_file',
        'writeback',
        'unevictable',
        'pgpgin',
        'total_unevictable',
        'pgmajfault',
        'total_rss',
        'total_rss_huge',
        'total_writeback',
        'total_inactive_anon',
        'rss_huge',
        'hierarchical_memory_limit',
        'total_pgfault',
        'total_active_file',
        'active_anon',
        'total_active_anon',
        'total_pgpgout',
        'total_cache',
        'inactive_anon',
        'active_file',
        'pgfault',
        'inactive_file',
        'total_pgpgin'
      ]
    }, json.keys);
  }
}

class StatsResponseCpuUsage {
  UnmodifiableListView<int> _perCpuUsage;
  UnmodifiableListView<int> get perCpuUsage => _perCpuUsage;

  int _usageInUserMode;
  int get usageInUserMode => _usageInUserMode;

  int _totalUsage;
  int get totalUsage => _totalUsage;

  int _usageInKernelMode;
  int get usageInKernelMode => _usageInKernelMode;

  StatsResponseCpuUsage.fromJson(Map json, Version apiVersion) {
    _perCpuUsage = _toUnmodifiableListView(json['percpu_usage']);
    _usageInUserMode = json['usage_in_usermode'];
    _totalUsage = json['total_usage'];
    _usageInKernelMode = json['usage_in_kernelmode'];

    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_17: const [
        'percpu_usage',
        'usage_in_usermode',
        'total_usage',
        'usage_in_kernelmode',
      ]
    }, json.keys);
  }
}

class StatsResponseCpuStats {
  StatsResponseCpuUsage _cupUsage;
  StatsResponseCpuUsage get cupUsage => _cupUsage;

  int _systemCpuUsage;
  int get systemCpuUsage => _systemCpuUsage;

  ThrottlingData _throttlingData;
  ThrottlingData get throttlingData => _throttlingData;

  StatsResponseCpuStats.fromJson(Map json, Version apiVersion) {
    _cupUsage =
        new StatsResponseCpuUsage.fromJson(json['cpu_usage'], apiVersion);
    _systemCpuUsage = json['system_cpu_usage'];
    _throttlingData =
        new ThrottlingData.fromJson(json['throttling_data'], apiVersion);
    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'cpu_usage',
        'system_cpu_usage',
        'throttling_data'
      ]
    }, json.keys);
  }
}

class ThrottlingData {
  int _periods;
  int get periods => _periods;

  int _throttledPeriods;
  int get throttledPeriods => _throttledPeriods;

  int _throttledTime;
  int get throttledTime => _throttledTime;

  ThrottlingData.fromJson(Map json, Version apiVersion) {
    _periods = json['periods'];
    _throttledPeriods = json['throttled_periods'];
    _throttledTime = json['throttled_time'];

    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const ['periods', 'throttled_periods', 'throttled_time']
    }, json.keys);
  }
}

/// The response to a logs request.
class StatsResponse {
  BlkIoStats _blkIoStats;
  BlkIoStats get blkIoStats => _blkIoStats;

  StatsResponseCpuStats _cpuStats;
  StatsResponseCpuStats get cpuStats => _cpuStats;

  StatsResponseMemoryStats _memoryStats;
  StatsResponseMemoryStats get memoryStats => _memoryStats;

  StatsResponseNetwork _network;
  StatsResponseNetwork get network => _network;

  StatsResponseCpuStats _preCpuStats;
  StatsResponseCpuStats get preCpuStats => _preCpuStats;

  DateTime _read;
  DateTime get read => _read;

  StatsResponse.fromJson(Map json, Version apiVersion) {
    _blkIoStats = new BlkIoStats.fromJson(json['blkio_stats'], apiVersion);
    _cpuStats =
        new StatsResponseCpuStats.fromJson(json['cpu_stats'], apiVersion);
    _memoryStats =
        new StatsResponseMemoryStats.fromJson(json['memory_stats'], apiVersion);
    _network = new StatsResponseNetwork.fromJson(json['network'], apiVersion);
    _preCpuStats =
        new StatsResponseCpuStats.fromJson(json['precpu_stats'], apiVersion);
    _read = _parseDate(json['read']);
    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'blkio_stats',
        'cpu_stats',
        'memory_stats',
        'network',
        'read',
      ],
      ApiVersion.v1_19: const [
        'blkio_stats',
        'cpu_stats',
        'memory_stats',
        'network',
        'precpu_stats',
        'read',
      ],
    }, json.keys);
  }
}

class BlkIoStats {
  UnmodifiableListView<int> _ioServiceBytesRecursive;
  UnmodifiableListView<int> get ioServiceBytesRecursive =>
      _ioServiceBytesRecursive;

  UnmodifiableListView<int> _ioServicedRecursive;
  UnmodifiableListView<int> get ioServicedRecursive => _ioServicedRecursive;

  UnmodifiableListView<int> _ioQueueRecursive;
  UnmodifiableListView<int> get ioQueueRecursive => _ioQueueRecursive;

  UnmodifiableListView<int> _ioServiceTimeRecursive;
  UnmodifiableListView<int> get ioServiceTimeRecursive =>
      _ioServiceTimeRecursive;

  UnmodifiableListView<int> _ioWaitTimeRecursive;
  UnmodifiableListView<int> get ioWaitTimeRecursive => _ioWaitTimeRecursive;

  UnmodifiableListView<int> _ioMergedRecursive;
  UnmodifiableListView<int> get ioMergedRecursive => _ioMergedRecursive;

  UnmodifiableListView<int> _ioTimeRecursive;
  UnmodifiableListView<int> get ioTimeRecursive => _ioTimeRecursive;

  UnmodifiableListView<int> _sectorsRecursive;
  UnmodifiableListView<int> get sectorsRecursive => _sectorsRecursive;

  BlkIoStats.fromJson(Map json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _ioServiceBytesRecursive =
        _toUnmodifiableListView(json['io_service_bytes_recursive']);
    _ioServicedRecursive =
        _toUnmodifiableListView(json['io_serviced_recursive']);
    _ioQueueRecursive = _toUnmodifiableListView(json['io_queue_recursive']);
    _ioServiceTimeRecursive =
        _toUnmodifiableListView(json['io_service_time_recursive']);
    _ioWaitTimeRecursive =
        _toUnmodifiableListView(json['io_wait_time_recursive']);
    _ioMergedRecursive = _toUnmodifiableListView(json['io_merged_recursive']);
    _ioTimeRecursive = _toUnmodifiableListView(json['io_time_recursive']);
    _sectorsRecursive = _toUnmodifiableListView(json['sectors_recursive']);

    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'io_service_bytes_recursive',
        'io_serviced_recursive',
        'io_queue_recursive',
        'io_service_time_recursive',
        'io_wait_time_recursive',
        'io_merged_recursive',
        'io_time_recursive',
        'sectors_recursive',
      ]
    }, json.keys);
  }
}

/// The available change kinds for the changes request.
enum ChangeKind { modify, add, delete, }

/// The argument for the changes request.
class ChangesResponse {
  final Set<_ChangesPath> _changes = new Set<_ChangesPath>();
  List<_ChangesPath> get changes => new UnmodifiableListView(_changes);

  void _add(String path, ChangeKind kind) {
    _changes.add(new _ChangesPath(path, kind));
  }

  List<Map> toJson() {
    return _changes.map((c) => c.toJson()).toList();
  }

  ChangesResponse.fromJson(List json) {
    json.forEach((Map c) {
      _add(
          c['Path'], ChangeKind.values.firstWhere((v) => v.index == c['Kind']));
    });
  }
}

/// A path/change kind entry for the [ChangeRequest].
class _ChangesPath {
  final String path;
  final ChangeKind kind;

  _ChangesPath(this.path, this.kind) {
    assert(path != null && path.isNotEmpty);
    assert(kind != null);
  }

  @override
  // TODO(zoechi) use quiver once it supports the test package // hash2(path, kind);
  int get hashCode => '${path}-${kind}'.hashCode;

  @override
  bool operator ==(other) {
    return (other is _ChangesPath && other.path == path && other.kind == kind);
  }

  Map toJson() => {'Path': path, 'Kind': kind.index};
}

/// Response to the top request.
class TopResponse {
  List<String> _titles;
  List<String> get titles => _titles;

  List<List<String>> _processes;
  List<List<String>> get processes => _processes;

  TopResponse.fromJson(Map json, Version apiVersion) {
    _titles = _toUnmodifiableListView(json['Titles']);
    _processes = _toUnmodifiableListView(json['Processes']);
  }

  Map toJson() => {'Titles': titles, 'Processes': processes};
}

/// The possible running states of a container.
class ContainerStatus {
  static const restarting = const ContainerStatus('restarting');
  static const running = const ContainerStatus('running');
  static const paused = const ContainerStatus('paused');
  static const exited = const ContainerStatus('exited');

  static const values = const <ContainerStatus>[
    restarting,
    running,
    paused,
    exited
  ];

  final String value;

  const ContainerStatus(this.value);

  @override
  String toString() => '${value}';
}

enum RestartPolicyVariant { doNotRestart, always, onFailure }

///  The behavior to apply when the container exits. The value is an object with
///  a `Name` property of either "always" to always restart or `"on-failure"` to
///  restart only when the container exit code is non-zero. If `on-failure` is
///  used, `MaximumRetryCount` controls the number of times to retry before
///  giving up. The default is not to restart. (optional) An ever increasing
///  delay (double the previous delay, starting at 100mS) is added before each
///  restart to prevent flooding the server.
class RestartPolicy {
  RestartPolicyVariant _variant;
  RestartPolicyVariant get variant => _variant;
  int _maximumRetryCount;
  int get maximumRetryCount => _maximumRetryCount;

  RestartPolicy(this._variant, this._maximumRetryCount);

  RestartPolicy.fromJson(Map json, Version apiVersion) {
    if (json == null) {
      return;
    }
    if (json['Name'] != null && json['Name'].isNotEmpty) {
      final value = RestartPolicyVariant.values
          .where((v) => v.toString().endsWith(json['Name']));
//      print(json);
      if (value.length != 1) {
        throw 'Invalid value "${json['Name']}".';
      }
      _variant = value.first;
      if (value == RestartPolicyVariant.onFailure) {
        _maximumRetryCount = json['MaximumRetryCount'];
      }
    }
  }

  Map toJson() {
    assert(_maximumRetryCount == null ||
        _variant == RestartPolicyVariant.onFailure);
    if (variant == null) {
      return null;
    }
    switch (_variant) {
      case RestartPolicyVariant.doNotRestart:
        return null;
      case RestartPolicyVariant.always:
        return {'always': null};
      case RestartPolicyVariant.onFailure:
        if (_maximumRetryCount != null) {
          return {'on-failure': null, 'MaximumRetryCount': _maximumRetryCount};
        }
        return {'on-failure': null};
      default:
        throw 'Unsupported enum value.';
    }
  }
}

class NetworkMode {
  static const bridge = const NetworkMode('bridge');
  static const host = const NetworkMode('host');

  static const values = const <NetworkMode>[bridge, host];

  final String value;

  const NetworkMode(this.value);

  @override
  String toString() => '${value}';
}

/// Basic info about a container.
class Container {
  String _id;
  String get id => _id;

  String _command;
  String get command => _command;

  DateTime _created;
  DateTime get created => _created;

  UnmodifiableMapView _labels;
  UnmodifiableMapView get labels => _labels;

  String _image;
  String get image => _image;

  List<String> _names;
  List<String> get names => _names;

  List<PortArgument> _ports;
  List<PortArgument> get ports => _ports;

  String _status;
  String get status => _status;

  Container(this._id);

  Container.fromJson(Map json, Version apiVersion) {
    _id = json['Id'];
    _command = json['Command'];
    _created = _parseDate(json['Created']);
    _labels = _parseLabels(json['Labels']);
    _image = json['Image'];
    _names = json['Names'];
    _ports = json['Ports'] == null
        ? null
        : json['Ports']
            .map((p) => new PortResponse.fromJson(p, apiVersion))
            .toList();
    _status = json['Status'];

    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'Id',
        'Command',
        'Created',
        'Image',
        'Names',
        'Ports',
        'Status'
      ],
      ApiVersion.v1_18: [
        'Id',
        'Command',
        'Created',
        'Labels',
        'Image',
        'Names',
        'Ports',
        'Status'
      ],
      ApiVersion.v1_19: [
        'Id',
        'Command',
        'Created',
        'Labels',
        'Image',
        'Names',
        'Ports',
        'Status'
      ],
    }, json.keys);
  }

  Map toJson() {
    final json = {};
    if (id != null) json['Id'] = id;
    if (command != null) json['Command'] = command;
    if (created != null) json['Created'] = created.toIso8601String();
    if (image != null) json['Image'] = image;
    if (names != null) json['Names'] = names;
    if (ports != null) json['Ports'] = ports;
    if (status != null) json['Status'] = status;
    return json;
  }
}

/// Information about an image returned by 'inspect'
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

  UnmodifiableMapView<String, String> _labels;
  UnmodifiableMapView<String, String> get labels => _labels;

  String _os;
  String get os => _os;

  String _parent;
  String get parent => _parent;

  int _size;
  int get size => _size;

  int _virtualSize;
  int get virtualSize => _virtualSize;

  UnmodifiableListView<String> _repoDigests;
  UnmodifiableListView<String> get repoDigests => _repoDigests;

  UnmodifiableListView<String> _repoTags;
  UnmodifiableListView<String> get repoTags => _repoTags;

  ImageInfo.fromJson(Map json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _architecture = json['Architecture'];
    _author = json['Author'];
    _comment = json['Comment'];
    _config = new Config.fromJson(json['Config'], apiVersion);
    _container = json['Container'];
    _containerConfig = new Config.fromJson(json['ContainerConfig'], apiVersion);
    _created = _parseDate(json['Created']);
    _dockerVersion = json['DockerVersion'];
    _id = json['Id'];
    _labels = _parseLabels(json['Labels']);
    _os = json['Os'];
    // depending on the request `Parent` or `ParentId` is set.
    _parent = json['Parent'];
    _parent = json['ParentId'] != null ? json['ParentId'] : null;
    _size = json['Size'];
    _virtualSize = json['VirtualSize'];
    _repoDigests = _toUnmodifiableListView(json['RepoDigests']);
    _repoTags = _toUnmodifiableListView(json['RepoTags']);

    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'Architecture',
        'Author',
        'Comment',
        'Config',
        'Container',
        'ContainerConfig',
        'Created',
        'DockerVersion',
        'Id',
        'Os',
        'Parent',
        'ParentId',
        'Size',
        'VirtualSize',
        'RepoTags'
      ],
      ApiVersion.v1_18: const [
        'Architecture',
        'Author',
        'Comment',
        'Config',
        'Container',
        'ContainerConfig',
        'Created',
        'DockerVersion',
        'Id',
        'Labels',
        'Os',
        'Parent',
        'ParentId',
        'Size',
        'VirtualSize',
        'RepoDigests',
        'RepoTags',
      ],
      ApiVersion.v1_19: const [
        'Architecture',
        'Author',
        'Comment',
        'Config',
        'Container',
        'ContainerConfig',
        'Created',
        'DockerVersion',
        'Id',
        'Labels',
        'Os',
        'Parent',
        'ParentId',
        'Size',
        'VirtualSize',
        'RepoDigests',
        'RepoTags',
      ],
    }, json.keys);
  }
}

class ContainerInfo {
  String _appArmorProfile;
  String get appArmorProfile => _appArmorProfile;

  String _appliedVolumesFrom; // ExecInfo
  String get appliedVolumesFrom => _appliedVolumesFrom;

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

  String _execIds;
  String get execIds => _execIds;

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

  String _logPath;
  String get logPath => _logPath;

  String _mountLabel;
  String get mountLabel => _mountLabel;

  UnmodifiableMapView<String, UnmodifiableListView<String>> _mountPoints; // TODO add generic type with actual data
  UnmodifiableMapView<String, UnmodifiableListView<String>> get mountPoints =>
      _mountPoints;

  String _name;
  String get name => _name;

  NetworkSettings _networkSettings;
  NetworkSettings get networkSettings => _networkSettings;

  String _path;
  String get path => _path;

  String _processLabel;
  String get processLabel => _processLabel;

  String _resolveConfPath;
  String get resolveConfPath => _resolveConfPath;

  int _restartCount;
  int get restartCount => _restartCount;

  State _state;
  State get state => _state;

  Volumes _volumes;
  Volumes get volumes => _volumes;

  VolumesRw _volumesRw;
  VolumesRw get volumesRw => _volumesRw;

  bool _updateDns;
  bool get updateDns => _updateDns;

  ContainerInfo.fromJson(Map json, Version apiVersion) {
    _appArmorProfile = json['AppArmorProfile'];
    _appliedVolumesFrom = json['AppliedVolumesFrom'];
    _args = _toUnmodifiableListView(json['Args']);
    _config = new Config.fromJson(json['Config'], apiVersion);
    _created = _parseDate(json['Created']);
    _driver = json['Driver'];
    _execDriver = json['ExecDriver'];
    _execIds = json['ExecIDs'];
    _hostConfig = new HostConfig.fromJson(json['HostConfig'], apiVersion);
    _hostnamePath = json['HostnamePath'];
    _hostsPath = json['HostsPath'];
    if (json.containsKey('Id')) {
      _id = json['Id'];
    } else if (json.containsKey('ID')) {
      _id = json['ID']; // ExecInfo
    }
    _image = json['Image'];
    _logPath = json['LogPath'];
    _mountLabel = json['MountLabel'];
    _mountPoints = _toUnmodifiableMapView(
        json['MountPoints']); // TODO check with actual data
    _name = json['Name'];
    _networkSettings =
        new NetworkSettings.fromJson(json['NetworkSettings'], apiVersion);
    _path = json['Path'];
    _processLabel = json['ProcessLabel'];
    _resolveConfPath = json['ResolvConfPath'];
    _restartCount = json['RestartCount'];
    _state = new State.fromJson(json['State'], apiVersion);
    _updateDns = json['UpdateDns'];
    _volumes = new Volumes.fromJson(json['Volumes'], apiVersion);
    _volumesRw = new VolumesRw.fromJson(json['VolumesRW'], apiVersion);

    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'AppArmorProfile',
        'AppliedVolumesFrom', // ExecInfo
        'Args',
        'Config',
        'Created',
        'Driver',
        'ExecDriver',
        'HostConfig',
        'HostnamePath',
        'HostsPath',
        'Id',
        'ID',
        'Image',
        'MountLabel',
        'Name',
        'NetworkSettings',
        'Path',
        'ProcessLabel',
        'ResolvConfPath',
        'State',
        'Volumes',
        'VolumesRW'
      ],
      ApiVersion.v1_18: const [
        'AppArmorProfile',
        'AppliedVolumesFrom', // ExecInfo
        'Args',
        'Config',
        'Created',
        'Driver',
        'ExecDriver',
        'ExecIDs',
        'HostConfig',
        'HostnamePath',
        'HostsPath',
        'Id',
        'ID',
        'Image',
        'LogPath',
        'MountLabel',
        'Name',
        'NetworkSettings',
        'Path',
        'ProcessLabel',
        'ResolvConfPath',
        'RestartCount',
        'State',
        'UpdateDns',
        'Volumes',
        'VolumesRW'
      ],
      ApiVersion.v1_19: const [
        'AppArmorProfile',
        'AppliedVolumesFrom', // ExecInfo
        'Args',
        'Config',
        'Created',
        'Driver',
        'ExecDriver',
        'ExecIDs',
        'HostConfig',
        'HostnamePath',
        'HostsPath',
        'Id',
        'ID',
        'Image',
        'LogPath',
        'MountLabel',
        'MountPoints',
        'Name',
        'NetworkSettings',
        'Path',
        'ProcessLabel',
        'ResolvConfPath',
        'RestartCount',
        'State',
        'UpdateDns',
        'Volumes',
        'VolumesRW'
      ],
    }, json.keys);
  }

  Map toJson() {
    final json = {};
    if (appArmorProfile != null) json['AppArmorProfile'] = appArmorProfile;
    if (args != null) json['Args'] = args;
    if (config != null) json['Config'] = config.toJson();
    if (created == null) json['Created'] = _created.toIso8601String();
    if (driver != null) json['Driver'] = driver;
    if (execDriver != null) json['ExecDriver'] = execDriver;
    if (hostConfig != null) json['HostConfig'] = hostConfig.toJson();
    if (hostnamePath != null) json['HostnamePath'] = hostnamePath;
    if (hostsPath != null) json['HostsPath'] = hostsPath;
    if (id != null) json['Id'] = id;
    if (image != null) json['Image'] = image;
    if (mountLabel != null) json['MountLabel'] = mountLabel;
    if (mountPoints != null) json['MountPoints'] = mountPoints;
    if (name != null) json['Name'] = name;
    if (networkSettings != null) json['NetworkSettings'] =
        networkSettings.toJson();
    if (path != null) json['Path'] = path;
    if (processLabel != null) json['ProcessLabel'] = processLabel;
    if (resolveConfPath != null) json['ResolvConfPath'] = resolveConfPath;
    if (state != null) json['State'] = state.toJson();
    if (volumes != null) json['Volumes'] = volumes.toJson();
    if (volumesRw != null) json['VolumesRW'] = volumesRw.toJson();
    return json;
  }
}

class PortBindingRequest extends PortBinding {
  String get hostIp => _hostIp;
  set hostIp(String val) => _hostIp = val;

  String get hostPort => _hostPort;
  set hostPort(String val) => _hostPort = val;
}

class PortBinding {
  String _hostIp;
  String get hostIp => _hostIp;

  String _hostPort;
  String get hostPort => _hostPort;

  PortBinding();

  PortBinding.fromJson(Map json, Version apiVersion) {
    _hostIp = json['HostIp'];
    _hostPort = json['HostPort'];
  }

  Map toJson() {
    final result = {'HostPort': hostPort};
    if (hostIp != null) {
      result['HostIp'] = hostIp;
    }
    return result;
  }
}

/// See [HostConfigRequest] for documentation of the members.
class HostConfig {
  List<String> _binds;
  List<String> get binds => _toUnmodifiableListView(_binds);

  int _blkioWeight;
  int get blkioWeight => _blkioWeight;

  List<String> _capAdd;
  List<String> get capAdd => _toUnmodifiableListView(_capAdd);

  List<String> _capDrop;
  List<String> get capDrop => _toUnmodifiableListView(_capDrop);

  String _cGroupParent;
  String get cGroupParent => _cGroupParent;

  String _containerIdFile;
  String get containerIdFile => _containerIdFile;

  int _cpuPeriod;
  int get cpuPeriod => _cpuPeriod;

  int _cpuQuota;
  int get cpuQuota => _cpuQuota;

  int _cpuShares;
  int get cpuShares => _cpuShares;

  String _cpusetCpus;
  String get cpusetCpus => _cpusetCpus;

  String _cpusetMems;
  String get cpusetMems => _cpusetMems;

  Map<String, String> _devices;
  Map<String, String> get devices => _toUnmodifiableMapView(_devices);

  List<String> _dns;
  List<String> get dns => _toUnmodifiableListView(_dns);

  List<String> _dnsSearch;
  List<String> get dnsSearch => _toUnmodifiableListView(_dnsSearch);

  List<String> _extraHosts;
  List<String> get extraHosts => _toUnmodifiableListView(_extraHosts);

  String _ipcMode;
  String get ipcMode => _ipcMode;

  List<String> _links;
  List<String> get links => _toUnmodifiableListView(_links);

  Map<String, Config> _logConfig;
  Map<String, Config> get logConfig => _toUnmodifiableMapView(_logConfig);

  Map<String, String> _lxcConf;
  Map<String, String> get lxcConf => _toUnmodifiableMapView(_lxcConf);

  int _memory;
  int get memory => _memory;

  int _memorySwap;
  int get memorySwap => _memorySwap;

  String _networkMode;
  String get networkMode => _networkMode;

  bool _oomKillDisable;
  bool get oomKillDisable => _oomKillDisable;

  String _pidMode;
  String get pidMode => _pidMode;

  Map<String, List<PortBinding>> _portBindings;
  Map<String, List<PortBinding>> get portBindings =>
      _toUnmodifiableMapView(_portBindings);

  bool _privileged;
  bool get privileged => _privileged;

  bool _publishAllPorts;
  bool get publishAllPorts => _publishAllPorts;

  bool _readonlyRootFs;
  bool get readonlyRootFs => _readonlyRootFs;

  RestartPolicy _restartPolicy;
  RestartPolicy get restartPolicy => _restartPolicy;

  String _securityOpt;
  String get securityOpt => _securityOpt;

  Map _ulimits;
  Map get ulimits => _ulimits;

  String _utsMode;
  String get utsMode => _utsMode;

  List _volumesFrom;
  List get volumesFrom => _toUnmodifiableListView(_volumesFrom);

  HostConfig();

  HostConfig.fromJson(Map json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _binds = json['Binds'];
    _blkioWeight = json['BlkioWeight'];
    _capAdd = json['CapAdd'];
    _capDrop = json['CapDrop'];
    _cGroupParent = json['CgroupParent'];
    _containerIdFile = json['ContainerIDFile'];
    _cpuPeriod = json['CpuPeriod'];
    _cpusetCpus = json['CpusetCpus'];
    _cpusetMems = json['CpusetMems'];
    _cpuShares = json['CpuShares'];
    _devices = json['Devices'];
    _dns = json['Dns'];
    _dnsSearch = json['DnsSearch'];
    _extraHosts = json['ExtraHosts'];
    _ipcMode = json['IpcMode'];
    _links = json['Links'];
    _logConfig = json['LogConfig'];
    _lxcConf = json['LxcConf'];
    _memory = json['Memory'];
    _memorySwap = json['MemorySwap'];
    _networkMode = json['NetworkMode'];
    _oomKillDisable = json['OomKillDisable'];
    _pidMode = json['PidMode'];
    final Map<String, List<Map<String, String>>> portBindings =
        json['PortBindings'];
    if (portBindings != null) {
      _portBindings = new Map<String, List<PortBinding>>.fromIterable(
          portBindings.keys,
          key: (k) => k,
          value: (k) => portBindings[k]
              .map((pb) => new PortBinding.fromJson(pb, apiVersion))
              .toList());
    }
    _privileged = json['Privileged'];
    _publishAllPorts = json['PublishAllPorts'];
    _readonlyRootFs = json['ReadonlyRootfs'];
    _restartPolicy =
        new RestartPolicy.fromJson(json['RestartPolicy'], apiVersion);
    _securityOpt = json['SecurityOpt'];
    _ulimits = json['Ulimits'];
    _utsMode = json['UTSMode'];
    _volumesFrom = json['VolumesFrom'];

    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'Binds',
        'CapAdd',
        'CapDrop',
        'ContainerIDFile',
        'Devices',
        'Dns',
        'DnsSearch',
        'ExtraHosts',
        'Links',
        'LxcConf',
        'NetworkMode',
        'PortBindings',
        'Privileged',
        'PublishAllPorts',
        'RestartPolicy',
        'SecurityOpt',
        'VolumesFrom',
      ],
      ApiVersion.v1_18: const [
        'Binds',
        'CapAdd',
        'CapDrop',
        'CgroupParent',
        'ContainerIDFile',
        'CpusetCpus',
        'CpuShares',
        'Devices',
        'Dns',
        'DnsSearch',
        'ExtraHosts',
        'IpcMode',
        'Links',
        'LogConfig',
        'LxcConf',
        'Memory',
        'MemorySwap',
        'NetworkMode',
        'PidMode',
        'PortBindings',
        'Privileged',
        'PublishAllPorts',
        'ReadonlyRootfs',
        'RestartPolicy',
        'SecurityOpt',
        'Ulimits',
        'VolumesFrom',
      ],
      ApiVersion.v1_19: const [
        'Binds',
        'BlkioWeight',
        'CapAdd',
        'CapDrop',
        'CgroupParent',
        'ContainerIDFile',
        'CpusetCpus',
        'CpusetMems',
        'CpuPeriod',
        'CpuQuota',
        'CpuShares',
        'Devices',
        'Dns',
        'DnsSearch',
        'ExtraHosts',
        'IpcMode',
        'Links',
        'LogConfig',
        'LxcConf',
        'Memory',
        'MemorySwap',
        'NetworkMode',
        'OomKillDisable',
        'PidMode',
        'PortBindings',
        'Privileged',
        'PublishAllPorts',
        'ReadonlyRootfs',
        'RestartPolicy',
        'SecurityOpt',
        'Ulimits',
        'UTSMode',
        'VolumesFrom',
      ]
    }, json.keys);
  }

  Map toJson() {
    final json = {};
    if (binds != null) json['Binds'] = binds;
    if (capAdd != null) json['CapAdd'] = capAdd;
    if (capDrop != null) json['CapDrop'] = capDrop;
    if (cGroupParent != null) json['CgroupParent'] = cGroupParent;
    if (containerIdFile != null) json['ContainerIDFile'] = containerIdFile;
    if (cpuPeriod != null) json['CpuPeriod'] = cpuPeriod;
    if (cpusetCpus != null) json['CpusetCpus'] = cpusetCpus;
    if (cpusetMems != null) json['CpusetMems'] = cpusetMems;
    if (cpuQuota != null) json['CpuQuota'] = cpuShares;
    if (cpuShares != null) json['CpuShares'] = cpuShares;
    if (devices != null) json['Devices'] = devices;
    if (dns != null) json['Dns'] = dns;
    if (dnsSearch != null) json['DnsSearch'] = dnsSearch;
    if (extraHosts != null) json['ExtraHosts'] = extraHosts;
    if (ipcMode != null) json['IpcMode'] = ipcMode;
    if (links != null) json['Links'] = links;
    if (logConfig != null) json['LogConfig'] = logConfig;
    if (lxcConf != null) json['LxcConf'] = lxcConf;
    if (memory != null) json['Memory'] = memory;
    if (memorySwap != null) {
      assert(memory > 0);
      assert(memorySwap > memory);
      json['MemorySwap'] = memorySwap;
    }
    if (networkMode != null) json['NetworkMode'] = networkMode;
    if (oomKillDisable != null) json['OomKillDisable'] = oomKillDisable;
    if (pidMode != null) json['PidMode'] = pidMode;
//    if (portBindings != null) json['PortBindings'] = portBindings;
    if (portBindings != null) json['PortBindings'] = new Map.fromIterable(
        portBindings.keys,
        key: (k) => k,
        value: (k) => portBindings[k].map((pb) => pb.toJson()).toList());
    if (privileged != null) json['Privileged'] = privileged;
    if (publishAllPorts != null) json['PublishAllPorts'] = publishAllPorts;
    if (readonlyRootFs != null) json['ReadonlyRootfs'] = readonlyRootFs;
    if (restartPolicy != null) json['RestartPolicy'] = restartPolicy.toJson();
    if (securityOpt != null) json['SecurityOpt'] = securityOpt;
    if (ulimits != null) json['Ulimits'] = ulimits;
    if (utsMode != null) json['UTSMode'] = utsMode;
    if (volumesFrom != null) json['VolumesFrom'] = volumesFrom;
    return json;
  }
}

class NetworkSettings {
  String _bridge;
  String get bridge => _bridge;

  String _endpointId;
  String get endpointId => _endpointId;

  String _gateway;
  String get gateway => _gateway;

  String _globalIPv6Address;
  String get globalIPv6Address => _globalIPv6Address;

  int _globalIPv6PrefixLen;
  int get globalIPv6PrefixLen => _globalIPv6PrefixLen;

  bool _hairpinMode;
  bool get hairpinMode => _hairpinMode;

  String _ipAddress;
  String get ipAddress => _ipAddress;

  int _ipPrefixLen;
  int get ipPrefixLen => _ipPrefixLen;

  String _ipv6Gateway;
  String get ipv6Gateway => _ipv6Gateway;

  String _linkLocalIPv6Address;
  String get linkLocalIPv6Address => _linkLocalIPv6Address;

  int _linkLocalIPv6PrefixLen;
  int get linkLocalIPv6PrefixLen => _linkLocalIPv6PrefixLen;

  String _macAddress;
  String get macAddress => _macAddress;

  String _networkId;
  String get networkId => _networkId;

  UnmodifiableMapView _portMapping;
  UnmodifiableMapView get portMapping => _portMapping;

  UnmodifiableMapView _ports;
  UnmodifiableMapView get ports => _ports;

  String _sandboxKey;
  String get sandboxKey => _sandboxKey;

  UnmodifiableListView _secondaryIPAddresses;
  UnmodifiableListView get secondaryIPAddresses => _secondaryIPAddresses;

  UnmodifiableListView _secondaryIPv6Addresses;
  UnmodifiableListView get secondaryIPv6Addresses => _secondaryIPv6Addresses;

  NetworkSettings.fromJson(Map json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _bridge = json['Bridge'];
    _endpointId = json['EndpointID'];
    _gateway = json['Gateway'];
    _globalIPv6Address = json['GlobalIPv6Address'];
    _globalIPv6PrefixLen = json['GlobalIPv6PrefixLen'];
    _hairpinMode = json['HairpinMode'];
    _ipAddress = json['IPAddress'];
    _ipPrefixLen = json['IPPrefixLen'];
    _ipv6Gateway = json['IPv6Gateway'];
    _linkLocalIPv6Address = json['LinkLocalIPv6Address'];
    _linkLocalIPv6PrefixLen = json['LinkLocalIPv6PrefixLen'];
    _macAddress = json['MacAddress'];
    _networkId = json['NetworkID'];
    _portMapping = _toUnmodifiableMapView(json['PortMapping']);
    _ports = _toUnmodifiableMapView(json['Ports']);
    _sandboxKey = json['SandboxKey'];
    _secondaryIPAddresses =
        _toUnmodifiableListView(json['SecondaryIPAddresses']);
    _secondaryIPv6Addresses =
        _toUnmodifiableListView(json['SecondaryIPv6Addresses']);

    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'Bridge',
        'Gateway',
        'IPAddress',
        'IPPrefixLen',
        'MacAddress',
        'PortMapping',
        'Ports',
      ],
      ApiVersion.v1_18: const [
        'Bridge',
        'Gateway',
        'GlobalIPv6Address',
        'GlobalIPv6PrefixLen',
        'IPAddress',
        'IPPrefixLen',
        'IPv6Gateway',
        'LinkLocalIPv6Address',
        'LinkLocalIPv6PrefixLen',
        'MacAddress',
        'PortMapping',
        'Ports',
      ],
      ApiVersion.v1_19: const [
        'Bridge',
        'EndpointID',
        'Gateway',
        'GlobalIPv6Address',
        'GlobalIPv6PrefixLen',
        'HairpinMode',
        'IPAddress',
        'IPPrefixLen',
        'IPv6Gateway',
        'LinkLocalIPv6Address',
        'LinkLocalIPv6PrefixLen',
        'MacAddress',
        'NetworkID',
        'PortMapping',
        'Ports',
        'SandboxKey',
        'SecondaryIPAddresses',
        'SecondaryIPv6Addresses',
      ],
    }, json.keys);
  }

  Map toJson() {
    final json = {};
    if (bridge != null) json['Bridge'] = bridge;
    if (endpointId != null) json['EndpointID'] = endpointId;
    if (gateway != null) json['Gateway'] = gateway;
    if (globalIPv6Address != null) json['GlobalIPv6Address'] =
        globalIPv6Address;
    if (globalIPv6PrefixLen != null) json['GlobalIPv6PrefixLen'] =
        globalIPv6PrefixLen;
    if (hairpinMode != null) json['HairpinMode'] = hairpinMode;
    if (ipAddress != null) json['IPAddress'] = ipAddress;
    if (ipPrefixLen != null) json['IPPrefixLen'] = ipPrefixLen;
    if (ipv6Gateway != null) json['IPv6Gateway'] = ipv6Gateway;
    if (linkLocalIPv6Address != null) json['LinkLocalIPv6Address'] =
        linkLocalIPv6Address;
    if (linkLocalIPv6PrefixLen != null) json['LinkLocalIPv6PrefixLen'] =
        linkLocalIPv6PrefixLen;
    if (macAddress != null) json['MacAddress'] = macAddress;
    if (portMapping != null) json['PortMapping'] = portMapping;
    if (ports != null) json['Ports'] = ports;
    return json;
  }
}

class State {
  bool _dead;
  bool get dead => _dead;

  String _error;
  String get error => _error;

  int _exitCode;
  int get exitCode => _exitCode;

  DateTime _finishedAt;
  DateTime get finishedAt => _finishedAt;

  bool _outOfMemoryKilled;
  bool get outOfMemoryKilled => _outOfMemoryKilled;

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

  State.fromJson(Map json, Version apiVersion) {
    if (json == null) {
      return;
    }

    _dead = json['Dead'];
    _error = json['Error'];
    _exitCode = json['ExitCode'];
    _finishedAt = _parseDate(json['FinishedAt']);
    _outOfMemoryKilled = json['OOMKilled'];
    _paused = json['Paused'];
    _pid = json['Pid'];
    _restarting = json['Restarting'];
    _running = json['Running'];
    _startedAt = _parseDate(json['StartedAt']);
    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'ExitCode',
        'FinishedAt',
        'Paused',
        'Pid',
        'Restarting',
        'Running',
        'StartedAt',
      ],
      ApiVersion.v1_15: const [
        'Dead',
        'Error',
        'ExitCode',
        'FinishedAt',
        'OOMKilled',
        'Paused',
        'Pid',
        'Restarting',
        'Running',
        'StartedAt',
      ]
    }, json.keys);
  }

  Map toJson() {
    final json = {};
    if (exitCode != null) json['ExitCode'] = exitCode;
    if (finishedAt != null) json['FinishedAt'] = finishedAt;
    if (paused != null) json['Paused'] = paused;
    if (pid != null) json['Pid'] = pid;
    if (restarting != null) json['Restarting'] = restarting;
    if (running != null) json['Running'] = running;
    if (startedAt != null) json['StartedAt'] = startedAt;
    return json;
  }
}

class Volumes {
  Map<String, Map> _volumes = {};
  UnmodifiableMapView<String, Map> get volumes =>
      _toUnmodifiableMapView(_volumes);

  Volumes();

  Volumes.fromJson(Map json, Version apiVersion) {
    if (json == null) {
      return;
    }
    json.keys.forEach((k) => add(k, json[k]));
//    print(json);
    //assert(json.keys.length <= 0); // ensure all keys were read
  }

  Map toJson() {
    if (_volumes.isEmpty) {
      return null;
    } else {
      return volumes;
    }
  }

  // TODO(zoechi) better name for other when I figured out what it is
  void add(String path, Map other) {
    _volumes[path] = other;
  }
}

class VolumesRw {
  VolumesRw.fromJson(Map json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _checkSurplusItems(apiVersion, {ApiVersion.v1_15: const []}, json.keys);
  }

  Map toJson() {
    return null;
//    final json = {};
//    return json;
  }
}

class Config {
  bool _attachStderr;
  bool get attachStderr => _attachStderr;

  bool _attachStdin;
  bool get attachStdin => _attachStdin;

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

  UnmodifiableMapView _labels;
  UnmodifiableMapView get labels => _labels;

  String _macAddress;
  String get macAddress => _macAddress;

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

  String _volumeDriver;
  String get volumeDriver => _volumeDriver;

  Volumes _volumes;
  Volumes get volumes => _volumes;

  String _workingDir;
  String get workingDir => _workingDir;

  Config.fromJson(Map json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _attachStderr = json['AttachStderr'];
    _attachStdin = json['AttachStdin'];
    _attachStdout = json['AttachStdout'];
    _cmd = _toUnmodifiableListView(json['Cmd']);
    _cpuShares = json['CpuShares'];
    _cpuSet = json['Cpuset'];
    _domainName = json['Domainname'];
    _entryPoint = json['Entrypoint'];
    final e = json['Env'];
    if (e != null) {
      _env = _toUnmodifiableMapView(new Map<String, String>.fromIterable(
          e.map((i) => i.split('=')),
          key: (i) => i[0], value: (i) => i.length == 2 ? i[1] : null));
    }
    _exposedPorts = _toUnmodifiableMapView(json['ExposedPorts']);
    _hostName = json['Hostname'];
    _image = json['Image'];
    _labels = _parseLabels(json['Labels']);
    _macAddress = json['MacAddress'];
    _memory = json['Memory'];
    _memorySwap = json['MemorySwap'];
    _networkDisabled = json['NetworkDisabled'];
    _onBuild = _toUnmodifiableListView(json['OnBuild']);
    _openStdin = json['OpenStdin'];
    _portSpecs = json['PortSpecs'];
    _stdinOnce = json['StdinOnce'];
    _tty = json['Tty'];
    _user = json['User'];
    _volumeDriver = json['VolumeDriver'];
    _volumes = new Volumes.fromJson(json['Volumes'], apiVersion);
    _workingDir = json['WorkingDir'];

    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const [
        'AttachStderr',
        'AttachStdin',
        'AttachStdout',
        'Cmd',
        'CpuShares',
        'Cpuset',
        'Domainname',
        'Entrypoint',
        'Env',
        'ExposedPorts',
        'Hostname',
        'Image',
        'Memory',
        'MemorySwap',
        'NetworkDisabled',
        'OnBuild',
        'OpenStdin',
        'PortSpecs',
        'StdinOnce',
        'Tty',
        'User',
        'Volumes',
        'WorkingDir',
      ],
      ApiVersion.v1_18: const [
        'AttachStderr',
        'AttachStdin',
        'AttachStdout',
        'Cmd',
        'CpuShares',
        'Cpuset',
        'Domainname',
        'Entrypoint',
        'Env',
        'ExposedPorts',
        'Hostname',
        'Image',
        'Labels',
        'MacAddress',
        'Memory',
        'MemorySwap',
        'NetworkDisabled',
        'OnBuild',
        'OpenStdin',
        'PortSpecs',
        'StdinOnce',
        'Tty',
        'User',
        'Volumes',
        'WorkingDir',
      ],
      ApiVersion.v1_19: const [
        'AttachStderr',
        'AttachStdin',
        'AttachStdout',
        'Cmd',
        'CpuShares',
        'Cpuset',
        'Domainname',
        'Entrypoint',
        'Env',
        'ExposedPorts',
        'Hostname',
        'Image',
        'Labels',
        'MacAddress',
        'Memory',
        'MemorySwap',
        'NetworkDisabled',
        'OnBuild',
        'OpenStdin',
        'PortSpecs',
        'StdinOnce',
        'Tty',
        'User',
        'VolumeDriver',
        'Volumes',
        'WorkingDir'
      ],
    }, json.keys);
  }

  Map toJson() {
    final json = {};
    if (attachStderr != null) json['AttachStderr'] = attachStderr;
    if (attachStdin != null) json['AttachStdin'] = attachStdin;
    if (attachStdout != null) json['AttachStdout'] = attachStdout;
    if (cmd != null) json['Cmd'] = cmd;
    if (cpuShares != null) json['CpuShares'] = cpuShares;
    if (cpuSet != null) json['Cpuset'] = cpuSet;
    if (domainName != null) json['Domainname'] = domainName;
    if (entryPoint != null) json['Entrypoint'] = entryPoint;
    if (env != null) json['Env'] = env;
    if (exposedPorts != null) json['ExposedPorts'] = exposedPorts;
    if (hostName != null) json['Hostname'] = hostName;
    if (image != null) json['Image'] = image;
    if (memory != null) json['Memory'] = memory;
    if (memorySwap != null) json['MemorySwap'] = memorySwap;
    if (networkDisabled != null) json['NetworkDisabled'] = networkDisabled;
    if (onBuild != null) json['OnBuild'] = onBuild;
    if (openStdin != null) json['OpenStdin'] = openStdin;
    if (portSpecs != null) json['PortSpecs'] = portSpecs;
    if (stdinOnce != null) json['StdinOnce'] = stdinOnce;
    if (tty != null) json['Tty'] = tty;
    if (user != null) json['User'] = user;
    if (volumeDriver != null) json['VolumeDriver'] = volumeDriver;
    if (volumes != null) json['Volumes'] = volumes;
    if (workingDir != null) json['WorkingDir'] = workingDir;
    return json;
  }
}

class PortResponse {
  String _ip;
  String get ip => _ip;

  int _privatePort;
  int get privatePort => _privatePort;

  int _publicPort;
  int get publicPort => _publicPort;

  String _type;
  String get type => _type;

  PortResponse.fromJson(Map json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _ip = json['IP'];
    _privatePort = json['PrivatePort'];
    _publicPort = json['PublicPort'];
    _type = json['Type'];
    _checkSurplusItems(apiVersion, {
      ApiVersion.v1_15: const ['IP', 'PrivatePort', 'PublicPort', 'Type',]
    }, json.keys);
  }
}

/// The response to an auth request.
class AuthResponse {
  String _status;
  String get status => _status;

  AuthResponse.fromJson(Map json, Version apiVersion) {
    _status = json['Status'];
    _checkSurplusItems(
        apiVersion, {ApiVersion.v1_15: const ['Status']}, json.keys);
  }
}

/// A response which isn't supposed to carry any information.
class SimpleResponse {
  SimpleResponse.fromJson(Map json, Version apiVersion) {
    if (json != null && json.keys.length > 0) {
      throw json;
    }
  }
}

/// The response to a [create] request.
class CreateResponse {
  Container _container;
  Container get container => _container;

  CreateResponse.fromJson(Map json, Version apiVersion) {
    if (json['Id'] != null && (json['Id'] as String).isNotEmpty) {
      _container = new Container(json['Id']);
    }
    if (json['Warnings'] != null) {
      throw json['Warnings'];
    }
    _checkSurplusItems(
        apiVersion, {ApiVersion.v1_15: const ['Id', 'Warnings']}, json.keys);
  }
}

/// The configuration for the [create] request.
class CreateContainerRequest {
  /// The desired hostname to use for the container.
  String hostName;

  /// The desired domain name to use for the container.
  String domainName;

  /// The user to use inside the container.
  String user;

  /// Attaches to stdin.
  bool attachStdin;

  /// Attaches to stdout.
  bool attachStdout;

  /// Attaches to stderr.
  bool attachStderr;

  /// Attach standard streams to a tty, including stdin if it is not closed.
  bool tty;

  /// Opens stdin.
  bool openStdin;

  /// Close stdin after the 1st attached client disconnects.
  bool stdinOnce;

  /// A list of environment variables in the form of `VAR=value`
  Map<String, String> env; // = <String,String>{};

  /// Command(s) to run.
  List<String> cmd = <String>[];

  /// Set the entrypoint for the container.
  String entryPoint;

  /// The image name to use for the container.
  String image;

  /// Adds a map of labels to a container. To specify a map:
  /// `{"key":"value"[,"key2":"value2"]}`
  Map<String, String> labels = <String, String>{};

  /// An object mapping mountpoint paths (strings) inside the container to empty
  /// objects.
  Volumes volumes = new Volumes();

  /// The working dir for commands to run in.
  String workingDir;

  /// [true] disables networking for the container.
  bool networkDisabled;

  String macAddress = '';

  /// An object mapping ports to an empty object in the form of:
  /// `"ExposedPorts": { "<port>/<tcp|udp>: {}" }`
  Map<String, Map<String, String>> exposedPorts = <String, Map<String, String>>{
  };

  /// Customize labels for MLS systems, such as SELinux.
  List<String> securityOpts = <String>[];
  HostConfigRequest hostConfig = new HostConfigRequest();

  Map toJson() {
    final json = {};
    if (hostName != null) json['Hostname'] = hostName;
    if (domainName != null) json['Domainname'] = domainName;
    if (user != null) json['User'] = user;
    if (attachStdin != null) json['AttachStdin'] = attachStdin;
    if (attachStdout != null) json['AttachStdout'] = attachStdout;
    if (attachStderr != null) json['AttachStderr'] = attachStderr;
    if (tty != null) json['Tty'] = tty;
    if (openStdin != null) json['OpenStdin'] = openStdin;
    if (stdinOnce != null) json['StdinOnce'] = stdinOnce;
    if (env != null) json['Env'] =
        env.keys.map((k) => '${k}=${env[k]}').toList();
    if (cmd != null) json['Cmd'] = cmd;
    if (entryPoint != null) json['Entrypoint'] = entryPoint;
    if (image != null) json['Image'] = image;
    if (labels != null) json['Labels'] = labels;
    if (volumes != null) json['Volumes'] = volumes.toJson();
    if (workingDir != null) json['WorkingDir'] = workingDir;
    if (networkDisabled != null) json['NetworkDisabled'] = networkDisabled;
    if (macAddress != null) json['MacAddress'] = macAddress;
    if (exposedPorts != null) json['ExposedPorts'] = exposedPorts;
    if (securityOpts != null) json['SecurityOpts'] = securityOpts;
    if (hostConfig != null) json['HostConfig'] = hostConfig.toJson();
    return json;
  }
}

// TODO(zoechi) looks quite the same as [HostConfig]
/// The [CreateRequest.hostConfig] part of the [create] request configuration.
class HostConfigRequest extends HostConfig {
  ///  Volume bindings for this container. Each volume binding is a string of
  ///  the form `container_path` (to create a new volume for the container),
  ///  `host_path:container_path` (to bind-mount a host path into the container),
  ///  or `host_path:container_path:ro` (to make the bind-mount read-only inside
  ///  the container).
  List<String> get binds => _binds;
  set binds(List<String> val) => _binds = val;

  /// Kernel capabilities to add to the container.
  List<String> get capAdd => _capAdd;
  set capAdd(List<String> val) => _capAdd = val;

  /// Kernel capabilities to drop from the container.
  List<String> get capDrop => _capDrop;
  set capDrop(List<String> val) => _capDrop = val;

  /// Path to cgroups under which the cgroup for the container will be created.
  /// If the path is not absolute, the path is considered to be relative to the
  /// cgroups path of the init process. Cgroups will be created if they do not
  /// already exist.
  String get cGroupParent => _cGroupParent;
  set cGroupParent(String val) => _cGroupParent = val;

  /// The CPU Shares for container (ie. the relative weight vs othercontainers).
  int get cpuShares => _cpuShares;
  set cpuShares(int val) => _cpuShares = val;

  /// The cgroups CpusetCpus to use.
  String get cpusetCpus => _cpusetCpus;
  set cpusetCpus(String val) => _cpusetCpus = val;

  /// Devices to add to the container specified in the form
  /// `{ "PathOnHost": "/dev/deviceName", "PathInContainer": "/dev/deviceName", "CgroupPermissions": "mrw"}`
  Map<String, String> get devices => _devices;
  set devices(Map<String, String> val) => _devices = val;

  /// A list of dns servers for the container to use.
  List<String> get dns => _dns;
  set dns(List<String> val) => _dns = val;

  /// A list of DNS search domains.
  List<String> get dnsSearch => _dnsSearch;
  set dnsSearch(List<String> val) => _dnsSearch = val;

  /// A list of hostnames/IP mappings to be added to the container's /etc/hosts
  /// file. Specified in the form `["hostname:IP"]`.
  List<String> get extraHosts => _extraHosts;
  set extraHosts(List<String> val) => _extraHosts = val;

  /// Links for the container. Each link entry should be of of the form
  /// "container_name:alias".
  List<String> get links => _links;
  set links(List<String> val) => _links = val;

  /// Logging configuration for the container in the form
  /// `{ "Type": "<driver_name>", "Config": {"key1": "val1"}}`
  /// Available types:`json-file`, `syslog`, `none`.
  Map<String, Config> get logConfig => _logConfig;
  set logConfig(Map<String, Config> val) => _logConfig = val;

  /// LXC specific configurations. These configurations will only work when
  /// using the lxc execution driver.
  Map<String, String> get lxcConf => _lxcConf;
  set lxcConf(Map<String, String> val) => _lxcConf = val;

  /// Memory limit in bytes.
  int get memory => _memory;
  set memory(int val) => _memory = val;

  /// Total memory limit (memory + swap); set -1 to disable swap, always use
  /// this with [memory], and make the value larger than [memory].
  int get memorySwap => _memorySwap;
  set memorySwap(int val) => _memorySwap = val;

  /// Sets the networking mode for the container. Supported values are:
  /// [NetworkMode.bridge], [NetworkMode.host], and `container:<name|id>`
  String get networkMode => _networkMode;
  set networkMode(String val) => _networkMode = val;

  /// Exposed container ports and the host port they should map to. It should be
  /// specified in the form `{ <port>/<protocol>: [{ "HostPort": "<port>" }] }`.
  /// Take note that port is specified as a string and not an integer value.
  Map<String, List<PortBinding>> get portBindings => _portBindings;
  set portBindings(Map<String, List<PortBinding>> val) => _portBindings = val;

  /// Allocates a random host port for all of a container's exposed ports.
  bool get publishAllPorts => _publishAllPorts;
  set publishAllPorts(bool val) => _publishAllPorts = val;

  /// Gives the container full access to the host.
  bool get privileged => _privileged;
  set privileged(bool val) => _privileged = val;

  ///  Mount the container's root filesystem as read only.
  bool get readonlyRootFs => _readonlyRootFs;
  set readonlyRootFs(bool val) => _readonlyRootFs = val;

  /// The behavior to apply when the container exits. The value is an object
  /// with a `Name` property of either `"always"` to always restart or
  /// `"on-failure"` to restart only when the container exit code is non-zero.
  /// If `on-failure` is used, `MaximumRetryCount` controls the number of times
  /// to retry before giving up. The default is not to restart. (optional) An
  /// ever increasing delay (double the previous delay, starting at 100mS) is
  /// added before each restart to prevent flooding the server.
  RestartPolicy get restartPolicy => _restartPolicy;
  set restartPolicy(RestartPolicy val) => _restartPolicy = val;

  /// Ulimits to be set in the container, specified as
  /// `{ "Name": <name>, "Soft": <soft limit>, "Hard": <hard limit> }`, for example:
  /// `Ulimits: { "Name": "nofile", "Soft": 1024, "Hard", 2048 }`
  Map get ulimits => _ulimits;
  set ulimits(Map val) => _ulimits = val;

  /// A list of volumes to inherit from another container. Specified in the
  /// form `<container name>[:<ro|rw>]`
  List<String> get volumesFrom => _volumesFrom;
  set volumesFrom(List<String> val) => _volumesFrom = val;
}

class PortArgument {
  final String hostIp;
  final int host;
  final int container;
  final String name;
  const PortArgument(this.host, this.container, {this.name: null, this.hostIp});
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
