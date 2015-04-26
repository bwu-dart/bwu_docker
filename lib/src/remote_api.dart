library bwu_docker.src.remote_api.dart;

import 'dart:convert' show JSON;
import 'dart:async' show Future, Stream;
import 'package:http/http.dart' as http;
import 'data_structures.dart';

class DockerConnection {
  static const headers = const {'Content-Type': 'application/json'};
  final String host;
  final int port;
  http.Client client;
  DockerConnection(this.host, this.port) {
    client = new http.Client();
  }

  Future<List<Container>> ps() async {
    final http.Response resp =
        await client.get(Uri.parse('http://localhost:2375/containers/json'));
    print(resp.body);
    //print('data: ${new String.fromCharCodes(resp.expand((e) => e).toList())}');
  }

  Future<CreateResponse> create(CreateContainerRequest request) async {
    final http.Response resp =
        await client.post(Uri.parse('http://localhost:2375/containers/create'), headers: headers, body: JSON.encode(request));
    return new CreateResponse.fromJson(JSON.decode(resp.body));
  }

  Future<SimpleResponse> start(Container container) async {
    final http.Response resp =
        await client.post(Uri.parse('http://localhost:2375/containers/${container.id}/start'), headers: headers);
    return new SimpleResponse.fromJson(resp.body.length == 0 ? null : JSON.decode(resp.body));
  }
}

class SimpleResponse {
  SimpleResponse.fromJson(Map json) {
    if(json != null && json.keys.length > 0) {
      throw json;
    }
  }
}

class CreateResponse {
  Container _container;
  Container get container => _container;

  CreateResponse.fromJson(Map json) {
    if(json['Id'] != null && (json['Id'] as String).isNotEmpty) {
      _container = new Container.fromJson(json);
    }
    if(json['Warnings'] != null) {
      throw json['Warnings'];
    }
  }
}
class Container {
  final String id;
  Container(this.id);

  factory Container.fromJson(Map json) {
    final id = json['Id'];
    assert(json.keys.length <= 2);
    return new Container(id);
  }
}

class CreateContainerRequest {
  String hostName = '';
  String domainName = '';
  String user = '';
  bool attachStdin = false;
  bool attachStdout = true;
  bool attachStderr = true;
  bool tty = false;
  bool openStdin = false;
  bool stdinOnce = false;
  Map<String, String> env;
  List<String> cmd = [];
  String entryPoint = '';
  String image = '';
  List<String> labels = <String>[];
  Volumes volumes;
  String workingDir = '';
  bool networkDisabled = false;
  String macAddress = '';
  Map<String, Map<String, String>> exposedPorts = <String, Map<String, String>>{
  };
  List<String> securityOpts = [""];
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
    json['HostConfig'] = hostConfig != null ? hostConfig.toJson(): null;
    return json;
  }
}

class HostConfigRequest {
  List<String> binds = ['/tmp:/tmp'];
  List<String> links = [];
  Map<String, String> lxcConf = {"lxc.utsname": "docker"};
  int memory = 0;
  int memorySwap = 0;
  int cpuShares = 512;
  String cpusetCpus = "0,1";
  Map<String, Map<String, String>> portBindings = {
    "22/tcp": [{"HostPort": "11022"}]
  };
  bool publishAllPorts = false;
  bool privileged = false;
  bool readonlyRootFs = false;
  List<String> dns = ["8.8.8.8"];
  List<String> dnsSearch = [""];
  List<String> extraHosts = null;
  List<String> volumesFrom = [];
  List<String> capAdd = ["NET_ADMIN"];
  List<String> capDrop = ["MKNOD"];
  Map restartPolicy = {"Name": "", "MaximumRetryCount": 0};
  String networkMode = "bridge";
  List<String> devices = [];
  List<Map<String, int>> uLimits = [{}];
  Map<String, Config> logConfig = {"Type": "json-file" /*, Config: {}*/};
  String cGroupParent = '';

  Map toJson() {
    final json = {};
    json['Binds'] = binds;
    json['Links'] = links;
    json['LxcConf'] = lxcConf;
    json['Memory'] = memory;
    json['MemorySwap'] = memorySwap;
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
