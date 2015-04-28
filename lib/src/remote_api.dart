library bwu_docker.src.remote_api.dart;

import 'dart:convert' show JSON;
import 'dart:async' show Future, Stream, ByteStream;
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

  /// Send a POST request to the Docker service.
  Future<Map> _post(String path, {Map json, Map query}) async {
    String data;
    if (json != null) {
      data = JSON.encode(json);
    }
    final url = new Uri(
        scheme: 'http',
        host: host,
        port: port,
        path: path,
        queryParameters: query);

    final http.Response response =
        await client.post(url, headers: headers, body: data);
    if (response.statusCode < 200 && response.statusCode >= 300) {
      throw 'ERROR: ${response.statusCode} - ${response.reasonPhrase}';
    }
    if (response.body != null && response.body.isNotEmpty) {
      return JSON.decode(response.body);
    }
    return null;
  }

  /// Post request expecting a streamed response.
  Future<Stream> _postStream(String path,
      {Map json, Map<String, String> query}) async {
    String data;
    if (json != null) {
      data = JSON.encode(json);
    }
    final url = new Uri(
        scheme: 'http',
        host: host,
        port: port,
        path: path,
        queryParameters: query);
    final request = new http.Request('GET', url)
      ..body = data
      ..headers.addAll(headers);
    final http.StreamedResponse response =
        await request.send().then(http.Response.fromStream);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw 'ERROR: ${response.statusCode} - ${response.reasonPhrase}';
    }
    return response.stream;
  }

  Future<dynamic> _get(String path, {Map<String, String> query}) async {
    final url = new Uri(
        scheme: 'http',
        host: host,
        port: port,
        path: path,
        queryParameters: query);
    final http.Response response = await client.get(url, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw 'ERROR: ${response.statusCode} - ${response.reasonPhrase}';
    }

    if (response.body != null && response.body.isNotEmpty) {
      return JSON.decode(response.body);
    }
    return null;
  }

  /// Get request expecting a streamed response.
  Future<http.ByteStream> _getStream(String path,
      {Map<String, String> query}) async {
    final url = new Uri(
        scheme: 'http',
        host: host,
        port: port,
        path: path,
        queryParameters: query);
    final request = new http.Request('GET', url);
    request.headers.addAll(headers);
    final http.StreamedResponse response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw 'ERROR: ${response.statusCode} - ${response.reasonPhrase}';
    }
    return response.stream;
  }

  /// Request the list of containers from the Docker service.
  /// [all] - Show all containers. Only running containers are shown by default (i.e., this defaults to false)
  /// [limit] - Show limit last created containers, include non-running ones.
  /// [since] - Show only containers created since Id, include non-running ones.
  /// [before] - Show only containers created before Id, include non-running ones.
  /// [size] - Show the containers sizes
  /// [filters] - filters to process on the containers list. Available filters:
  ///  `exited`=<[int]> - containers with exit code of <int>
  ///  `status`=[ContainerStatus]
  ///  Status Codes:
  /// 200 – no error
  /// 400 – bad parameter
  /// 500 – server error
  Future<Iterable<Container>> containers({bool all, int limit, String since,
      String before, bool size, Map<String, List> filters}) async {
    Map<String, String> query = {};
    if (all != null) query['all'] = all.toString();
    if (limit != null) query['limit'] = limit.toString();
    if (since != null) query['since'] = since;
    if (before != null) query['before'] = before;
    if (size != null) query['size'] = size.toString();
    if (filters != null) query['filters'] = JSON.encode(filters);

    final List response = await _get('/containers/json', query: query);
    return response.map((e) => new Container.fromJson(e));
  }

  /// Create a container from a container configuration.
  /// [name] - Assign the specified name to the container.
  /// Status Codes:
  /// 201 – no error
  /// 404 – no such container
  /// 406 – impossible to attach (container not running)
  /// 500 – server error
  Future<CreateResponse> create(CreateContainerRequest request,
      {String name}) async {
    Map query;
    if (name != null) {
      assert(containerNameRegex.hasMatch(name));
      query = {'name': name};
    }
    final Map response =
        await _post('/containers/create', json: request.toJson(), query: query);
    return new CreateResponse.fromJson(response);
  }

  Future<SimpleResponse> start(Container container) async {
    final Map response = await _post('/containers/${container.id}/start');
    return new SimpleResponse.fromJson(response);
  }

  /// Return low-level information on the container [container].
  /// The passed [container] argument must have an existing id assigned.
  /// Status Codes:
  /// 200 – no error
  /// 404 – no such container
  /// 500 – server error
  Future<ContainerInfo> container(Container container) async {
    final Map response = await _get('/containers/${container.id}/json');
    return new ContainerInfo.fromJson(response);
  }

  /// List processes running inside the container.
  /// [psArgs] – `ps` arguments to use (e.g., `aux`)
  /// Status Codes:
  /// 200 – no error
  /// 404 – no such container
  /// 500 – server error
  Future<TopResponse> top(Container container, {String psArgs}) async {
    Map query;
    if (psArgs != null) {
      query = {'ps_args': psArgs};
    }

    final Map response =
        await _get('/containers/${container.id}/top', query: query);
    return new TopResponse.fromJson(response);
  }

  /// Get stdout and stderr logs from [container].
  ///
  /// Note: This endpoint works only for containers with `json-file` logging
  /// driver.
  /// [follow] - Return stream. Default [:false:]
  /// [stdout] - Show stdout log. Default [:false:]
  /// [stderr] - Show stderr log. Default [:false:]
  /// [timestamps] - Print timestamps for every log line. Default [:false:]
  /// [tail] - Output specified number of lines at the end of logs: all or
  /// <number>. Default all
  /// Status Codes:
  ///
  /// 101 – no error, hints proxy about hijacking
  /// 200 – no error, no upgrade header found
  /// 404 – no such container
  /// 500 – server error
  Future<Stream> logs(Container container, {bool follow, bool stdout,
      bool stderr, bool timestamps, dynamic tail}) async {
    assert(stdout == true || stderr == true);
    final query = {};
    if (follow != null) query['follow'] = follow.toString();
    if (stdout != null) query['stdout'] = stdout.toString();
    if (stderr != null) query['stderr'] = stderr.toString();
    if (timestamps != null) query['timestamps'] = timestamps.toString();
    if (tail != null) {
      assert(tail == 'all' || tail is int);
      query['tail'] = tail.toString();
    }

    return _getStream('/containers/${container.id}/logs', query: query);
  }

  /// Inspect changes on container id's filesystem
  /// Status Codes:
  /// 200 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<ChangesResponse> changes(Container container) async {
    final List response = await _get('/containers/${container.id}/changes');
    return new ChangesResponse.fromJson(response);
  }

  /// Export a container
  /// Status Codes:
  /// 200 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<http.ByteStream> export(Container container) async {
    return _getStream('/containers/${container.id}/export');
  }
}
