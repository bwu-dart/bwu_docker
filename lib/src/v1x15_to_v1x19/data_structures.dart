library bwu_docker.src.v1x15_to_v1x19.data_structures;

import 'dart:collection';
import 'package:bwu_docker/src/shared/version.dart';
import 'package:bwu_docker/src/shared/json_util.dart';
import 'package:bwu_docker/src/shared/data_structures.dart';

export 'package:bwu_docker/src/shared/version.dart';
export 'package:bwu_docker/src/shared/data_structures.dart';

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

  ExecInfo.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _id = json['ID'];
    _running = json['Running'];
    _exitCode = json['ExitCode'];
    _processConfig = new ProcessConfig.fromJson(
        json['ProcessConfig'] as Map<String, dynamic>, apiVersion);
    _openStdin = json['OpenStdin'];
    _openStderr = json['OpenStderr'];
    _openStdout = json['OpenStdout'];
    _container = new ContainerInfo.fromJson(
        json['Container'] as Map<String, dynamic>, apiVersion);

    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
            'ID',
            'Running',
            'ProcessConfig',
            'ExitCode',
            'OpenStdin',
            'OpenStderr',
            'OpenStdout',
            'Container',
          ]
        },
        json.keys);
  }
}

/// Response to a commit request.
class CommitResponse {
  String _id;
  String get id => _id;

  UnmodifiableListView<String> _warnings;
  UnmodifiableListView<String> get warnings => _warnings;

  CommitResponse.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _id = json['Id'];
    _warnings = toUnmodifiableListView(json['Warnings'])
        as UnmodifiableListView<String>;
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const ['Id', 'Warnings']
        },
        json.keys);
  }
}

/// The filter argument to the events request.
class EventsFilter {
  final List<DockerEventBase> events = <DockerEventBase>[];
  final List<Image> images = <Image>[];
  final List<Container> containers = <Container>[];

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};
    if (events.isNotEmpty) {
      json['event'] = events
          .map /*<String>*/ ((DockerEventBase e) => e.toString())
          .toList();
    }
    if (images.isNotEmpty) {
      json['image'] = images.map /*<String>*/ ((Image e) => e.name).toList();
    }
    if (containers.isNotEmpty) {
      json['container'] =
          containers.map /*<String>*/ ((Container e) => e.id).toList();
    }
    return json;
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
  UnmodifiableListView<PortArgument> _portSpecs;
  UnmodifiableListView<PortArgument> get portSpecs => _portSpecs;
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

  CommitRequest(
      {this.hostName,
      this.domainName,
      this.user,
      this.attachStdin,
      this.attachStdout,
      this.attachStderr,
      List<PortArgument> portSpecs,
      this.tty,
      this.openStdin,
      this.stdinOnce,
      Map<String, String> env,
      List<String> cmd,
      this.volumes,
      this.workingDir,
      this.networkingDisabled,
      Map<String, Map> exposedPorts}) {
    _portSpecs = toUnmodifiableListView(portSpecs) as List<PortArgument>;
    _env = toUnmodifiableMapView(env);
    _name = toUnmodifiableMapView(exposedPorts);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};
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

  InfoResponse.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _containers = json['Containers'];
    _cpuCfsPeriod = json['CpuCfsPeriod'];
    _cpuCfsQuota = json['CpuCfsQuota'];
    _debug = parseBool(json['Debug']);
    _dockerRootDir = json['DockerRootDir'];
    _driver = json['Driver'];
    _driverStatus = toUnmodifiableListView /*<List<List>>*/ (
        json['DriverStatus'] as Iterable);
    _executionDriver = json['ExecutionDriver'];
    _experimentalBuild = json['ExperimentalBuild'];
    _httpProxy = json['HttpProxy'];
    _httpsProxy = json['HttpsProxy'];
    _id = json['ID'];
    _images = json['Images'];
    _indexServerAddress = json['IndexServerAddress'] is String
        ? toUnmodifiableListView /*<String>*/ ([json['IndexServerAddress']])
        : toUnmodifiableListView /*<String>*/ (
            json['IndexServerAddress'] as Iterable);
    _initPath = json['InitPath'];
    _initSha1 = json['InitSha1'];
    _ipv4Forwarding = parseBool(json['IPv4Forwarding']);
    _kernelVersion = json['KernelVersion'];
    _labels = parseLabels(json['Labels'] as Map<String, List<String>>);
    _loggingDriver = json['LoggingDriver'];
    _memoryLimit = parseBool(json['MemoryLimit']);
    _memTotal = json['MemTotal'];
    _name = json['Name'];
    _cpuCount = json['NCPU'];
    _eventsListenersCount = json['NEventsListener'];
    _fdCount = json['NFd'];
    _goroutinesCount = json['NGoroutines'];
    _noProxy = json['NoProxy'];
    _oomKillDisable = json['OomKillDisable'];
    _operatingSystem = json['OperatingSystem'];
    _registryConfigs = new RegistryConfigs.fromJson(
        json['RegistryConfigs'] as Map<String, dynamic>, apiVersion);
    _swapLimit = parseBool(json['SwapLimit']);
    _systemTime = parseDate(json['SystemTime']);

    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
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
          RemoteApiVersion.v1x18: const [
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
          RemoteApiVersion.v1x19: const [
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
        },
        json.keys);
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

  ImageHistoryResponse.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _id = json['Id'];
    _comment = json['Comment'];
    _created = parseDate(json['Created']);
    _createdBy = json['CreatedBy'];
    _size = json['Size'];
    _tags = toUnmodifiableListView /*<String>*/ (json['Tags'] as Iterable);
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
            'Id',
            'Created',
            'CreatedBy',
            'Size',
            'Tags'
          ],
          RemoteApiVersion.v1x19: const [
            'Id',
            'Comment',
            'Created',
            'CreatedBy',
            'Size',
            'Tags'
          ],
        },
        json.keys);
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

  StatsResponse.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _blkIoStats = new BlkIoStats.fromJson(
        json['blkio_stats'] as Map<String, dynamic>, apiVersion);
    _cpuStats = new StatsResponseCpuStats.fromJson(
        json['cpu_stats'] as Map<String, dynamic>, apiVersion);
    _memoryStats = new StatsResponseMemoryStats.fromJson(
        json['memory_stats'] as Map<String, dynamic>, apiVersion);
    _network = new StatsResponseNetwork.fromJson(
        json['network'] as Map<String, dynamic>, apiVersion);
    _preCpuStats = new StatsResponseCpuStats.fromJson(
        json['precpu_stats'] as Map<String, dynamic>, apiVersion);
    _read = parseDate(json['read']);
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
            'blkio_stats',
            'cpu_stats',
            'memory_stats',
            'network',
            'read',
          ],
          RemoteApiVersion.v1x19: const [
            'blkio_stats',
            'cpu_stats',
            'memory_stats',
            'network',
            'precpu_stats',
            'read',
          ],
        },
        json.keys);
  }
}

/// Basic info about a container.
class Container {
  String _id;
  String get id => _id;

  String _command;
  String get command => _command;

  DateTime _created;
  DateTime get created => _created;

  UnmodifiableMapView<String, String> _labels;
  UnmodifiableMapView<String, String> get labels => _labels;

  String _image;
  String get image => _image;

  List<String> _names;
  List<String> get names => _names;

  List<PortResponse> _ports;
  List<PortResponse> get ports => _ports;

  String _status;
  String get status => _status;

  Container(this._id);

  Container.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _id = json['Id'];
    _command = json['Command'];
    _created = parseDate(json['Created']);
    _labels = parseLabels(json['Labels'] as Map<String, List<String>>);
    _image = json['Image'];
    _names = json['Names'] as List<String>;
    _ports = json['Ports'] == null
        ? null
        : (json['Ports'] as List<Map<String, dynamic>>)
            .map /*<PortResponse>*/ ((Map<String, dynamic> p) =>
                new PortResponse.fromJson(p, apiVersion))
            .toList();
    _status = json['Status'];

    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
            'Id',
            'Command',
            'Created',
            'Image',
            'Names',
            'Ports',
            'Status'
          ],
//          RemoteApiVersion.v1x18: [
//            'Id',
//            'Command',
//            'Created',
//            'Labels',
//            'Image',
//            'Names',
//            'Ports',
//            'Status'
//          ],
          RemoteApiVersion.v1x19: [
            'Id',
            'Command',
            'Created',
            'Labels',
            'Image',
            'Names',
            'Ports',
            'Status'
          ],
        },
        json.keys);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};
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

  ImageInfo.fromJson(Map<String, dynamic> json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _architecture = json['Architecture'];
    _author = json['Author'];
    _comment = json['Comment'];
    _config =
        new Config.fromJson(json['Config'] as Map<String, dynamic>, apiVersion);
    _container = json['Container'];
    _containerConfig = new Config.fromJson(
        json['ContainerConfig'] as Map<String, dynamic>, apiVersion);
    _created = parseDate(json['Created']);
    _dockerVersion = json['DockerVersion'];
    _id = json['Id'];
    _labels = parseLabels(json['Labels'] as Map<String, List<String>>);
    _os = json['Os'];
    // depending on the request `Parent` or `ParentId` is set.
    _parent = json['Parent'];
    _parent = json['ParentId'] != null ? json['ParentId'] : null;
    _size = json['Size'];
    _virtualSize = json['VirtualSize'];
    _repoDigests =
        toUnmodifiableListView /*<String>*/ (json['RepoDigests'] as Iterable);
    _repoTags =
        toUnmodifiableListView /*<String>*/ (json['RepoTags'] as Iterable);

    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
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
//          RemoteApiVersion.v1x18: const [
//            'Architecture',
//            'Author',
//            'Comment',
//            'Config',
//            'Container',
//            'ContainerConfig',
//            'Created',
//            'DockerVersion',
//            'Id',
//            'Labels',
//            'Os',
//            'Parent',
//            'ParentId',
//            'Size',
//            'VirtualSize',
//            'RepoDigests',
//            'RepoTags',
//          ],
          RemoteApiVersion.v1x19: const [
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
        },
        json.keys);
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

  UnmodifiableMapView<
      String,
      UnmodifiableListView<
          String>> _mountPoints; // TODO check generic type with actual data
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

  ContainerInfo.fromJson(Map<String, dynamic> json, Version apiVersion) {
    _appArmorProfile = json['AppArmorProfile'];
    _appliedVolumesFrom = json['AppliedVolumesFrom'];
    _args = toUnmodifiableListView /*<String>*/ (json['Args'] as Iterable);
    _config =
        new Config.fromJson(json['Config'] as Map<String, dynamic>, apiVersion);
    _created = parseDate(json['Created']);
    _driver = json['Driver'];
    _execDriver = json['ExecDriver'];
    _execIds = json['ExecIDs'];
    _hostConfig = new HostConfig.fromJson(
        json['HostConfig'] as Map<String, dynamic>, apiVersion);
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
    _mountPoints =
        toUnmodifiableMapView /*<String,
          UnmodifiableListView<
              String>>*/
            (json['MountPoints']
                as Map<String, List<String>>); // TODO check with actual data
    _name = json['Name'];
    _networkSettings = new NetworkSettings.fromJson(
        json['NetworkSettings'] as Map<String, dynamic>, apiVersion);
    _path = json['Path'];
    _processLabel = json['ProcessLabel'];
    _resolveConfPath = json['ResolvConfPath'];
    _restartCount = json['RestartCount'];
    _state =
        new State.fromJson(json['State'] as Map<String, dynamic>, apiVersion);
    _updateDns = json['UpdateDns'];
    _volumes = new Volumes.fromJson(
        json['Volumes'] as Map<String, dynamic>, apiVersion);
    _volumesRw = new VolumesRw.fromJson(
        json['VolumesRW'] as Map<String, dynamic>, apiVersion);

    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
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
          RemoteApiVersion.v1x18: const [
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
          RemoteApiVersion.v1x19: const [
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
        },
        json.keys);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};
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

/// See [HostConfigRequest] for documentation of the members.
class HostConfig {
  List<String> _binds;
  List<String> get binds => toUnmodifiableListView /*<String>*/ (_binds);

  int _blkioWeight;
  int get blkioWeight => _blkioWeight;

  List<String> _capAdd;
  List<String> get capAdd => toUnmodifiableListView /*<String>*/ (_capAdd);

  List<String> _capDrop;
  List<String> get capDrop => toUnmodifiableListView /*<String>*/ (_capDrop);

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
  Map<String, String> get devices =>
      toUnmodifiableMapView /*<String,String>*/ (_devices);

  List<String> _dns;
  List<String> get dns => toUnmodifiableListView /*<String>*/ (_dns);

  List<String> _dnsSearch;
  List<String> get dnsSearch =>
      toUnmodifiableListView /*<String>*/ (_dnsSearch);

  List<String> _extraHosts;
  List<String> get extraHosts =>
      toUnmodifiableListView /*<String>*/ (_extraHosts);

  String _ipcMode;
  String get ipcMode => _ipcMode;

  List<String> _links;
  List<String> get links => toUnmodifiableListView /*<String>*/ (_links);

  Map<String, String> _logConfig;
  Map<String, String> get logConfig =>
      toUnmodifiableMapView /*<String,String>*/ (_logConfig);

  Map<String, String> _lxcConf;
  Map<String, String> get lxcConf =>
      toUnmodifiableMapView /*<String,String>*/ (_lxcConf);

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
      toUnmodifiableMapView(_portBindings);

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

  List<String> _volumesFrom;
  List<String> get volumesFrom =>
      toUnmodifiableListView /*<String>*/ (_volumesFrom);

  HostConfig();

  HostConfig.fromJson(Map<String, dynamic> json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _binds = json['Binds'] as List<String>;
    _blkioWeight = json['BlkioWeight'];
    _capAdd = json['CapAdd'] as List<String>;
    _capDrop = json['CapDrop'] as List<String>;
    _cGroupParent = json['CgroupParent'];
    _containerIdFile = json['ContainerIDFile'];
    _cpuPeriod = json['CpuPeriod'];
    _cpusetCpus = json['CpusetCpus'];
    _cpusetMems = json['CpusetMems'];
    _cpuShares = json['CpuShares'];
    _devices = json['Devices'] as Map<String, String>;
    _dns = json['Dns'] as List<String>;
    _dnsSearch = json['DnsSearch'] as List<String>;
    _extraHosts = json['ExtraHosts'] as List<String>;
    _ipcMode = json['IpcMode'];
    _links = json['Links'] as List<String>;
    _logConfig = json['LogConfig'] as Map<String, String>;
    _lxcConf = json['LxcConf'] as Map<String, String>;
    _memory = json['Memory'];
    _memorySwap = json['MemorySwap'];
    _networkMode = json['NetworkMode'];
    _oomKillDisable = json['OomKillDisable'];
    _pidMode = json['PidMode'];
    final Map<String, List<Map<String, String>>> portBindings =
        json['PortBindings'] as Map<String, List<Map<String, String>>>;
    if (portBindings != null) {
      _portBindings = new Map<String, List<PortBinding>>.fromIterable(
          portBindings.keys,
          key: (String k) => k,
          value: (List<Map<String, String>> k) => portBindings[k]
              .map /*<PortBinding>*/ ((Map<String, String> pb) =>
                  new PortBinding.fromJson(pb, apiVersion))
              .toList());
    }
    _privileged = json['Privileged'];
    _publishAllPorts = json['PublishAllPorts'];
    _readonlyRootFs = json['ReadonlyRootfs'];
    _restartPolicy = new RestartPolicy.fromJson(
        json['RestartPolicy'] as Map<String, dynamic>, apiVersion);
    _securityOpt = json['SecurityOpt'];
    _ulimits = json['Ulimits'];
    _utsMode = json['UTSMode'];
    _volumesFrom = json['VolumesFrom'] as List<String>;

    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
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
          RemoteApiVersion.v1x18: const [
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
          RemoteApiVersion.v1x19: const [
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
        },
        json.keys);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};
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
        key: (String k) => k,
        value: (String k) => portBindings[k]
            .map /*<List<Map<String,dynamic>>>*/ (
                (PortBinding pb) => pb.toJson())
            .toList());
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

  NetworkSettings.fromJson(Map<String, dynamic> json, Version apiVersion) {
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
    _portMapping = toUnmodifiableMapView(json['PortMapping']);
    _ports = toUnmodifiableMapView(json['Ports']);
    _sandboxKey = json['SandboxKey'];
    _secondaryIPAddresses =
        toUnmodifiableListView(json['SecondaryIPAddresses']);
    _secondaryIPv6Addresses =
        toUnmodifiableListView(json['SecondaryIPv6Addresses']);

    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
            'Bridge',
            'Gateway',
            'IPAddress',
            'IPPrefixLen',
            'MacAddress',
            'PortMapping',
            'Ports',
          ],
          RemoteApiVersion.v1x18: const [
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
          RemoteApiVersion.v1x19: const [
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
        },
        json.keys);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};
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

  UnmodifiableListView<String> _entryPoint;
  UnmodifiableListView<String> get entryPoint => _entryPoint;

  UnmodifiableMapView<String, String> _env;
  UnmodifiableMapView<String, String> get env => _env;

  UnmodifiableMapView<String,
      UnmodifiableMapView<String, String>> _exposedPorts;
  UnmodifiableMapView<String,
      UnmodifiableMapView<String, String>> get exposedPorts => _exposedPorts;

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

  Config.fromJson(Map<String, dynamic> json, Version apiVersion) {
    if (json == null) {
      return;
    }
    _attachStderr = json['AttachStderr'];
    _attachStdin = json['AttachStdin'];
    _attachStdout = json['AttachStdout'];
    _cmd = toUnmodifiableListView /*<String>*/ (json['Cmd'] as Iterable);
    _cpuShares = json['CpuShares'];
    _cpuSet = json['Cpuset'];
    _domainName = json['Domainname'];
    _entryPoint = toUnmodifiableListView /*>String>*/ (json['Entrypoint']);
    final List<String> e = json['Env'] as List<String>;
    if (e != null) {
      _env = toUnmodifiableMapView(new Map<String, String>.fromIterable(
          e.map /*<String>*/ ((String i) => i.split('=')),
          key: (List<String> i) => i[0],
          value: (List<String> i) => i.length == 2 ? i[1] : null));
    }
    _exposedPorts = toUnmodifiableMapView /*<String,Map<String, String>>*/ (
        json['ExposedPorts'] as Map<String, Map<String, String>>);
    _hostName = json['Hostname'];
    _image = json['Image'];
    _labels = parseLabels(json['Labels'] as Map<String, List<String>>);
    _macAddress = json['MacAddress'];
    _memory = json['Memory'];
    _memorySwap = json['MemorySwap'];
    _networkDisabled = json['NetworkDisabled'];
    _onBuild =
        toUnmodifiableListView /*<String>*/ (json['OnBuild'] as Iterable);
    _openStdin = json['OpenStdin'];
    _portSpecs = json['PortSpecs'];
    _stdinOnce = json['StdinOnce'];
    _tty = json['Tty'];
    _user = json['User'];
    _volumeDriver = json['VolumeDriver'];
    _volumes = new Volumes.fromJson(
        json['Volumes'] as Map<String, dynamic>, apiVersion);
    _workingDir = json['WorkingDir'];

    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const [
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
          RemoteApiVersion.v1x18: const [
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
          RemoteApiVersion.v1x19: const [
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
        },
        json.keys);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};
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

/// The response to a [create] request.
class CreateResponse {
  Container _container;
  Container get container => _container;

  CreateResponse.fromJson(Map<String, dynamic> json, Version apiVersion) {
    if (json['Id'] != null && (json['Id'] as String).isNotEmpty) {
      _container = new Container(json['Id']);
    }
    if (json['Warnings'] != null) {
      throw json['Warnings'];
    }
    checkSurplusItems(
        apiVersion,
        {
          RemoteApiVersion.v1x15: const ['Id', 'Warnings']
        },
        json.keys);
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
  Map<String, Map<String, String>> exposedPorts =
      <String, Map<String, String>>{};

  /// Customize labels for MLS systems, such as SELinux.
  List<String> securityOpts = <String>[];
  HostConfigRequest hostConfig = new HostConfigRequest();

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};
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
        env.keys.map /*<String>*/ ((String k) => '${k}=${env[k]}').toList();
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

/// The [CreateRequest.hostConfig] part of the [create] request configuration.
class HostConfigRequest extends HostConfig {
  ///  Volume bindings for this container. Each volume binding is a string of
  ///  the form `container_path` (to create a new volume for the container),
  ///  `host_path:container_path` (to bind-mount a host path into the container),
  ///  or `host_path:container_path:ro` (to make the bind-mount read-only inside
  ///  the container).
  List<String> get binds => _binds;
  void set binds(List<String> val) {
    _binds = val;
  }

  /// Kernel capabilities to add to the container.
  List<String> get capAdd => _capAdd;
  void set capAdd(List<String> val) {
    _capAdd = val;
  }

  /// Kernel capabilities to drop from the container.
  List<String> get capDrop => _capDrop;
  void set capDrop(List<String> val) {
    _capDrop = val;
  }

  /// Path to cgroups under which the cgroup for the container will be created.
  /// If the path is not absolute, the path is considered to be relative to the
  /// cgroups path of the init process. Cgroups will be created if they do not
  /// already exist.
  String get cGroupParent => _cGroupParent;
  void set cGroupParent(String val) {
    _cGroupParent = val;
  }

  /// The CPU Shares for container (ie. the relative weight vs othercontainers).
  int get cpuShares => _cpuShares;
  void set cpuShares(int val) {
    _cpuShares = val;
  }

  /// The cgroups CpusetCpus to use.
  String get cpusetCpus => _cpusetCpus;
  void set cpusetCpus(String val) {
    _cpusetCpus = val;
  }

  /// Devices to add to the container specified in the form
  /// `{ "PathOnHost": "/dev/deviceName", "PathInContainer": "/dev/deviceName", "CgroupPermissions": "mrw"}`
  Map<String, String> get devices => _devices;
  void set devices(Map<String, String> val) {
    _devices = val;
  }

  /// A list of dns servers for the container to use.
  List<String> get dns => _dns;
  void set dns(List<String> val) {
    _dns = val;
  }

  /// A list of DNS search domains.
  List<String> get dnsSearch => _dnsSearch;
  void set dnsSearch(List<String> val) {
    _dnsSearch = val;
  }

  /// A list of hostnames/IP mappings to be added to the container's /etc/hosts
  /// file. Specified in the form `["hostname:IP"]`.
  List<String> get extraHosts => _extraHosts;
  void set extraHosts(List<String> val) {
    _extraHosts = val;
  }

  /// Links for the container. Each link entry should be of of the form
  /// "container_name:alias".
  List<String> get links => _links;
  void set links(List<String> val) {
    _links = val;
  }

  /// Logging configuration for the container in the form
  /// `{ "Type": "<driver_name>", "Config": {"key1": "val1"}}`
  /// Available types:`json-file`, `syslog`, `none`.
  Map<String, String> get logConfig => _logConfig;
  void set logConfig(Map<String, String> val) {
    _logConfig = val;
  }

  /// LXC specific configurations. These configurations will only work when
  /// using the lxc execution driver.
  Map<String, String> get lxcConf => _lxcConf;
  void set lxcConf(Map<String, String> val) {
    _lxcConf = val;
  }

  /// Memory limit in bytes.
  int get memory => _memory;
  void set memory(int val) {
    _memory = val;
  }

  /// Total memory limit (memory + swap); set -1 to disable swap, always use
  /// this with [memory], and make the value larger than [memory].
  int get memorySwap => _memorySwap;
  void set memorySwap(int val) {
    _memorySwap = val;
  }

  /// Sets the networking mode for the container. Supported values are:
  /// [NetworkMode.bridge], [NetworkMode.host], and `container:<name|id>`
  String get networkMode => _networkMode;
  void set networkMode(String val) {
    _networkMode = val;
  }

  /// Exposed container ports and the host port they should map to. It should be
  /// specified in the form `{ <port>/<protocol>: [{ "HostPort": "<port>" }] }`.
  /// Take note that port is specified as a string and not an integer value.
  Map<String, List<PortBinding>> get portBindings => _portBindings;
  void set portBindings(Map<String, List<PortBinding>> val) {
    _portBindings = val;
  }

  /// Allocates a random host port for all of a container's exposed ports.
  bool get publishAllPorts => _publishAllPorts;
  void set publishAllPorts(bool val) {
    _publishAllPorts = val;
  }

  /// Gives the container full access to the host.
  bool get privileged => _privileged;
  void set privileged(bool val) {
    _privileged = val;
  }

  ///  Mount the container's root filesystem as read only.
  bool get readonlyRootFs => _readonlyRootFs;
  void set readonlyRootFs(bool val) {
    _readonlyRootFs = val;
  }

  /// The behavior to apply when the container exits. The value is an object
  /// with a `Name` property of either `"always"` to always restart or
  /// `"on-failure"` to restart only when the container exit code is non-zero.
  /// If `on-failure` is used, `MaximumRetryCount` controls the number of times
  /// to retry before giving up. The default is not to restart. (optional) An
  /// ever increasing delay (double the previous delay, starting at 100mS) is
  /// added before each restart to prevent flooding the server.
  RestartPolicy get restartPolicy => _restartPolicy;
  void set restartPolicy(RestartPolicy val) {
    _restartPolicy = val;
  }

  /// Ulimits to be set in the container, specified as
  /// `{ "Name": <name>, "Soft": <soft limit>, "Hard": <hard limit> }`, for example:
  /// `Ulimits: { "Name": "nofile", "Soft": 1024, "Hard", 2048 }`
  Map get ulimits => _ulimits;
  void set ulimits(Map val) {
    _ulimits = val;
  }

  /// A list of volumes to inherit from another container. Specified in the
  /// form `<container name>[:<ro|rw>]`
  List<String> get volumesFrom => _volumesFrom;
  void set volumesFrom(List<String> val) {
    _volumesFrom = val;
  }
}
