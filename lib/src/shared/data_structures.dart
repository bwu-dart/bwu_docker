// This code was moved to shared because it seemed a split between Remote API
// version < 1.21 and >= 1.21 is necessary and this code seemed to be still
// shareable without complicating things.
// In the end it seems not yet necessary to split yet.
library bwu_docker.src.shared.exception;

import 'dart:collection';
import 'package:bwu_docker/src/shared/json_util.dart';
import 'version.dart';
import 'package:quiver_hashcode/hashcode.dart' show hash2;

final RegExp containerNameRegex = new RegExp(r'^/?[a-zA-Z0-9_-]+$');

bool doCheckSurplusItems = false;

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
  const AuthConfig(
      {this.userName,
      this.password,
      this.auth,
      this.email,
      this.serverAddress});

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};
    if (userName != null) json['userName'] = userName;
    if (password != null) json['password;'] = password;
    json['auth;'] = auth;
    json['email;'] = email;
    if (serverAddress != null) json['serverAddress'] = serverAddress;
    return json;
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

  Map<String, dynamic> toJson() {
    return {
      'username': userName,
      'password': password,
      'email': email,
      'serveraddress': serverAddress
    };
  }
}

/// The response to an auth request.
class AuthResponse {
  String _status;
  String get status => _status;

  AuthResponse.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _status = json['Status'];
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const ['Status']
        },
        json.keys);
  }
}

/// A response which isn't supposed to carry any information.
class SimpleResponse {
  SimpleResponse.fromJson(Map<String, dynamic> json, Version apiVersion) {
    if (json != null && json.keys.length > 0) {
      throw json;
    }
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

  BlkIoStats.fromJson(Map<String, dynamic> json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _ioServiceBytesRecursive = toUnmodifiableListView /*<int>*/ (
        json['io_service_bytes_recursive'] as Iterable);
    _ioServicedRecursive = toUnmodifiableListView /*<int>*/ (
        json['io_serviced_recursive'] as Iterable);
    _ioQueueRecursive = toUnmodifiableListView /*<int>*/ (
        json['io_queue_recursive'] as Iterable);
    _ioServiceTimeRecursive = toUnmodifiableListView /*<int>*/ (
        json['io_service_time_recursive'] as Iterable);
    _ioWaitTimeRecursive = toUnmodifiableListView /*<int>*/ (
        json['io_wait_time_recursive'] as Iterable);
    _ioMergedRecursive = toUnmodifiableListView /*int*/ (
        json['io_merged_recursive'] as Iterable);
    _ioTimeRecursive = toUnmodifiableListView /*<int>*/ (
        json['io_time_recursive'] as Iterable);
    _sectorsRecursive = toUnmodifiableListView /*<int>*/ (
        json['sectors_recursive'] as Iterable);

    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
            'io_service_bytes_recursive',
            'io_serviced_recursive',
            'io_queue_recursive',
            'io_service_time_recursive',
            'io_wait_time_recursive',
            'io_merged_recursive',
            'io_time_recursive',
            'sectors_recursive',
          ]
        },
        json.keys);
  }
}

/// The available change kinds for the changes request.
enum ChangeKind { modify, add, delete, }

/// The argument for the changes request.
class ChangesResponse {
  final Set<ChangesPath> _changes = new Set<ChangesPath>();
  List<ChangesPath> get changes => new UnmodifiableListView(_changes);

  void _add(String path, ChangeKind kind) {
    _changes.add(new ChangesPath(path, kind));
  }

  List<Map<String, dynamic>> toJson() {
    return _changes
        .map /*<Map<String,dynamic>>*/ ((ChangesPath c) => c.toJson())
        .toList /*<Map<String,dynamic>>*/ ();
  }

  ChangesResponse.fromJson(List json) {
    json.forEach((Map c) {
      _add(c['Path'],
          ChangeKind.values.firstWhere((ChangeKind v) => v.index == c['Kind']));
    });
  }
}

/// A path/change kind entry for the [ChangeRequest].
class ChangesPath {
  final String path;
  final ChangeKind kind;

  ChangesPath(this.path, this.kind) {
    assert(path != null && path.isNotEmpty);
    assert(kind != null);
  }

  @override
  int get hashCode => hash2(path, kind);

  @override
  bool operator ==(Object other) {
    return (other is ChangesPath && other.path == path && other.kind == kind);
  }

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'Path': path, 'Kind': kind.index};
}

/// Container related Docker events
/// [More details about container events](https://docs.docker.com/reference/api/images/event_state.png)
class ContainerEvent extends DockerEventBase {
  static const ContainerEvent create = const ContainerEvent._(1, 'create');
  static const ContainerEvent destroy = const ContainerEvent._(2, 'destroy');
  static const ContainerEvent die = const ContainerEvent._(3, 'die');
  static const ContainerEvent execCreate =
      const ContainerEvent._(4, 'exec_create');
  static const ContainerEvent execStart =
      const ContainerEvent._(5, 'exec_start');
  static const ContainerEvent export = const ContainerEvent._(6, 'export');
  static const ContainerEvent kill = const ContainerEvent._(7, 'kill');
  static const ContainerEvent outOfMemory = const ContainerEvent._(7, 'oom');
  static const ContainerEvent pause = const ContainerEvent._(8, 'pause');
  static const ContainerEvent restart = const ContainerEvent._(9, 'restart');
  static const ContainerEvent start = const ContainerEvent._(10, 'start');
  static const ContainerEvent stop = const ContainerEvent._(11, 'stop');
  static const ContainerEvent unpause = const ContainerEvent._(11, 'unpause');

  static const List<ContainerEvent> values = const <ContainerEvent>[
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

class ConfigFile {
  AuthConfig _auths;
  AuthConfig get auths => _auths;

  UnmodifiableMapView<String, String> _httpHeaders;
  UnmodifiableMapView<String, String> get httpHeaders => _httpHeaders;

  String _fileName;
  String get fileName => _fileName;

  ConfigFile(this._auths, {Map<String, String> httpHeaders}) {
    assert(auths != null);
    _httpHeaders = toUnmodifiableMapView(httpHeaders);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};
    if (auths != null) json['auths'] = auths.toJson();
    if (httpHeaders != null) json['HttpHeaders'] = _httpHeaders;
    return json;
  }
}

/// The possible running states of a container.
class ContainerStatus {
  static const ContainerStatus restarting = const ContainerStatus('restarting');
  static const ContainerStatus running = const ContainerStatus('running');
  static const ContainerStatus paused = const ContainerStatus('paused');
  static const ContainerStatus exited = const ContainerStatus('exited');

  static const List<ContainerStatus> values = const <ContainerStatus>[
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

/// To create proper JSON for a requested path for a copy request.
class CopyRequestPath {
  String _path;
  String get path => _path;

  CopyRequestPath(this._path) {
    assert(path != null && path.isNotEmpty);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'Resource': path};
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

  CreateImageResponse.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _status = json['status'];
    _progressDetail =
        toUnmodifiableMapView /*<String,Map>*/ (json['progressDetail']);
    _id = json['id'];
    _progress = json['progress'];
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
            'status',
            'progressDetail',
            'id',
            'progress'
          ],
        },
        json.keys);
  }
}

/// Image related Docker events
class ImageEvent extends DockerEventBase {
  static const ImageEvent untag = const ImageEvent._(101, 'untag');
  static const ImageEvent delete = const ImageEvent._(102, 'delete');

  static const List<ImageEvent> values = const [untag, delete];

  final int value;
  final String _asString;

  const ImageEvent._(this.value, this._asString) : super();

  @override
  String toString() => _asString;
}

/// All Docker events in one enum
class DockerEvent {
  static const ContainerEvent containerCreate = ContainerEvent.create;
  static const ContainerEvent containerDestroy = ContainerEvent.destroy;
  static const ContainerEvent containerDie = ContainerEvent.die;
  static const ContainerEvent containerExecCreate = ContainerEvent.execCreate;
  static const ContainerEvent containerExecStart = ContainerEvent.execStart;
  static const ContainerEvent containerExport = ContainerEvent.export;
  static const ContainerEvent containerKill = ContainerEvent.kill;
  static const ContainerEvent containerOutOfMemory = ContainerEvent.outOfMemory;
  static const ContainerEvent containerPause = ContainerEvent.pause;
  static const ContainerEvent containerRestart = ContainerEvent.restart;
  static const ContainerEvent containerStart = ContainerEvent.start;
  static const ContainerEvent containerStop = ContainerEvent.stop;
  static const ContainerEvent containerUnpause = ContainerEvent.unpause;

  static const ImageEvent imageUntag = ImageEvent.untag;
  static const ImageEvent imageDelete = ImageEvent.delete;

  static const List<DockerEventBase> values = const <DockerEventBase>[
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
  @override String toString() => value.toString();
}

/// An item of the response to the events request.
class EventsResponse {
  String _from;
  String get from => _from;

  String _id;
  String get id => _id;

  DockerEventBase _status;
  DockerEventBase get status => _status;

  DateTime _time;
  DateTime get time => _time;

  int _timeNano;
  int get timeNano => _timeNano;

  EventsResponse.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _from = json['from'];
    _id = json['id'];
    if (json['status'] != null) {
      try {
        _status = DockerEvent.values
            .firstWhere((DockerEventBase e) => e.toString() == json['status']);
      } catch (e) {
        print('${e}');
      }
    }
    _time = parseDate(json['time']);
    _timeNano = json['timeNano'];
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
            'from',
            'id',
            'status',
            'time',
            'timeNano'
          ],
          RemoteApiVersion.v1x19: const [
            'from',
            'id',
            'status',
            'time',
            'timeNano'
          ]
        },
        json.keys);
  }
}

/// The response to the exec command
class Exec {
  String _id;
  String get id => _id;

  Exec.fromJson(Map<String, dynamic> json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _id = json['Id'];
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const ['Id']
        },
        json.keys);
  }
}

class GraphDriver {
  String _name;
  String get name => _name;

  List<GraphDriverData> _data;
  List<GraphDriverData> get data =>
      new UnmodifiableListView<GraphDriverData>(_data);

  GraphDriver.fromJson(Map<String, dynamic> json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _name = json['Name'] as String;
    Map<String, dynamic> dataJsonTmp = json['Data'] as Map<String, dynamic>;
    if (dataJsonTmp != null) {
      _data = new UnmodifiableListView<GraphDriverData>(dataJsonTmp.keys
          .map /*<GraphDriverData>*/ ((String k) =>
              new GraphDriverData.fromJson(
                  dataJsonTmp[k] as Map<String, dynamic>, apiVersion)));
    }
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x20: const ['Name', 'Data'],
        },
        json.keys);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};
    if (name != null) json['Name'] = name;
    if (data != null) json['Data'] =
        data.map /*<String,dynamic>*/ ((GraphDriverData data) => data.toJson());
    return json;
  }
}

class GraphDriverData {
  String _deviceId;
  String get deviceId => _deviceId;

  String _deviceName;
  String get deviceName => _deviceName;

  String _deviceSize;
  String get deviceSize => _deviceSize;

  GraphDriverData.fromJson(Map<String, dynamic> json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _deviceId = json['DeviceId'];
    _deviceName = json['DeviceName'];
    _deviceSize = json['DeviceSize'];

    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x20: const [
            'DeviceId',
            'DeviceName',
            'DeviceSize'
          ],
        },
        json.keys);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};
    if (deviceId != null) json['DeviceId'] = deviceId;
    if (deviceName != null) json['DeviceName'] = deviceName;
    if (deviceSize != null) json['DeviceSize'] = deviceSize;
    return json;
  }
}

/// A reference to an image.
class Image {
  final String name;

  Image(this.name) {
    assert(name != null && name.isNotEmpty);
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

  ImagePushResponse.fromJson(Map<String, dynamic> json, Version apiVersion) {
    final Map<String, dynamic> json = <String, dynamic>{};
    _status = json['status'];
    _progress = json['progress'];
    _progressDetail = toUnmodifiableMapView(json['progressDetail']);
    _error = json['error'];
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
            'status',
            'progress',
            'progressDetail',
            'error'
          ]
        },
        json.keys);
  }
}

/// An item of the response to removeImage.
class ImageRemoveResponse {
  String _untagged;
  String get untagged => _untagged;

  String _deleted;
  String get deleted => _deleted;

  ImageRemoveResponse.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _untagged = json['Untagged'];
    _deleted = json['Deleted'];
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const ['Untagged', 'Deleted']
        },
        json.keys);
  }
}

/// Base class for all kinds of Docker events
abstract class DockerEventBase {
  const DockerEventBase();
}

class NetworkMode {
  static const NetworkMode bridge = const NetworkMode('bridge');
  static const NetworkMode host = const NetworkMode('host');

  static const List<NetworkMode> values = const <NetworkMode>[bridge, host];

  final String value;

  const NetworkMode(this.value);

  @override
  String toString() => '${value}';
}

abstract class Network {
  factory Network.fromJson(
      String type, Map<String, dynamic> json, RemoteApiVersion apiVersion) {
    switch (type) {
      case 'bridge':
        return new BridgeNetwork.fromJson(json, apiVersion);

      default:
        throw 'Network type "${type}" isn\'t yet supported.';
    }
  }

  Network();
}

class BridgeNetwork extends Network {
  String _endpointId;
  String get endpointId => _endpointId;

  String _gateway;
  String get gateway => _gateway;

  String _ipAddress;
  String get ipAddress => _ipAddress;

  int _ipPrefixLen;
  int get ipPrefixLen => _ipPrefixLen;

  String _ipv6Gateway;
  String get ipv6Gateway => _ipv6Gateway;

  String _globalIpv6Address;
  String get globalIpv6Address => _globalIpv6Address;

  int _globalIpv6PrefixLen;
  int get globalIpv6PrefixLen => _globalIpv6PrefixLen;

  String _macAddress;
  String get macAddress => _macAddress;

  BridgeNetwork.fromJson(Map<String, dynamic> json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _endpointId = json['EndpointID'];
    _gateway = json['Gateway'];
    _ipAddress = json['IPAddress'];
    _ipPrefixLen = json['IPPrefixLen'];
    _ipv6Gateway = json['IPv6Gateway'];
    _globalIpv6Address = json['GlobalIPv6Address'];
    _globalIpv6PrefixLen = json['GlobalIPv6PrefixLen'];
    _macAddress = json['MacAddress'];

    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x17: const [
            'EndpointID',
            'Gateway',
            'IPAddress',
            'IPPrefixLen',
            'IPv6Gateway',
            'GlobalIPv6Address',
            'GlobalIPv6PrefixLen',
            'MacAddress',
          ]
        },
        json.keys);
  }
}

class PortBindingRequest extends PortBinding {
  String get hostIp => _hostIp;
  void set hostIp(String val) {
    _hostIp = val;
  }

  String get hostPort => _hostPort;
  void set hostPort(String val) {
    _hostPort = val;
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

class PortBinding {
  String _hostIp;
  String get hostIp => _hostIp;

  String _hostPort;
  String get hostPort => _hostPort;

  PortBinding();

  PortBinding.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _hostIp = json['HostIp'];
    _hostPort = json['HostPort'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, String> result = <String, String>{'HostPort': hostPort};
    if (hostIp != null) {
      result['HostIp'] = hostIp;
    }
    return result;
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

  PortResponse.fromJson(Map<String, dynamic> json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _ip = json['IP'];
    _privatePort = json['PrivatePort'];
    _publicPort = json['PublicPort'];
    _type = json['Type'];
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
            'IP',
            'PrivatePort',
            'PublicPort',
            'Type',
          ]
        },
        json.keys);
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

  ProcessConfig.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _privileged = json['privileged'];
    _user = json['user'];
    _tty = json['tty'];
    _entrypoint = json['entrypoint'];
    _arguments = toUnmodifiableListView(json['arguments'])
        as UnmodifiableListView<String>;
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
            'privileged',
            'user',
            'tty',
            'entrypoint',
            'arguments'
          ]
        },
        json.keys);
  }
}

class RegistryConfigs {
  UnmodifiableMapView _indexConfigs;
  UnmodifiableMapView get indexConfigs => _indexConfigs;

  UnmodifiableListView<String> _insecureRegistryCidrs;
  UnmodifiableListView<String> get insecureRegistryCidrs =>
      _insecureRegistryCidrs;

  RegistryConfigs.fromJson(Map<String, dynamic> json, Version apiVersion) {
    if (json == null) {
      return;
    }

    _indexConfigs = toUnmodifiableMapView(json['IndexConfigs'] as Map);
    _insecureRegistryCidrs = toUnmodifiableListView /*<String>*/ (
        json['InsecureRegistryCIDRs'] as Iterable);

    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x18: const [
            'IndexConfigs',
            'InsecureRegistryCIDRs'
          ]
        },
        json.keys);
  }
}

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

  RestartPolicy.fromJson(Map<String, dynamic> json, Version apiVersion) {
    if (json == null) {
      return;
    }
    if (json['Name'] != null && (json['Name'] as String).isNotEmpty) {
      final Iterable<RestartPolicyVariant> value = RestartPolicyVariant.values
          .where(
              (RestartPolicyVariant v) => v.toString().endsWith(json['Name']));
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

  Map<String, dynamic> toJson() {
    assert(_maximumRetryCount == null ||
        _variant == RestartPolicyVariant.onFailure);
    if (variant == null) {
      return null;
    }
    switch (_variant) {
      case RestartPolicyVariant.doNotRestart:
        return null;
      case RestartPolicyVariant.always:
        return <String, dynamic>{'always': null};
      case RestartPolicyVariant.onFailure:
        if (_maximumRetryCount != null) {
          return <String, dynamic>{
            'on-failure': null,
            'MaximumRetryCount': _maximumRetryCount
          };
        }
        return <String, dynamic>{'on-failure': null};
      default:
        throw 'Unsupported enum value.';
    }
  }
}

enum RestartPolicyVariant { doNotRestart, always, onFailure }

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

  SearchResponse.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _description = json['description'];
    _isOfficial = json['is_official'];
    if (json['is_trusted'] != null) {
      _isAutomated = json['is_trusted'];
    } else {
      _isAutomated = json['is_automated'];
    }
    _name = json['name'];
    _starCount = json['star_count'];
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
            'description',
            'is_official',
            'is_trusted',
            'is_automated',
            'name',
            'star_count'
          ]
        },
        json.keys);
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

  String _status;
  String get status => _status;

  State.fromJson(Map<String, dynamic> json, Version apiVersion) {
    if (json == null) {
      return;
    }

    _dead = json['Dead'];
    _error = json['Error'];
    _exitCode = json['ExitCode'];
    _finishedAt = parseDate(json['FinishedAt']);
    _outOfMemoryKilled = json['OOMKilled'];
    _paused = json['Paused'];
    _pid = json['Pid'];
    _restarting = json['Restarting'];
    _running = json['Running'];
    _startedAt = parseDate(json['StartedAt']);
    _status = json['Status'];
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
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
            'Status',
          ],
        },
        json.keys);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};
    if (exitCode != null) json['ExitCode'] = exitCode;
    if (finishedAt != null) json['FinishedAt'] = finishedAt;
    if (paused != null) json['Paused'] = paused;
    if (pid != null) json['Pid'] = pid;
    if (restarting != null) json['Restarting'] = restarting;
    if (running != null) json['Running'] = running;
    if (startedAt != null) json['StartedAt'] = startedAt;
    if (status != null) json['Status'] = status;
    return json;
  }
}

class StatsResponseCpuStats {
  StatsResponseCpuUsage _cupUsage;
  StatsResponseCpuUsage get cupUsage => _cupUsage;

  int _systemCpuUsage;
  int get systemCpuUsage => _systemCpuUsage;

  ThrottlingData _throttlingData;
  ThrottlingData get throttlingData => _throttlingData;

  StatsResponseCpuStats.fromJson(
      Map<String, dynamic> json, Version apiVersion) {
    _cupUsage = new StatsResponseCpuUsage.fromJson(
        json['cpu_usage'] as Map<String, dynamic>, apiVersion);
    _systemCpuUsage = json['system_cpu_usage'];
    _throttlingData = new ThrottlingData.fromJson(
        json['throttling_data'] as Map<String, dynamic>, apiVersion);
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
            'cpu_usage',
            'system_cpu_usage',
            'throttling_data'
          ]
        },
        json.keys);
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

  StatsResponseCpuUsage.fromJson(
      Map<String, dynamic> json, Version apiVersion) {
    _perCpuUsage =
        toUnmodifiableListView /*<int>*/ (json['percpu_usage'] as Iterable);
    _usageInUserMode = json['usage_in_usermode'];
    _totalUsage = json['total_usage'];
    _usageInKernelMode = json['usage_in_kernelmode'];

    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x17: const [
            'percpu_usage',
            'usage_in_usermode',
            'total_usage',
            'usage_in_kernelmode',
          ]
        },
        json.keys);
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

  StatsResponseMemoryStats.fromJson(
      Map<String, dynamic> json, Version apiVersion) {
    _stats = new StatsResponseMemoryStatsStats.fromJson(
        json['stats'] as Map<String, dynamic>, apiVersion);
    _maxUsage = json['max_usage'];
    _usage = json['usage'];
    _failCount = json['failcnt'];
    _limit = json['limit'];
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
            'stats',
            'max_usage',
            'usage',
            'failcnt',
            'limit'
          ]
        },
        json.keys);
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

  StatsResponseMemoryStatsStats.fromJson(
      Map<String, dynamic> json, Version apiVersion) {
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
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
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
        },
        json.keys);
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

  StatsResponseNetwork.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _rxBytes = json['rx_bytes'];
    _rxDropped = json['rx_dropped'];
    _rxErrors = json['rx_errors'];
    _rxPackets = json['rx_packets'];
    _txBytes = json['tx_bytes'];
    _txDropped = json['tx_dropped'];
    _txErrors = json['tx_errors'];
    _txPackets = json['tx_packets'];
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
            'rx_bytes',
            'rx_dropped',
            'rx_errors',
            'rx_packets',
            'tx_bytes',
            'tx_errors',
            'tx_dropped',
            'tx_packets',
          ]
        },
        json.keys);
  }
}

class ThrottlingData {
  int _periods;
  int get periods => _periods;

  int _throttledPeriods;
  int get throttledPeriods => _throttledPeriods;

  int _throttledTime;
  int get throttledTime => _throttledTime;

  ThrottlingData.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _periods = json['periods'];
    _throttledPeriods = json['throttled_periods'];
    _throttledTime = json['throttled_time'];

    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
            'periods',
            'throttled_periods',
            'throttled_time'
          ]
        },
        json.keys);
  }
}

/// Response to the top request.
class TopResponse {
  List<String> _titles;
  List<String> get titles => _titles;

  List<List<String>> _processes;
  List<List<String>> get processes => _processes;

  TopResponse.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _titles =
        toUnmodifiableListView /*<List<String>>*/ (json['Titles'] as Iterable);
    _processes = toUnmodifiableListView /*<List<String>>*/ (
        json['Processes'] as Iterable);
  }

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'Titles': titles, 'Processes': processes};
}

/// Response to the version request.
class VersionResponse {
  String _buildTime;
  String get buildTime => _buildTime;

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

  VersionResponse.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _buildTime = json['BuildTime'];
    _version = new Version.fromString(json['Version']);
    _os = json['Os'];
    _kernelVersion = json['KernelVersion'];
    _goVersion = json['GoVersion'];
    _gitCommit = json['GitCommit'];
    _architecture = json['Arch'];
    _apiVersion = new Version.fromString(json['ApiVersion']);
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
            'ApiVersion',
            'Arch',
            'BuildTime',
            'GitCommit',
            'GoVersion',
            'KernelVersion',
            'Os',
            'Version',
          ],
          RemoteApiVersion.v1x20: const [
            'ApiVersion',
            'Arch',
            'BuildTime',
            'GitCommit',
            'GoVersion',
            'KernelVersion',
            'Os',
            'Version',
          ]
        },
        json.keys);
  }
}

class Volumes {
  Map<String, Map> _volumes = <String, Map>{};
  UnmodifiableMapView<String, Map> get volumes =>
      toUnmodifiableMapView(_volumes);

  Volumes();

  void add(String path, Map to) {
    assert(path != null && path.isNotEmpty);
    assert(to != null);
    _volumes[path] = to;
  }

  Volumes.fromJson(Map<String, dynamic> json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _volumes.addAll(json as Map<String, Map>);
  }

  Map<String, dynamic> toJson() {
    if (_volumes.isEmpty) {
      return null;
    } else {
      return volumes;
    }
  }
}

class VolumesRequest extends Volumes {
  void add(String name, Map value) {
    _volumes[name] = value;
  }

  Map remove(String name) => _volumes.remove(name);
}

class VolumesRw {
  Map<String, bool> _volumes = <String, bool>{};
  UnmodifiableMapView<String, bool> get volumes =>
      toUnmodifiableMapView(_volumes);

  VolumesRw.fromJson(Map<String, dynamic> json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _volumes.addAll(json as Map<String, bool>);
//    checkSurplusItems(apiVersion, {ApiVersion.v1_15: const []}, json.keys);
  }

  Map<String, dynamic> toJson() {
    if (_volumes.isEmpty) {
      return null;
    } else {
      return volumes;
    }
  }
}

/// The response to a wait request.
class WaitResponse {
  int _statusCode;
  int get statusCode => _statusCode;

  WaitResponse.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _statusCode = json['StatusCode'];
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const ['StatusCode',]
        },
        json.keys);
  }
}
