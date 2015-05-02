library bwu_docker.src.data_structures;

import 'dart:collection';
import 'package:intl/intl.dart';
import 'package:quiver/core.dart' show hash2;

final containerNameRegex = new RegExp(r'^/?[a-zA-Z0-9_-]+$');

//final dateFormat = new DateFormat('yyyy-MM-ddTHH:mm:ss.SSSSSSSSSZ');

DateTime _parseDate(dynamic dateValue) {
  if (dateValue is String) {
    if (dateValue == '0001-01-01T00:00:00Z') {
      return new DateTime(1, 1, 1);
    }

    try {
//      return dateFormat.parse(
//          dateValue.substring(0, dateValue.length - 7) + 'Z', true);
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
  }));
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

/// Base class for all kinds of Docker events
abstract class DockerEventBase {
  const DockerEventBase();
}

/// Container related Docker events
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
  DockerEvent _status;
  DockerEvent get status => _status;

  String _id;
  String get id => _id;

  String _from;
  String get from => _from;

  DateTime _time;
  DateTime get time => _time;

  EventsResponse.fromJson(Map json) {
    if (json['status'] != null) {
      _status =
          DockerEvent.values.firstWhere((e) => e.toString() == json['status']);
    }
    _id = json['id'];
    _from = json['from'];
    _time = _parseDate(json['time']);
  }
}

/// The filter argument to the events request.
class EventFilter {
  final List<DockerEventBase> events = [];
  final List<Image> images = [];
  final List<Container> containers = [];

  Map toJson() {
    final json = {};
    if (events.isNotEmpty) {
      json['event'] = events.map((e) => e.toString()).toList();
    }
    if (images.isNotEmpty) {
      json['image'] = images.map((e) => e.toString).toList();
    }
    if (containers.isNotEmpty) {
      json['container'] = events.map((e) => e.toString).toList();
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

  CommitResponse.fromJson(Map json) {
    _id = json['Id'];
    ;
    _warnings = _toUnmodifiableListView(json['Warnings']);
    assert(json.keys.length <= 2); // ensure all keys were read
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
    json['Hostname'] = hostName;
    json['Domainname'] = domainName;
    json['User'] = user;
    json['AttachStdin'] = attachStdin;
    json['AttachStdout'] = attachStdout;
    json['AttachStderr'] = attachStderr;
    json['PortSpecs'] = portSpecs;
    json['Tty'] = tty;
    json['OpenStdin'] = openStdin;
    json['StdinOnce'] = stdinOnce;
    json['Env'] = env;
    json['Cmd'] = cmd;
    json['Volumes'] = volumes.toJson();
    json['WorkingDir'] = workingDir;
    json['NetworkDisabled'] = networkingDisabled;
    json['ExposedPorts'] = name;
    return json;
  }
}

/// Response to the version request.
class VersionResponse {
  String _version;
  String get version => _version;

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

  String _apiVersion;
  String get apiVersion => _apiVersion;

  VersionResponse.fromJson(Map json) {
    _version = json['Version'];
    _os = json['Os'];
    _kernelVersion = json['KernelVersion'];
    _goVersion = json['GoVersion'];
    _gitCommit = json['GitCommit'];
    _architecture = json['Arch'];
    _apiVersion = json['ApiVersion'];
    assert(json.keys.length <= 7); // ensure all keys were read
  }
}

/// Response to the info request.
class InfoResponse {
  int _containers;
  int get containers => _containers;

  int _images;
  int get images => _images;

  String _driver;
  String get driver => _driver;

  UnmodifiableListView<List<List>> _driverStatus;
  UnmodifiableListView<List<List>> get driverStatus => _driverStatus;

  String _executionDriver;
  String get executionDriver => _executionDriver;

  String _kernelVersion;
  String get kernelVersion => _kernelVersion;

  int _cpuCount;
  int get cpuCount => _cpuCount;

  int _memTotal;
  int get memTotal => _memTotal;

  String _name;
  String get name => _name;

  String _id;
  String get id => _id;

  bool _debug;
  bool get debug => _debug;

  int _fdCount;
  int get fdCount => _fdCount;

  int _goroutinesCount;
  int get goroutinesCount => _goroutinesCount;

  DateTime _systemTime;
  DateTime get systemTime => _systemTime;

  int _eventsListenersCount;
  int get eventsListenersCount => _eventsListenersCount;

  String _initPath;
  String get initPath => _initPath;

  String _initSha1;
  String get initSha1 => _initSha1;

  UnmodifiableListView<String> _indexServerAddress;
  UnmodifiableListView<String> get indexServerAddress => _indexServerAddress;

  bool _memoryLimit;
  bool get memoryLimit => _memoryLimit;

  bool _swapLimit;
  bool get swapLimit => _swapLimit;

  bool _ipv4Forwarding;
  bool get ipv4Forwarding => _ipv4Forwarding;

  UnmodifiableMapView<String, String> _labels;
  UnmodifiableMapView<String, String> get labels => _labels;

  String _dockerRootDir;
  String get dockerRootDir => _dockerRootDir;

  String _httpProxy;
  String get httpProxy => _httpProxy;

  String _httpsProxy;
  String get httpsProxy => _httpsProxy;

  String _noProxy;
  String get noProxy => _noProxy;

  String _operatingSystem;
  String get operatingSystem => _operatingSystem;

  InfoResponse.fromJson(Map json) {
    _containers = json['Containers'];
    _images = json['Images'];
    _driver = json['Driver'];
    _driverStatus = _toUnmodifiableListView(json['DriverStatus']);
    _executionDriver = json['ExecutionDriver'];
    _kernelVersion = json['KernelVersion'];
    _cpuCount = json['NCPU'];
    _memTotal = json['MemTotal'];
    _name = json['Name'];
    _id = json['ID'];
    _debug = _parseBool(json['Debug']);
    _fdCount = json['NFd'];
    _goroutinesCount = json['NGoroutines'];
    _systemTime = _parseDate(json['SystemTime']);
    _eventsListenersCount = json['NEventsListener'];
    _initPath = json['InitPath'];
    _initSha1 = json['InitSha1'];
    _indexServerAddress = json['IndexServerAddress'] is String
        ? _toUnmodifiableListView([json['IndexServerAddress']])
        : _toUnmodifiableListView(json['IndexServerAddress']);
    _memoryLimit = _parseBool(json['MemoryLimit']);
    _swapLimit = _parseBool(json['SwapLimit']);
    _ipv4Forwarding = _parseBool(json['IPv4Forwarding']);
    final l =
        json['Labels'] != null ? json['labels'].map((l) => l.split('=')) : null;
    _labels = l == null
        ? null
        : _toUnmodifiableMapView(new Map.fromIterable(l,
            key: (l) => l[0], value: (l) => l.length == 2 ? l[1] : null));
    _dockerRootDir = json['DockerRootDir'];
    _httpProxy = json['HttpProxy'];
    _httpsProxy = json['HttpsProxy'];
    _noProxy = json['NoProxy'];
    _operatingSystem = json['OperatingSystem'];
    assert(json.keys.length <= 27); // ensure all keys were read
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

  SearchResponse.fromJson(Map json) {
    _description = json['description'];
    _isOfficial = json['is_official'];
    if (json['is_trusted'] != null) {
      _isAutomated = json['is_trusted'];
    } else {
      _isAutomated = json['is_automated'];
    }
    _name = json['name'];
    _starCount = json['star_count'];
    assert(json.keys.length <= 5); // ensure all keys were read
  }
}

/// An item of the response to removeImage.
class ImageRemoveResponse {
  String _untagged;
  String get untagged => _untagged;

  String _deleted;
  String get deleted => _deleted;

  ImageRemoveResponse.fromJson(Map json) {
    _untagged = json['Untagged'];
    _deleted = json['Deleted'];
    assert(json.keys.length <= 2); // ensure all keys were read
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

  ImagePushResponse.fromJson(Map json) {
    final json = {};
    _status = json['status'];
    _progress = json['progress'];
    _progressDetail = _toUnmodifiableMapView(json['progressDetail']);
    _error = json['error'];
    assert(json.keys.length <= 4); // ensure all keys were read
  }
}

/// The response to an images/(name)/history request.
class ImageHistoryResponse {
  String _id;
  String get id => _id;

  DateTime _created;
  DateTime get created => _created;

  String _createdBy;
  String get createdBy => _createdBy;

  int _size;
  int get size => _size;

  UnmodifiableListView<String> _tags;
  UnmodifiableListView<String> get tags => _tags;

  ImageHistoryResponse.fromJson(Map json) {
    _id = json['Id'];
    _created = _parseDate(json['Created']);
    _createdBy = json['CreatedBy'];
    _size = json['Size'];
    _tags = _toUnmodifiableListView(json['Tags']);
    assert(json.keys.length <= 5); // ensure all keys were read
  }
}

/// A reference to an image.
class Image {
  final String name;

  Image(this.name) {
    assert(name != null && name.isNotEmpty);
  }
}

///// Response to an image response
//class ImageInfo {
//  DateTime _created;
//  DateTime get created => _created;
//
//  String _container;
//  String get container => _container;
//
//  ContainerConfig _containerConfig;
//  ContainerConfig get containerConfig => _containerConfig;
//
//  String _id;
//  String get id => _id;
//
//  String _parent;
//  String get parent => _parent;
//
//  int _size;
//  int get size => _size;
//
//  ImageInfo.fromJson(Map json) {
//    _created = _parseDate(json['created']);
//    _container = json['container'];
//    _containerConfig = new ContainerConfig.fromJson(json['containerConfig']);
//    _id = json['id'];
//    _parent = json['parent'];
//    _size = json['size'];
//    assert(json.keys.length <= 6); // ensure all keys were read
//  }
//}
//
//class ContainerConfig {
//  String _hostName;
//  String get hostName => _hostName;
//
//  String _user;
//  String get user => _user;
//
//  bool _attachStdin;
//  bool get attachStdin => _attachStdin;
//
//  bool _attachStdout;
//  bool get attachStdout => _attachStdout;
//
//  bool _attachStderr;
//  bool get attachStderr => _attachStderr;
//
//  PortResponse _portSpecs;
//  PortResponse get portSpecs => _portSpecs;
//
//  bool _tty;
//  bool get tty => _tty;
//
//  bool _openStdin;
//  bool get openStdin => _openStdin;
//
//  bool _stdinOnce;
//  bool get stdinOnce => _stdinOnce;
//
//  UnmodifiableMapView<String,String> _env;
//  UnmodifiableMapView<String,String> get env => _env;
//
//  UnmodifiableListView<String> _cmd;
//  UnmodifiableListView<String> get cmd => _cmd;
//
//  UnmodifiableListView<String> _dns;
//  UnmodifiableListView<String> get dns => _dns;
//
//  String _image;
//  String get image => _image;
//
//  UnmodifiableListView<String> _labels;
//  UnmodifiableListView<String> get labels => _labels;
//
//  Volumes _volumes;
//  Volumes get volumes => _volumes;
//
//  String _volumesFrom;
//  String get volumesFrom => _volumesFrom;
//
//  String _workingDir;
//  String get workingDir => _workingDir;
//
//  ContainerConfig.fromJson(Map json) {
//    _hostName = json['Hostname'];
//    _user = json['User'];
//    _attachStdin = json['AttachStdin'];
//    _attachStdout = json['AttachStdout'];
//    _attachStderr = json['AttachStderr'];
//    _portSpecs = json['PortSpecs'];
//    _tty = json['Tty'];
//    _openStdin = json['OpenStdin'];
//    _stdinOnce = json['StdinOnce'];
//    _env = _toUnmodifiableMapView(json['Env']);
//    _cmd = _toUnmodifiableListView(json['Cmd']);
//    _dns = _toUnmodifiableListView(json['Dns']);
//    _image = json['Image'];
//    _labels = _toUnmodifiableListView(json['Labels']);
//    _volumes = json['Volumes'];
//    _volumesFrom = json['VolumesFrom'];
//    _workingDir = json['WorkingDir'];
//    assert(json.keys.length <= 17); // ensure all keys were read
//  }
//
//}

/// An item of an image create response
class CreateImageResponse {
  String _status;
  String get status => _status;

  UnmodifiableMapView<String, Map> _progressDetail;
  UnmodifiableMapView<String, Map> get progressDetail => _progressDetail;

  String _id;
  String get id => _id;

  CreateImageResponse.fromJson(Map json) {
    _status = json['status'];
    _progressDetail = _toUnmodifiableMapView(json['progressDetail']);
    _id = json['id'];
    assert(json.keys.length <= 3); // ensure all keys were read
  }
}

///// Item of a response to an images request.
//class ImageResponse {
//  UnmodifiableListView<String> _repoTags;
//  UnmodifiableListView<String> get repoTags => _repoTags;
//
//  String _id;
//  String get id => _id;
//
//  String _parentId;
//  String get parentId => _parentId;
//
//  DateTime _created;
//  DateTime get created => _created;
//
//  int _size;
//  int get size => _size;
//
//  int _virtualSize;
//  int get virtualSize => _virtualSize;
//
//  UnmodifiableListView<String> _repoDigest;
//  UnmodifiableListView<String> get repoDigest => _repoDigest;
//
//  ImageResponse.fromJson(Map json) {
//    _repoTags = _toUnmodifiableListView(json['RepoTags']);
//    _id = json['Id'];
//    _parentId = json['ParentId'];
//    _created = _parseDate(json['Created']);
//    _size = json['Size'];
//    _virtualSize = json['VirtualSize'];
//    _repoDigest = _toUnmodifiableListView(json['RepoDigest']);
//    assert(json.keys.length <= 7); // ensure all keys were read
//  }
//}

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
    json['auths'] = auths.toJson();
    if (httpHeaders != null) {
      json['HttpHeaders'] = _httpHeaders;
    }
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
    if (userName != null) {
      json['userName'] = userName;
    }
    if (password != null) {
      json['password;'] = password;
    }
    json['auth;'] = auth;
    json['email;'] = email;
    if (serverAddress != null) {
      json['serverAddress'] = serverAddress;
    }

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

  WaitResponse.fromJson(Map json) {
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

  StatsResponseNetwork.fromJson(Map json) {
    _rxDropped = json['rx_dropped'];
    _rxBytes = json['rx_bytes'];
    _rxErrors = json['rx_errors'];
    _txPackets = json['tx_packets'];
    _txDropped = json['tx_dropped'];
    _rxPackets = json['rx_packets'];
    _txErrors = json['tx_errors'];
    _txBytes = json['tx_bytes'];
    assert(json.keys.length <= 8); // ensure all keys were read
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

  StatsResponseMemoryStats.fromJson(Map json) {
    _stats = new StatsResponseMemoryStatsStats.fromJson(json['name']);
    _maxUsage = json['max_usage'];
    _usage = json['usage'];
    _failCount = json['failcnt'];
    _limit = json['limit'];
    assert(json.keys.length <= 5); // ensure all keys were read
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

  StatsResponseMemoryStatsStats.fromJson(Map json) {
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
    assert(json.keys.length <= 29); // ensure all keys were read
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

  StatsResponseCpuUsage.fromJson(Map json) {
    _perCpuUsage = _toUnmodifiableListView(json['percpu_usage']);
    _usageInUserMode = json['usage_in_usermode'];
    _totalUsage = json['total_usage'];
    _usageInKernelMode = json['usage_in_kernelmode'];
    assert(json.keys.length <= 4); // ensure all keys were read
  }
}

class StatsResponseCpuStats {
  StatsResponseCpuUsage _cupUsage;
  StatsResponseCpuUsage get cupUsage => _cupUsage;

  int _systemCpuUsage;
  int get systemCpuUsage => _systemCpuUsage;

  UnmodifiableListView _throttlingData;
  UnmodifiableListView get throttlingData => _throttlingData;

  StatsResponseCpuStats.fromJson(Map json) {
    _cupUsage = new StatsResponseCpuUsage.fromJson(json['cpu_usage']);
    _systemCpuUsage = json['system_cpu_usage'];
    _throttlingData = _toUnmodifiableListView(json['throttling_data']);
    assert(json.keys.length <= 3); // ensure all keys were read
  }
}

/// The response to a logs request.
class StatsResponse {
  DateTime _read;
  DateTime get read => _read;

  StatsResponseNetwork _network;
  StatsResponseNetwork get network => _network;

  StatsResponseMemoryStats _memoryStats;
  StatsResponseMemoryStats get memoryStats => _memoryStats;

  Map _blkIoStats;
  Map get blkIoStats => _blkIoStats;

  StatsResponseCpuStats _cpuStats;
  StatsResponseCpuStats get cpuStats => _cpuStats;

  StatsResponse.fromJson(Map json) {
    _read = _parseDate(json['read']);
    _network = new StatsResponseNetwork.fromJson(json['network']);
    _memoryStats = new StatsResponseMemoryStats.fromJson(json['memory_stats']);
    _blkIoStats = _toUnmodifiableMapView(json['blkio_stats']);
    _cpuStats = new StatsResponseCpuStats.fromJson(json['cpu_stats']);
    assert(json.keys.length <= 5); // ensure all keys were read
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
  int get hashCode => hash2(path, kind);

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

  TopResponse.fromJson(Map json) {
    _titles = _toUnmodifiableListView(json['Titles']);
    _processes = _toUnmodifiableListView(json['Processes']);
  }

  Map toJson() {
    return {'Titles': titles, 'Processes': processes};
  }
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

  RestartPolicy.fromJson(Map json) {
    if (json['Name'] != null && json['Name'].isNotEmpty) {
      final value = RestartPolicyVariant.values
          .where((v) => v.toString().endsWith(json['Name']));
      print(json);
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

  String _image;
  String get image => _image;

  List<String> _names;
  List<String> get names => _names;

  List<PortArgument> _ports;
  List<PortArgument> get ports => _ports;

  String _status;
  String get status => _status;

  Container(this._id);

  Container.fromJson(Map json) {
    _id = json['Id'];
    _command = json['Command'];
    _created = _parseDate(json['Created']);
    _image = json['Image'];
    _names = json['Names'];
    _ports = json['Ports'] == null
        ? null
        : json['Ports'].map((p) => new PortResponse.fromJson(p)).toList();
    _status = json['Status'];

    assert(json.keys.length <= 7); // ensure all keys were read
  }

  Map toJson() {
    final json = {};
    json['Id'] = id;
    json['Command'] = command;
    json['Created'] = created == null ? null : created.toIso8601String();
    json['Image'] = image;
    json['Names'] = names;
    json['Ports'] = ports;
    json['Status'] = status;

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

  String _os;
  String get os => _os;

  String _parent;
  String get parent => _parent;

  int _size;
  int get size => _size;

  int _virtualSize;
  int get virtualSize => _virtualSize;

  UnmodifiableListView<String> _repoTags;
  UnmodifiableListView<String> get repoTags => _repoTags;

  ImageInfo.fromJson(Map json) {
    if (json == null) {
      return;
    }
    _architecture = json['Architecture'];
    _author = json['Author'];
    _comment = json['Comment'];
    _config = new Config.fromJson(json['Config']);
    _container = json['Container'];
    _containerConfig = new Config.fromJson(json['ContainerConfig']);
    _created = _parseDate(json['Created']);
    _dockerVersion = json['DockerVersion'];
    _id = json['Id'];
    _os = json['Os'];
    // depending on the request `Parent` or `ParentId` is set.
    _parent = json['Parent'];
    _parent = json['ParentId'] != null ? json['ParentId'] : null;
    _size = json['Size'];
    _virtualSize = json['VirtualSize'];
    _repoTags = _toUnmodifiableListView(json['RepoTags']);
    assert(json.keys.length <= 14); // ensure all keys were read
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

  ContainerInfo.fromJson(Map json) {
    _appArmorProfile = json['AppArmorProfile'];
    _args = _toUnmodifiableListView(json['Args']);
    _config = new Config.fromJson(json['Config']);
    _created = _parseDate(json['Created']);
    _driver = json['Driver'];
    _execDriver = json['ExecDriver'];
    _hostConfig = new HostConfig.fromJson(json['HostConfig']);
    _hostnamePath = json['HostnamePath'];
    _hostsPath = json['HostsPath'];
    _id = json['Id'];
    _image = json['Image'];
    _mountLabel = json['MountLabel'];
    _name = json['Name'];
    _networkSettings = new NetworkSettings.fromJson(json['NetworkSettings']);
    _path = json['Path'];
    _processLabel = json['ProcessLabel'];
    _resolvConfPath = json['ResolvConfPath'];
    _state = new State.fromJson(json['State']);
    _volumes = new Volumes.fromJson(json['Volumes']);
    _volumesRw = new VolumesRw.fromJson(json['VolumesRW']);
    assert(json.keys.length <= 20); // ensure all keys are read
  }

  Map toJson() {
    final json = {};
    json['AppArmorProfile'] = appArmorProfile;
    json['Args'] = args;
    json['Config'] = config.toJson();
    json['Created'] = created == null ? null : _created.toIso8601String();
    json['Driver'] = driver;
    json['ExecDriver'] = execDriver;
    json['HostConfig'] = hostConfig.toJson();
    json['HostnamePath'] = hostnamePath;
    json['HostsPath'] = hostsPath;
    json['Id'] = id;
    json['Image'] = image;
    json['MountLabel'] = mountLabel;
    json['Name'] = name;
    json['NetworkSettings'] = networkSettings.toJson();
    json['Path'] = path;
    json['ProcessLabel'] = processLabel;
    json['ResolvConfPath'] = resolvConfPath;
    json['State'] = state.toJson();
    json['Volumes'] = volumes.toJson();
    json['VolumesRW'] = volumesRw.toJson();
    return json;
  }
}

class HostConfig {
  UnmodifiableListView<String> _binds;
  UnmodifiableListView<String> get binds => _binds;

  UnmodifiableListView<String> _capAdd;
  UnmodifiableListView<String> get capAdd => _capAdd;

  UnmodifiableListView<String> _capDrop;
  UnmodifiableListView<String> get capDrop => _capDrop;

  String _containerIdFile;
  String get containerIdFile => _containerIdFile;

  UnmodifiableListView<String> _devices;
  UnmodifiableListView<String> get devices => _devices;

  UnmodifiableListView<String> _dns;
  UnmodifiableListView<String> get dns => _dns;

  UnmodifiableListView<String> _dnsSearch;
  UnmodifiableListView<String> get dnsSearch => _dnsSearch;

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

  RestartPolicy _restartPolicy;
  RestartPolicy get restartPolicy => _restartPolicy;

  String _securityOpt;
  String get securityOpt => _securityOpt;

  UnmodifiableListView _volumesFrom;
  UnmodifiableListView get volumesFrom => _volumesFrom;

  HostConfig.fromJson(Map json) {
    if (json == null) {
      return;
    }
    _binds = _toUnmodifiableListView(json['Binds']);
    _capAdd = _toUnmodifiableListView(json['CapAdd']);
    _capDrop = _toUnmodifiableListView(json['CapDrop']);
    _containerIdFile = json['ContainerIDFile'];
    _devices = _toUnmodifiableListView(json['Devices']);
    _dns = _toUnmodifiableListView(json['Dns']);
    _dnsSearch = _toUnmodifiableListView(json['DnsSearch']);
    _extraHosts = _toUnmodifiableListView(json['ExtraHosts']);
    _links = _toUnmodifiableListView(json['Links']);
    _lxcConf = _toUnmodifiableListView(json['LxcConf']);
    _networkMode = json['NetworkMode'];
    _portBindings = _toUnmodifiableMapView(json['PortBindings']);
    _privileged = json['Privileged'];
    _publishAllPorts = json['PublishAllPorts'];
    _restartPolicy = new RestartPolicy.fromJson(json['RestartPolicy']);
    _securityOpt = json['SecurityOpt'];
    _volumesFrom = _toUnmodifiableListView(json['VolumesFrom']);
    assert(json.keys.length <= 17); // ensure all keys were read
  }

  Map toJson() {
    final json = {};
    json['Binds'] = binds;
    json['CapAdd'] = capAdd;
    json['CapDrop'] = capDrop;
    json['ContainerIDFile'] = containerIdFile;
    json['Devices'] = devices;
    json['Dns'] = dns;
    json['DnsSearch'] = dnsSearch;
    json['ExtraHosts'] = extraHosts;
    json['Links'] = links;
    json['LxcConf'] = lxcConf;
    json['NetworkMode'] = networkMode;
    json['PortBindings'] = portBindings;
    json['Privileged'] = privileged;
    json['PublishAllPorts'] = publishAllPorts;
    json['RestartPolicy'] = restartPolicy.toJson();
    json['SecurityOpt'] = securityOpt;
    json['VolumesFrom'] = volumesFrom;
    return json;
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

  NetworkSettings.fromJson(Map json) {
    if (json == null) {
      return;
    }
    _bridge = json['Bridge'];
    _gateway = json['Gateway'];
    _ipAddress = json['IPAddress'];
    _ipPrefixLen = json['IPPrefixLen'];
    _macAddress = json['MacAddress'];
    _portMapping = _toUnmodifiableMapView(json['PortMapping']);
    _ports = _toUnmodifiableMapView(json['Ports']);
    assert(json.keys.length <= 7); // ensure all keys were read
  }

  Map toJson() {
    final json = {};
    json['Bridge'] = bridge;
    json['Gateway'] = gateway;
    json['IPAddress'] = ipAddress;
    json['IPPrefixLen'] = ipPrefixLen;
    json['MacAddress'] = macAddress;
    json['PortMapping'] = portMapping;
    json['Ports'] = ports;
    return json;
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

  State.fromJson(Map json) {
    if (json == null) {
      return;
    }
    _exitCode = json['ExitCode'];
    _finishedAt = _parseDate(json['FinishedAt']);
    _paused = json['Paused'];
    _pid = json['Pid'];
    _restarting = json['Restarting'];
    _running = json['Running'];
    _startedAt = _parseDate(json['StartedAt']);
    assert(json.keys.length <= 7); // ensure all keys were read
  }

  Map toJson() {
    final json = {};
    json['ExitCode'] = exitCode;
    json['FinishedAt'] = finishedAt;
    json['Paused'] = paused;
    json['Pid'] = pid;
    json['Restarting'] = restarting;
    json['Running'] = running;
    json['StartedAt'] = startedAt;

    return json;
  }
}

class Volumes {
  Map<String, Map> _volumes = {};
  UnmodifiableMapView<String, Map> get volumes =>
      _toUnmodifiableMapView(_volumes);

  Volumes();

  Volumes.fromJson(Map json) {
    if (json == null) {
      return;
    }
    json.keys.forEach((k) => add(k, json[k]));
    print(json);
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
  VolumesRw.fromJson(Map json) {
    if (json == null) {
      return;
    }
    assert(json.keys.length <= 0); // ensure all keys were read
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

  Volumes _volumes;
  Volumes get volumes => _volumes;

  String _workingDir;
  String get workingDir => _workingDir;

  Config.fromJson(Map json) {
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
    _memory = json['Memory'];
    _memorySwap = json['MemorySwap'];
    _networkDisabled = json['NetworkDisabled'];
    _onBuild = _toUnmodifiableListView(json['OnBuild']);
    _openStdin = json['OpenStdin'];
    _portSpecs = json['PortSpecs'];
    _stdinOnce = json['StdinOnce'];
    _tty = json['Tty'];
    _user = json['User'];
    _volumes = new Volumes.fromJson(json['Volumes']);
    _workingDir = json['WorkingDir'];
    assert(json.keys.length <= 23); // ensure all keys were read
  }

  Map toJson() {
    final json = {};
    json['AttachStderr'] = attachStderr;
    json['AttachStdin'] = attachStdin;
    json['AttachStdout'] = attachStdout;
    json['Cmd'] = cmd;
    json['CpuShares'] = cpuShares;
    json['Cpuset'] = cpuSet;
    json['Domainname'] = domainName;
    json['Entrypoint'] = entryPoint;
    json['Env'] = env;
    json['ExposedPorts'] = exposedPorts;
    json['Hostname'] = hostName;
    json['Image'] = image;
    json['Memory'] = memory;
    json['MemorySwap'] = memorySwap;
    json['NetworkDisabled'] = networkDisabled;
    json['OnBuild'] = onBuild;
    json['OpenStdin'] = openStdin;
    json['PortSpecs'] = portSpecs;
    json['StdinOnce'] = stdinOnce;
    json['Tty'] = tty;
    json['User'] = user;
    json['_volumes'] = volumes;
    json['WorkingDir'] = workingDir;
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

  PortResponse.fromJson(Map json) {
    if (json == null) {
      return;
    }
    _ip = json['IP'];
    _privatePort = json['PrivatePort'];
    _publicPort = json['PublicPort'];
    _type = json['Type'];
    assert(json.keys.length <= 4); // ensure all keys were read
  }
}

/// The response to an auth request.
class AuthResponse {
  String _status;
  String get status => _status;

  AuthResponse.fromJson(Map json) {
    _status = json['Status'];
    assert(json.keys.length <= 1); // ensure all keys were read
  }
}

/// A response which isn't supposed to carry any information.
class SimpleResponse {
  SimpleResponse.fromJson(Map json) {
    if (json != null && json.keys.length > 0) {
      throw json;
    }
  }
}

/// The response to a [create] request.
class CreateResponse {
  Container _container;
  Container get container => _container;

  CreateResponse.fromJson(Map json) {
    if (json['Id'] != null && (json['Id'] as String).isNotEmpty) {
      _container = new Container(json['Id']);
    }
    if (json['Warnings'] != null) {
      throw json['Warnings'];
    }
    assert(json.keys.length <= 2);
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
    json['Hostname'] = hostName;
    json['Domainname'] = domainName;
    json['User'] = user;
    json['AttachStdin'] = attachStdin;
    json['AttachStdout'] = attachStdout;
    json['AttachStderr'] = attachStderr;
    json['Tty'] = tty;
    json['OpenStdin'] = openStdin;
    json['StdinOnce'] = stdinOnce;
    json['Env'] = env;
    json['Cmd'] = cmd;
    json['Entrypoint'] = entryPoint;
    json['Image'] = image;
    json['Labels'] = labels;
    json['Volumes'] = volumes != null ? volumes.toJson() : null;
    json['WorkingDir'] = workingDir;
    json['NetworkDisabled'] = networkDisabled;
    json['MacAddress'] = macAddress;
    json['ExposedPorts'] = exposedPorts;
    json['SecurityOpts'] = securityOpts;
    json['HostConfig'] = hostConfig != null ? hostConfig.toJson() : null;
    return json;
  }
}

/// The [CreateRequest.hostConfig] part of the [create] request configuration.
class HostConfigRequest {
  ///  Volume bindings for this container. Each volume binding is a string of
  ///  the form `container_path` (to create a new volume for the container),
  ///  `host_path:container_path` (to bind-mount a host path into the container),
  ///  or `host_path:container_path:ro` (to make the bind-mount read-only inside
  ///  the container).
  List<String> binds = <String>[];
  /// Links for the container. Each link entry should be of of the form
  /// "container_name:alias".
  List<String> links = <String>[];
  /// LXC specific configurations. These configurations will only work when
  /// using the lxc execution driver.
  Map<String, String> lxcConf = <String, String>{};
  /// Memory limit in bytes.
  int memory;
  /// Total memory limit (memory + swap); set -1 to disable swap, always use
  /// this with [memory], and make the value larger than [memory].
  int memorySwap;
  /// The CPU Shares for container (ie. the relative weight vs othercontainers).
  int cpuShares;
  /// The cgroups CpusetCpus to use.
  String cpusetCpus;
  /// Exposed container ports and the host port they should map to. It should be
  /// specified in the form `{ <port>/<protocol>: [{ "HostPort": "<port>" }] }`.
  /// Take note that port is specified as a string and not an integer value.
  Map<String, Map<String, String>> portBindings = <String, Map<String, String>>{
  };
  /// Allocates a random host port for all of a container's exposed ports.
  bool publishAllPorts;
  /// Gives the container full access to the host.
  bool privileged;
  ///  Mount the container's root filesystem as read only.
  bool readonlyRootFs;
  /// A list of dns servers for the container to use.
  List<String> dns = <String>[];
  /// A list of DNS search domains.
  List<String> dnsSearch = <String>[];
  /// A list of hostnames/IP mappings to be added to the container's /etc/hosts
  /// file. Specified in the form `["hostname:IP"]`.
  List<String> extraHosts = <String>[];
  /// A list of volumes to inherit from another container. Specified in the
  /// form `<container name>[:<ro|rw>]`
  List<String> volumesFrom = <String>[];
  /// Kernel capabilities to add to the container.
  List<String> capAdd = <String>[];
  /// Kernel capabilities to drop from the container.
  List<String> capDrop = <String>[];
  /// The behavior to apply when the container exits. The value is an object
  /// with a `Name` property of either `"always"` to always restart or
  /// `"on-failure"` to restart only when the container exit code is non-zero.
  /// If `on-failure` is used, `MaximumRetryCount` controls the number of times
  /// to retry before giving up. The default is not to restart. (optional) An
  /// ever increasing delay (double the previous delay, starting at 100mS) is
  /// added before each restart to prevent flooding the server.
  RestartPolicy restartPolicy;
  /// Sets the networking mode for the container. Supported values are:
  /// [NetworkMode.bridge], [NetworkMode.host], and `container:<name|id>`
  String networkMode;
  /// Devices to add to the container specified in the form
  /// `{ "PathOnHost": "/dev/deviceName", "PathInContainer": "/dev/deviceName", "CgroupPermissions": "mrw"}`
  Map<String, String> devices = <String, String>{};
  /// Ulimits to be set in the container, specified as
  /// `{ "Name": <name>, "Soft": <soft limit>, "Hard": <hard limit> }`, for example:
  /// `Ulimits: { "Name": "nofile", "Soft": 1024, "Hard", 2048 }`
  Map uLimits = {};
  /// Logging configuration for the container in the form
  /// `{ "Type": "<driver_name>", "Config": {"key1": "val1"}}`
  /// Available types:`json-file`, `syslog`, `none`.
  Map<String, Config> logConfig = <String, Config>{};
  /// Path to cgroups under which the cgroup for the container will be created.
  /// If the path is not absolute, the path is considered to be relative to the
  /// cgroups path of the init process. Cgroups will be created if they do not
  /// already exist.
  String cGroupParent;

  Map toJson() {
    final json = {};
    json['Binds'] = binds;
    json['Links'] = links;
    json['LxcConf'] = lxcConf;
    json['Memory'] = memory;
    if (memorySwap != null) {
      assert(memory != null && memory > 0);
      assert(memorySwap > memory);
      json['MemorySwap'] = memorySwap;
    }
    json['CpuShares'] = cpuShares;
    json['CpusetCpus'] = cpusetCpus;
    json['PortBindings'] = portBindings;
    json['PublishAllPorts'] = publishAllPorts;
    json['Privileged'] = privileged;
    json['ReadonlyRootfs'] = readonlyRootFs;
    json['Dns'] = dns;
    json['DnsSearch'] = dnsSearch;
    json['ExtraHosts'] = extraHosts;
    json['VolumesFrom'] = volumesFrom;
    json['CapAdd'] = capAdd;
    json['CapDrop'] = capDrop;
    json['RestartPolicy'] = restartPolicy;
    json['NetworkMode'] = networkMode;
    json['Devices'] = devices;
    json['Ulimits'] = uLimits;
    json['LogConfig'] = logConfig;
    json['CgroupParent'] = cGroupParent;

    return json;
  }
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
