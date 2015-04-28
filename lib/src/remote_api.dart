library bwu_docker.src.remote_api.dart;

import 'dart:convert' show JSON;
import 'dart:async' show Future, Stream, ByteStream;
import 'package:http/http.dart' as http;
import 'data_structures.dart';

class DockerConnection {
  final Map headers = {'Content-Type': 'application/json'};
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
    if (response.statusCode < 200 || response.statusCode >= 300) {
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

  Future<dynamic> _delete(String path, {Map<String, String> query}) async {
    final url = new Uri(
        scheme: 'http',
        host: host,
        port: port,
        path: path,
        queryParameters: query);
    final http.Response response = await client.delete(url, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw 'ERROR: ${response.statusCode} - ${response.reasonPhrase}';
    }

    if (response.body != null && response.body.isNotEmpty) {
      return JSON.decode(response.body);
    }
    return null;
  }


  /// Request the list of containers from the Docker service.
  /// [all] - Show all containers. Only running containers are shown by default
  /// (i.e., this defaults to false)
  /// [limit] - Show limit last created containers, include non-running ones.
  /// [since] - Show only containers created since Id, include non-running ones.
  /// [before] - Show only containers created before Id, include non-running
  /// ones.
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

  /// Return low-level information of [container].
  /// The passed [container] argument must have an existing id assigned.
  /// Status Codes:
  /// 200 – no error
  /// 404 – no such container
  /// 500 – server error
  Future<ContainerInfo> container(Container container) async {
    final Map response = await _get('/containers/${container.id}/json');
    print(response);
    return new ContainerInfo.fromJson(response);
  }

  /// List processes running inside the [container].
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

  /// Inspect changes on [container]'s filesystem
  /// Status Codes:
  /// 200 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<ChangesResponse> changes(Container container) async {
    final List response = await _get('/containers/${container.id}/changes');
    return new ChangesResponse.fromJson(response);
  }

  /// Export the contents of [container].
  /// Returns a tar of the container as stream.
  /// Status Codes:
  /// 200 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<http.ByteStream> export(Container container) async {
    return _getStream('/containers/${container.id}/export');
  }

  /// This endpoint returns a live stream of a [container]'s resource usage
  /// statistics.
  ///
  /// Note: this functionality currently only works when using the libcontainer
  /// exec-driver.
  ///
  /// Status Codes:
  /// 200 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<StatsResponse> stats(Container container) async {
    final Map response = await _get('/containers/${container.id}/stats');
    return new StatsResponse.fromJson(response);
  }

  /// Resize the TTY for [container].
  /// The container must be restarted for the
  /// resize to take effect.
  /// Status Codes:
  /// 200 - no error
  /// 404 - No such container
  /// 500 - Cannot resize container
  Future<SimpleResponse> resize(
      Container container, int width, int height) async {
    assert(height != null && height > 0);
    assert(width != null && width > 0);
    final query = {'h': height.toString(), 'w': width.toString()};
    final Map response =
        await _post('/containers/${container.id}/resize', query: query);
    return new SimpleResponse.fromJson(response);
  }

  /// Start the [container].
  /// Status Codes:
  /// 204 - no error
  /// 304 - container already started
  /// 404 - no such container
  /// 500 - server error
  Future<SimpleResponse> start(Container container) async {
    final Map response = await _post('/containers/${container.id}/start');
    return new SimpleResponse.fromJson(response);
  }

  /// Stop the [container].
  /// [timeout] – number of seconds to wait before killing the container
  /// Status Codes:
  /// 204 - no error
  /// 304 - container already stopped
  /// 404 - no such container
  /// 500 - server error
  Future<SimpleResponse> stop(Container container, {int timeout}) async {
    assert(timeout == null || timeout > 0);
    final query = {'t': timeout.toString()};
    final Map response =
        await _post('/containers/${container.id}/stop', query: query);
    return new SimpleResponse.fromJson(response);
  }

  /// Restart the [container].
  /// [timeout] – number of seconds to wait before killing the container
  /// Status Codes:
  /// 204 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<SimpleResponse> restart(Container container, {int timeout}) async {
    assert(timeout == null || timeout > 0);
    final query = {'t': timeout.toString()};
    final Map response =
        await _post('/containers/${container.id}/restart', query: query);
    return new SimpleResponse.fromJson(response);
  }

  /// Kill the [container].
  /// [signal] - Signal to send to the container: integer or string like
  /// "SIGINT". When not set, SIGKILL is assumed and the call will wait for the
  /// container to exit.
  /// Status Codes:
  /// 204 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<SimpleResponse> kill(Container container, dynamic signal) async {
    assert(signal == null ||
        (signal is String && signal.isNotEmpty) ||
        (signal is int));
    final query = {'signal': signal.toString()};
    final Map response =
        await _post('/containers/${container.id}/kill', query: query);
    return new SimpleResponse.fromJson(response);
  }

  /// Rename the [container] to [name].
  /// [name] - new name for the container
  /// Status Codes:
  /// 204 - no error
  /// 404 - no such container
  /// 409 - conflict name already assigned
  /// 500 - server error
  Future<SimpleResponse> rename(Container container, String name) async {
    assert(name != null);
    final query = {'name': name.toString()};
    final Map response =
        await _post('/containers/${container.id}/rename', query: query);
    return new SimpleResponse.fromJson(response);
  }

  /// Pause the [container].
  /// Status Codes:
  /// 204 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<SimpleResponse> pause(Container container) async {
    final Map response = await _post('/containers/${container.id}/pause');
    return new SimpleResponse.fromJson(response);
  }

  /// Unpause the [container].
  /// Status Codes:
  /// 204 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<SimpleResponse> unpause(Container container) async {
    final Map response = await _post('/containers/${container.id}/unpause');
    return new SimpleResponse.fromJson(response);
  }

  /// Attach to the [container].
  /// [logs] - Return logs. Default [:false:]
  /// [stream] - Return stream. Default [:false:]
  /// [stdin] - if stream=true, attach to stdin. Default [:false:]
  /// [stdout] - if logs==true, return stdout log, if stream==true, attach to
  ///     stdout. Default [:false:]
  /// [stderr] - if logs==true, return stderr log, if stream==true, attach to
  ///     stderr. Default [:false:]
  /// Status Codes:
  /// 101 – no error, hints proxy about hijacking
  /// 200 – no error, no upgrade header found
  /// 400 – bad parameter
  /// 404 – no such container
  /// 500 – server error
  ///
  /// Stream details:
  ///
  /// When using the TTY setting is enabled in POST /containers/create , the
  /// stream is the raw data from the process PTY and client's stdin. When the
  /// TTY is disabled, then the stream is multiplexed to separate stdout and
  /// stderr.
  ///
  /// The format is a Header and a Payload (frame).
  ///
  /// HEADER
  ///
  /// The header will contain the information on which stream write the stream
  /// (stdout or stderr). It also contain the size of the associated frame
  /// encoded on the last 4 bytes (uint32).
  ///
  /// It is encoded on the first 8 bytes like this:
  ///
  /// header := [8]byte{STREAM_TYPE, 0, 0, 0, SIZE1, SIZE2, SIZE3, SIZE4}
  /// STREAM_TYPE can be:
  ///
  /// 0: stdin (will be written on stdout)
  ///
  /// 1: stdout
  /// 2: stderr
  ///
  /// SIZE1, SIZE2, SIZE3, SIZE4 are the 4 bytes of the uint32 size encoded as
  /// big endian.
  ///
  /// PAYLOAD
  ///
  /// The payload is the raw stream.
  ///
  /// IMPLEMENTATION
  ///
  /// The simplest way to implement the Attach protocol is the following:
  ///
  /// Read 8 bytes
  /// chose stdout or stderr depending on the first byte
  /// Extract the frame size from the last 4 bytes
  /// Read the extracted size and output it on the correct output
  /// Goto 1
  // TODO(zoechi) return an instance of a class which provides access to the
  // stdout/stderr as separate streams
  Future<http.ByteStream> attach(Container container,
      {bool logs, bool stream, bool stdin, bool stdout, bool stderr}) async {
    final query = {};
    if (logs != null) query['logs'] = logs.toString();
    if (stream != null) query['stream'] = stream.toString();
    if (stdin != null) query['stdin'] = stdin.toString();
    if (stdout != null) query['stdout'] = stdout.toString();
    if (stderr != null) query['stderr'] = stderr.toString();

    return _getStream('/containers/${container.id}/attach', query: query);
  }

  /// Attach to the [container] via websocket
  /// [logs] - Return logs. Default [:false:]
  /// [stream] - Return stream. Default [:false:]
  /// [stdin] - if stream=true, attach to stdin. Default [:false:]
  /// [stdout] - if logs==true, return stdout log, if stream==true, attach to
  ///     stdout. Default [:false:]
  /// [stderr] - if logs==true, return stderr log, if stream==true, attach to
  ///     stderr. Default [:false:]
  /// Status Codes:
  /// 200 - no error
  /// 400 - bad parameter
  /// 404 - no such container
  /// 500 - server error
  // TODO(zoechi) implement
  Future<http.ByteStream> attachWs(Container container,
      {bool logs, bool stream, bool stdin, bool stdout, bool stderr}) async {
    final query = {};
    if (logs != null) query['logs'] = logs.toString();
    if (stream != null) query['stream'] = stream.toString();
    if (stdin != null) query['stdin'] = stdin.toString();
    if (stdout != null) query['stdout'] = stdout.toString();
    if (stderr != null) query['stderr'] = stderr.toString();

    throw 'AttachWs is not yet implemented';
    //return http. _getStream('/containers/${container.id}/attach', query: query);
  }

  /// Block until [container] stops, then returns the exit code.
  /// Status Codes:
  /// 200 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<WaitResponse> wait(Container container) async {
    final Map response = await _post('/containers/${container.id}/wait');
    return new WaitResponse.fromJson(response);
  }

  /// Remove the [container] from the filesystem.
  /// [removeVolumes] - Remove the volumes associated to the [container].
  /// Default false
  /// [force] - 1/True/true or 0/False/false, Kill then remove the container.
  /// Default false
  /// Status Codes:
  /// 204 – no error
  /// 400 – bad parameter
  /// 404 – no such container
  /// 500 – server error
  Future<SimpleResponse> remove(Container container, {bool removeVolumes, bool force}) async {
    final query = {};
    if (removeVolumes != null) query['v'] = removeVolumes.toString();
    if (force != null) query['force'] = force.toString();

    final Map response = await _delete('/containers/${container.id}');
    return new SimpleResponse.fromJson(response);
  }

}


