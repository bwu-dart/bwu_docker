library bwu_docker.src.v1x20.remote_api;

import 'dart:async' show Future, Stream, Completer, StreamController;
import 'dart:convert' show JSON, UTF8;
import 'package:crypto/crypto.dart' show CryptoUtils;
import 'package:http/http.dart' as http;

import 'package:bwu_docker/src/shared/remote_api.dart';
import 'package:bwu_docker/src/shared/exception.dart';

import 'data_structures.dart';
export 'package:bwu_docker/src/shared/remote_api.dart';
export 'package:bwu_docker/src/shared/exception.dart';


/// The primary API class to initialize a connection to a Docker hosts remote
/// API and send any number of commands to this Docker service.
class DockerConnection {
  final Map<String, String> headersJson = <String, String>{
    'Content-Type': 'application/json'
  };
  final Map<String, String> headersTar = <String, String>{
    'Content-Type': 'application/tar'
  };

  VersionResponse _dockerVersion;
  VersionResponse get dockerVersion => _dockerVersion;

  /// The most recent version supported by the Docker server.
  /// If a remote API version was specified when the [DockerConnection] was
  /// created, it can be read from [serverReference.remoteApiVersion] instead.
  /// [remoteApiVersion] returns an invalid version until initialized by [init].
  RemoteApiVersion _remoteApiVersion;
  RemoteApiVersion get remoteApiVersion {
    if (_remoteApiVersion == null) {
      return new RemoteApiVersion(0, 0, 0);
    }
    return _remoteApiVersion;
  }

  /// Loads the version information from the Docker service.
  /// The version information is used to adapt to differences in the Docker
  /// remote API between different Docker version.
  /// If [init] isn't called no version specific handling can be done.
  Future init() async {
    if (_dockerVersion == null) {
      _dockerVersion = await version();
      _remoteApiVersion =
          new RemoteApiVersion.fromVersion(dockerVersion.apiVersion);
    }
  }

  ServerReference _serverReference;
  ServerReference get serverReference => _serverReference;

  /// Create a [DockerConnection] which uses a specific remote API endpoint
  /// version (the version is added to the request URI).
  /// Without a specified version the most recent version supported
  /// by the Docker service is used (the version part is omitted in the request
  /// URI).
  DockerConnection.useRemoteApiVersion(
      Uri uri, RemoteApiVersion remoteApiVersion, http.Client client) {
    assert(uri != null);
    assert(client != null);
//    print('Uri: ${uri}');
    _serverReference =
        new ServerReference(uri, client, remoteApiVersion: remoteApiVersion);
  }

  /// Create a [DockerConnection] which uses the most recent remote API version
  /// supported by the server (the version part is omitted in the request URI).
  DockerConnection(Uri uri, http.Client client)
      : this.useRemoteApiVersion(uri, null, client);

  String _jsonifyConcatenatedJson(String s) {
    return '[${s.replaceAll(new RegExp(r'\}\s*\{', multiLine: true), '},\n{')}]';
  }

  Future /*<T>*/ _request /*<T>*/ (RequestType requestType, String path,
      {Map<String, dynamic> body,
      Map<String, String> query,
      Map<String, String> headers,
      ResponsePreprocessor preprocessor}) async {
    assert(requestType != null);
    assert(requestType == RequestType.post || body == null);
    String data;
    if (body != null) {
      data = JSON.encode(body);
    }
    Map<String, String> _headers = headers != null ? headers : headersJson;

    final Uri url = serverReference.buildUri(path, query);
//    print('Uri: ${url}, ${requestType}');

    http.Response response;
    switch (requestType) {
      case RequestType.post:
        response = await serverReference.client
            .post(url, headers: _headers, body: data);
        break;
      case RequestType.get:
        response = await serverReference.client.get(url, headers: _headers);
        break;
      case RequestType.delete:
        response = await serverReference.client.delete(url, headers: _headers);
        break;
      default:
        throw '"${requestType}" not implemented.';
    }

    if ((response.statusCode < 200 || response.statusCode >= 300) &&
        response.statusCode != 304) {
      throw new DockerRemoteApiError(
          response.statusCode, response.reasonPhrase, response.body,
          message: 'Request failed: ${requestType} ${url}');
    }
    if (response.body != null && response.body.isNotEmpty) {
      String data = response.body;
      if (preprocessor != null) {
        data = preprocessor(response.body);
      }
      try {
        return JSON.decode(data) as dynamic /*=T*/;
      } catch (e) {
        print(data);
      }
    }
    return null;
  }

  /// Post request expecting a streamed response.
  Future<Stream<List<int>>> _requestStream(RequestType requestType, String path,
      {Map<String, dynamic> body,
      Map<String, String> query,
      Map<String, String> headers}) async {
    assert(requestType != null);
    assert(requestType == RequestType.post || body == null);

    String data;
    if (body != null) {
      data = JSON.encode(body);
    }
    final Uri url = serverReference.buildUri(path, query);

    final http.Request request = new http.Request(requestType.toString(), url)
      ..headers.addAll(headers != null ? headers : headersJson);
    if (data != null) {
      request.body = data;
    }
    final http.BaseResponse response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new DockerRemoteApiError(
          response.statusCode, response.reasonPhrase, null);
    }
    return (response as http.StreamedResponse).stream;
  }

  /// Send a POST request to the Docker service.
  Future<http.ByteStream> _streamRequestStream(
      String path, Stream<List<int>> stream,
      {Map<String, String> query}) async {
    assert(stream != null);

    final Uri url = serverReference.buildUri(path, query);

    final http.StreamedRequest request = new http.StreamedRequest('POST', url)
      ..headers.addAll(headersTar);
    stream.listen(request.sink.add);
    final http.BaseResponse response =
        await request.send().then(http.Response.fromStream);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new DockerRemoteApiError(
          response.statusCode, response.reasonPhrase, null);
    }
    return (response as http.StreamedResponse).stream;
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
  Future<Iterable<Container>> containers(
      {bool all,
      int limit,
      String since,
      String before,
      bool size,
      Map<String, List> filters}) async {
    Map<String, String> query = <String, String>{};
    if (all != null) query['all'] = all.toString();
    if (limit != null) query['limit'] = limit.toString();
    if (since != null) query['since'] = since;
    if (before != null) query['before'] = before;
    if (size != null) query['size'] = size.toString();
    if (filters != null) query['filters'] = JSON.encode(filters);

    final List<Map<String, dynamic>> response =
        await _request /*<List<Map<String,dynamic>>>*/ (
            RequestType.get, '/containers/json',
            query: query);
//    print(response);
    return response.map /*<Iterable<Container>>*/ ((Map<String, dynamic> e) =>
        new Container.fromJson(e, remoteApiVersion));
  }

  /// Create a container from a container configuration.
  /// [name] - Assign the specified name to the container.
  /// Status Codes:
  /// 201 – no error
  /// 404 – no such container
  /// 406 – impossible to attach (container not running)
  /// 500 – server error
  Future<CreateResponse> createContainer(CreateContainerRequest request,
      {String name}) async {
    assert(request != null);
    Map<String, String> query;
    if (name != null) {
      assert(containerNameRegex.hasMatch(name));
      query = <String, String>{'name': name};
    }
    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.post, '/containers/create',
            body: request.toJson(), query: query);
//    print(response);
    return new CreateResponse.fromJson(response, remoteApiVersion);
  }

  /// Return low-level information of [container].
  /// The passed [container] argument must have an existing id assigned.
  /// Status Codes:
  /// 200 – no error
  /// 404 – no such container
  /// 500 – server error
  Future<ContainerInfo> container(Container container) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.get, '/containers/${container.id}/json');
//    print(response);
    return new ContainerInfo.fromJson(response, remoteApiVersion);
  }

  /// List processes running inside the [container].
  /// [psArgs] – `ps` arguments to use (e.g., `aux`)
  /// Status Codes:
  /// 200 – no error
  /// 404 – no such container
  /// 500 – server error
  Future<TopResponse> top(Container container, {String psArgs}) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    Map<String, dynamic> query;
    if (psArgs != null) {
      query = <String, dynamic>{'ps_args': psArgs};
    }

    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.get, '/containers/${container.id}/top',
            query: query);
    return new TopResponse.fromJson(response, remoteApiVersion);
  }

  /// Get stdout and stderr logs from [container].
  ///
  /// Note: This endpoint works only for containers with `json-file` logging
  /// driver.
  /// [follow] - Return stream. Default [:false:]
  /// [stdout] - Show stdout log. Default [:false:]
  /// [stderr] - Show stderr log. Default [:false:]
  /// [since] - Specifying a timestamp will only output log-entries since that
  ///   timestamp. Default: unfiltered
  /// [timestamps] - Print timestamps for every log line. Default [:false:]
  /// [tail] - Output specified number of lines at the end of logs: all or
  /// <number>. Default all
  /// Status Codes:
  ///
  /// 101 – no error, hints proxy about hijacking
  /// 200 – no error, no upgrade header found
  /// 404 – no such container
  /// 500 – server error
  Future<Stream> logs(Container container,
      {bool follow,
      bool stdout,
      bool stderr,
      DateTime since,
      bool timestamps,
      Object tail}) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    assert(stdout == true || stderr == true);
    final Map<String, String> query = <String, String>{};
    if (follow != null) query['follow'] = follow.toString();
    if (stdout != null) query['stdout'] = stdout.toString();
    if (stderr != null) query['stderr'] = stderr.toString();
    if (since != null) query['since'] =
        (since.toUtc().millisecondsSinceEpoch ~/ 1000).toString();
    if (timestamps != null) query['timestamps'] = timestamps.toString();
    if (tail != null) {
      assert(tail == 'all' || tail is int);
      query['tail'] = tail.toString();
    }

    return _requestStream(RequestType.get, '/containers/${container.id}/logs',
        query: query);
  }

  /// Inspect changes on [container]'s filesystem
  /// Status Codes:
  /// 200 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<ChangesResponse> changes(Container container) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    final List response =
        await _request(RequestType.get, '/containers/${container.id}/changes');
    return new ChangesResponse.fromJson(response);
  }

  /// Export the contents of [container].
  /// Returns a tar of the container as stream.
  /// Status Codes:
  /// 200 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<Stream<List<int>>> export(Container container) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    return _requestStream(
        RequestType.get, '/containers/${container.id}/export');
  }

  /// This endpoint returns a live stream of a [container]'s resource usage
  /// statistics.
  ///
  /// [stream] - If `false` pull stats once then disconnect. Default [:true:]
  ///
  /// Note: this functionality currently only works when using the libcontainer
  /// exec-driver.
  ///
  /// Status Codes:
  /// 200 - no error
  /// 404 - no such container
  /// 500 - server error
  Stream<StatsResponse> stats(Container container, {bool stream: true}) async* {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    assert(stream != null);
    final Map<String, String> query = <String, String>{};
    if (!stream) query['stream'] = stream.toString();

    final Stream<List<int>> responseStream = await _requestStream(
        RequestType.get, '/containers/${container.id}/stats',
        query: query);
    await for (List<int> v in responseStream) {
      yield new StatsResponse.fromJson(
          JSON.decode(UTF8.decode(v)) as Map<String, dynamic>,
          remoteApiVersion);
    }
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
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    assert(height != null && height > 0);
    assert(width != null && width > 0);
    final Map<String, String> query = <String, String>{
      'h': height.toString(),
      'w': width.toString()
    };
    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.post, '/containers/${container.id}/resize',
            query: query);
    return new SimpleResponse.fromJson(response, remoteApiVersion);
  }

  /// Start the [container].
  /// Status Codes:
  /// 204 - no error
  /// 304 - container already started
  /// 404 - no such container
  /// 500 - server error
  // TODO(zoechi) find out which options can be sent in the body
  Future<SimpleResponse> start(Container container,
      {HostConfigRequest hostConfig}) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    final Map<String, dynamic> body =
        hostConfig == null ? null : hostConfig.toJson();
    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.post, '/containers/${container.id}/start',
            body: body);
    return new SimpleResponse.fromJson(response, remoteApiVersion);
  }

  /// Stop the [container].
  /// [timeout] – number of seconds to wait before killing the container
  /// Status Codes:
  /// 204 - no error
  /// 304 - container already stopped
  /// 404 - no such container
  /// 500 - server error
  Future<SimpleResponse> stop(Container container, {int timeout}) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    assert(timeout == null || timeout > 0);
    final Map<String, String> query = <String, String>{'t': timeout.toString()};
    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.post, '/containers/${container.id}/stop',
            query: query);
//    print(response);
    return new SimpleResponse.fromJson(response, remoteApiVersion);
  }

  /// Restart the [container].
  /// [timeout] – number of seconds to wait before killing the container
  /// Status Codes:
  /// 204 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<SimpleResponse> restart(Container container, {int timeout}) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    assert(timeout == null || timeout > 0);
    final Map<String, String> query = <String, String>{'t': timeout.toString()};
    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.post, '/containers/${container.id}/restart',
            query: query);
    return new SimpleResponse.fromJson(response, remoteApiVersion);
  }

  /// Kill the [container].
  /// [signal] - Signal to send to the container: integer or string like
  /// "SIGINT". When not set, SIGKILL is assumed and the call will wait for the
  /// container to exit.
  /// Status Codes:
  /// 204 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<SimpleResponse> kill(Container container, {Object signal}) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    assert(signal == null ||
        (signal is String && signal.isNotEmpty) ||
        (signal is int));
    final Map<String, String> query = <String, String>{
      'signal': signal.toString()
    };
    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.post, '/containers/${container.id}/kill',
            query: query);
    return new SimpleResponse.fromJson(response, remoteApiVersion);
  }

  /// Rename the [container] to [name].
  /// [name] - new name for the container
  /// Status Codes:
  /// 204 - no error
  /// 404 - no such container
  /// 409 - conflict name already assigned
  /// 500 - server error
  Future<SimpleResponse> rename(Container container, String name) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    assert(name != null);
    final Map<String, String> query = <String, String>{'name': name.toString()};
    final Map response = await _request /*<Map<String,dynamic>>*/ (
        RequestType.post, '/containers/${container.id}/rename',
        query: query);
    return new SimpleResponse.fromJson(response, remoteApiVersion);
  }

  /// Pause the [container].
  /// Status Codes:
  /// 204 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<SimpleResponse> pause(Container container) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.post, '/containers/${container.id}/pause');
    return new SimpleResponse.fromJson(response, remoteApiVersion);
  }

  /// Unpause the [container].
  /// Status Codes:
  /// 204 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<SimpleResponse> unpause(Container container) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.post, '/containers/${container.id}/unpause');
    return new SimpleResponse.fromJson(response, remoteApiVersion);
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
  Future<DeMux> attach(Container container,
      {bool logs, bool stream, bool stdin, bool stdout, bool stderr}) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    final Map<String, String> query = <String, String>{};
    if (logs != null) query['logs'] = logs.toString();
    if (stream != null) query['stream'] = stream.toString();
    if (stdin != null) query['stdin'] = stdin.toString();
    if (stdout != null) query['stdout'] = stdout.toString();
    if (stderr != null) query['stderr'] = stderr.toString();

    final Stream<List<int>> streamResponse = await _requestStream(
        RequestType.post, '/containers/${container.id}/attach',
        query: query);
    return new DeMux(streamResponse);
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
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    final Map<String, String> query = <String, String>{};
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
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.post, '/containers/${container.id}/wait');
    return new WaitResponse.fromJson(response, remoteApiVersion);
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
  /// It seems the container must be stopped before it can be removed.
  Future<SimpleResponse> removeContainer(Container container,
      {bool removeVolumes, bool force}) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    final Map<String, String> query = <String, String>{};
    if (removeVolumes != null) query['v'] = removeVolumes.toString();
    if (force != null) query['force'] = force.toString();

    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.delete, '/containers/${container.id}');
    return new SimpleResponse.fromJson(response, remoteApiVersion);
  }

  /// Copy files or folders of [container].
  /// Status Codes:
  /// 200 - no error
  /// 404 - no such container
  /// 500 - server error
  // TODO(zoechi) figure out whether it's possible to request more than one file
  // or directory with one request.
  /// [resource] is the path of a file or directory;
  Future<Stream<List<int>>> copy(Container container, String resource) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    final Map<String, dynamic> json = new CopyRequestPath(resource).toJson();
    return _requestStream /*<Map<String,dynamic>>*/ (
        RequestType.post, '/containers/${container.id}/copy',
        body: json);
  }

  /// List images.
  /// The response shows a single image `Id` associated with two repositories
  /// (`RepoTags`): `localhost:5000/test/busybox`: and `playdate`. A caller can
  /// use either of the `RepoTags` values `localhost:5000/test/busybox:latest`
  /// or `playdate:latest` to reference the image.
  ///
  /// You can also use `RepoDigests` values to reference an image. In this
  /// response, the array has only one reference and that is to the
  /// `localhost:5000/test/busybox` repository; the `playdate` repository has no
  /// digest. You can reference this digest using the value:
  /// `localhost:5000/test/busybox@sha256:cbbf2f9a99b47fc460d...`
  ///
  /// See the `docker run` and `docker build` commands for examples of digest
  /// and tag references on the command line.
  ///
  /// Query Parameters:
  ///
  /// [all] - Show all images (by default filter out the intermediate image
  ///     layers). The default is false.
  /// [filters] - a json encoded value of the filters (a map[string][]string) to
  ///     process on the images list. Available filters: dangling=true
  Future<Iterable<ImageInfo>> images(
      {bool all, Map<String, List> filters}) async {
    Map<String, String> query = {};
    if (all != null) query['all'] = all.toString();
    if (filters != null) query['filters'] = JSON.encode(filters);

    final List<Map<String, dynamic>> response =
        await _request /*<List<Map<String,dynamic>>>*/ (
            RequestType.get, '/images/json',
            query: query);
    return response.map /*<ImageInfo>*/ ((Map<String, dynamic> e) =>
        new ImageInfo.fromJson(e, remoteApiVersion));
  }

  /// Build an image from a Dockerfile.
  /// The input stream must be a tar archive compressed with one of the
  /// following algorithms: identity (no compression), gzip, bzip2, xz.
  ///
  /// The archive must include a build instructions file, typically called
  /// `Dockerfile` at the root of the archive. The [dockerfile] parameter may be
  /// used to specify a different build instructions file by having its value be
  /// the path to the alternate build instructions file to use.
  ///
  /// The archive may include any number of other files, which will be
  /// accessible in the build context (See the
  /// [ADD build command](https://docs.docker.com/reference/builder/#dockerbuilder)).
  ///
  /// The build will also be canceled if the client drops the connection by
  /// quitting or being killed.
  ///
  /// Query Parameters:
  ///
  /// [dockerfile] Path within the build context to the Dockerfile. This is
  ///     ignored if [remote] is specified and points to an individual filename.
  /// [t] repository name (and optionally a tag) to be applied to the resulting
  ///     image in case of success
  /// [remote] A Git repository URI or HTTP/HTTPS URI build source. If the URI
  ///     specifies a filename, the file's contents are placed into a file
  ///     called `Dockerfile`.
  /// [q] Suppress verbose build output
  /// [noCache] Do not use the cache when building the image
  /// [pull] Attempt to pull the image even if an older image exists locally
  /// [rm] Remove intermediate containers after a successful build (default
  /// behavior)
  /// [forceRm] Always remove intermediate containers (includes rm)
  /// [memory] Set memory limit for build
  /// [memSwap] Total memory (memory + swap), `-1` to disable swap
  /// [cpuShares] CPU shares (relative weight)
  /// [cpuSetCpus] CPUs in which to allow execution, e.g., `0-3`, `0,1`
  ///
  /// Request Headers:
  ///
  /// `Content-type` Should be set to `"application/tar"`.
  /// `X-Registry-Config` base64-encoded ConfigFile object.
  ///
  /// Status Codes:
  /// 200 - no error
  /// 500 - server error
  Future<Stream<List<int>>> build(Stream<List<int>> stream,
      {AuthConfig authConfig,
      String dockerfile,
      String t,
      String remote,
      bool q,
      bool noCache,
      bool pull,
      bool rm,
      bool forceRm,
      int memory,
      int memSwap,
      List<int> cpuShares,
      List<String> cpuSetCpus}) async {
    assert(stream != null);
    Map<String, String> query = <String, String>{};

    final Map<String, String> headers = headersTar;
    if (authConfig != null) {
      headers['X-Registry-Config'] = CryptoUtils
          .bytesToBase64(UTF8.encode(JSON.encode(authConfig.toJson())));
    }
    return _streamRequestStream('/build', stream, query: query);
  }

  /// Create an image, either by pulling it from the registry or by importing it.
  /// [fromImage] Name of the image to pull
  /// [fromSrc] Source to import. The value may be a URL from which the image
  ///     can be retrieved or - to read the image from the request body.
  /// [repo] Repository
  /// [tag] Tag
  /// [registry] The registry to pull from
  ///
  /// Request Headers:
  /// X-Registry-Auth – base64-encoded AuthConfig object
  /// Status Codes:
  /// 200 - no error
  /// 500 - server error
  Future<Iterable<CreateImageResponse>> createImage(String fromImage,
      {AuthConfig authConfig,
      String fromSrc,
      String repo,
      String tag,
      String registry}) async {
    assert(fromImage != null && fromImage.isNotEmpty);
    Map<String, String> query = <String, String>{};
    if (fromImage != null) query['fromImage'] = fromImage;
    if (fromSrc != null) query['fromSrc'] = fromSrc;
    if (repo != null) query['repo'] = repo;
    if (tag != null) query['tag'] = tag;
    if (registry != null) query['registry'] = registry;

    Map<String, String> headers;
    if (authConfig != null) {
      headers['X-Registry-Config'] = CryptoUtils
          .bytesToBase64(UTF8.encode(JSON.encode(authConfig.toJson())));
    }

    final List<Map<String, dynamic>> response =
        await _request /*<List<Map<String,dynamic>>>*/ (
            RequestType.post, '/images/create',
            query: query,
            headers: headers,
            preprocessor: _jsonifyConcatenatedJson);
    return response.map /*<CreateImageResponse>*/ ((Map<String, dynamic> e) =>
        new CreateImageResponse.fromJson(e, remoteApiVersion));
  }

  /// Return low-level information on the [image].
  /// Status Codes:
  /// 200 - no error
  /// 404 - no such image
  /// 500 - server error
  Future<ImageInfo> image(Image image) async {
    assert(image != null && image.name != null && image.name.isNotEmpty);
    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.get, '/images/${image.name}/json');
//    print(response);
    return new ImageInfo.fromJson(response, remoteApiVersion);
  }

  /// Return the history of the [image].
  /// Status Codes:
  /// 200 - no error
  /// 404 - no such image
  /// 500 - server error
  Future<Iterable<ImageHistoryResponse>> history(Image image) async {
    assert(image != null && image.name != null && image.name.isNotEmpty);
    final List<Map<String, dynamic>> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.get, '/images/${image.name}/history');
//    print(response);
    return response.map /*<ImageHistoryResponse>*/ ((Map<String, dynamic> e) =>
        new ImageHistoryResponse.fromJson(e, remoteApiVersion));
  }

  /// Push the image name on the registry.
  /// If you wish to push an image on to a private registry, that image must
  /// already have been tagged into a repository which references that registry
  /// host name and port.  This repository name should then be used in the URL.
  /// This mirrors the flow of the CLI.
  /// [tag] The tag to associate with the image on the registry, optional.
  /// [registry] The registry to push to, like `registry.acme.com:5000`
  /// [AuthConfig] Passed as `X-Registry-Auth` request header.
  /// Status Codes:
  /// 200 - no error
  /// 404 - no such image
  /// 500 - server error
  Future<Iterable<ImagePushResponse>> push(Image image,
      {AuthConfig authConfig, String tag, String registry}) async {
    assert(image != null && image.name != null && image.name.isNotEmpty);
    Map<String, String> query = {};
    if (tag != null) query['tag'] = tag;

    Map<String, String> headers;
    if (authConfig != null) {
      headers['X-Registry-Config'] = CryptoUtils
          .bytesToBase64(UTF8.encode(JSON.encode(authConfig.toJson())));
    }

    String reg = '';
    if (registry != null) {
      reg = registry;
      if (reg.endsWith('/')) {
        reg = reg.substring(0, reg.length - 1);
      }
      if (!reg.startsWith('/')) {
        reg = '/${reg}';
      }
    }

    final List<Map<String, dynamic>> response =
        await _request /*List<Map<String,dynamic>>*/ (
            RequestType.post, '/images${reg}/${image.name}/push',
            query: query,
            headers: headers,
            preprocessor: _jsonifyConcatenatedJson);
    return response.map /*<ImagePushResponse>*/ ((Map<String, dynamic> e) =>
        new ImagePushResponse.fromJson(e, remoteApiVersion));
  }

  /// Tag the [image] into a repository.
  /// [repo] The repository to tag in
  /// [force] default false
  /// [tag] The new tag name.
  /// Status Codes:
  /// 201 - no error
  /// 400 - bad parameter
  /// 404 - no such image
  /// 409 - conflict
  /// 500 - server error
  Future<SimpleResponse> tag(Image image, String repo, String tag,
      {bool force}) async {
    assert(image != null && image.name != null && image.name.isNotEmpty);
    assert(tag != null && tag.isNotEmpty);
    assert(repo != null && repo.isNotEmpty);

    Map<String, String> query = <String, String>{};
    if (tag != null) query['tag'] = tag;
    if (repo != null) query['repo'] = repo;
    if (force != null) query['force'] = force.toString();

    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.post, '/images/${image.name}/tag',
            query: query);
    return new SimpleResponse.fromJson(response, remoteApiVersion);
  }

  /// Remove the image name from the filesystem.
  /// [force] default false
  /// [noprune] default false
  /// Status Codes:
  ///
  /// 200 - no error
  /// 404 - no such image
  /// 409 - conflict
  /// 500 - server error
  Future<Iterable<ImageRemoveResponse>> removeImage(Image image,
      {bool force, bool noPrune}) async {
    assert(image != null && image.name != null && image.name.isNotEmpty);

    Map<String, String> query = <String, String>{};
    if (force != null) query['force'] = force.toString();
    if (noPrune != null) query['noprune'] = noPrune.toString();

    final List response = await _request(
        RequestType.delete, '/images/${image.name}',
        query: query);
    return response.map /*<ImageRemoveResponse>*/ ((Map<String, dynamic> e) =>
        new ImageRemoveResponse.fromJson(e, remoteApiVersion));
  }

  /// Search for an image on [Docker Hub](https://hub.docker.com/).
  /// Note: The response keys have changed from API v1.6 to reflect the JSON
  /// sent by the registry server to the docker daemon's request.
  /// [term] Term to search.
  /// Status Codes:
  /// 200 - no error
  /// 500 - server error
  Future<Iterable<SearchResponse>> search(String term) async {
    assert(term != null);

    Map<String, String> query = {'term': term};

    final List response =
        await _request(RequestType.get, '/images/search', query: query);
    return response.map((Map<String, dynamic> e) =>
        new SearchResponse.fromJson(e, remoteApiVersion));
  }

  /// Get the default username and email.
  /// Status Codes:
  /// 200 - no error
  /// 204 - no error
  /// 500 - server error
  Future<AuthResponse> auth(AuthRequest auth) async {
    assert(auth != null);

    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (RequestType.post, '/auth',
            body: auth.toJson());
    return new AuthResponse.fromJson(response, remoteApiVersion);
  }

  /// Get system-wide information.
  /// Status Codes:
  /// 200 - no error
  /// 500 - server error
  Future<InfoResponse> info() async {
    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (RequestType.get, '/info');
    return new InfoResponse.fromJson(response, remoteApiVersion);
  }

  /// Show Docker version information.
  /// Status Codes:
  /// 200 - no error
  /// 500 - server error
  Future<VersionResponse> version() async {
    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (RequestType.get, '/version');
    return new VersionResponse.fromJson(response, remoteApiVersion);
  }

  /// Ping the Docker server.
  /// Status Codes:
  /// 200 - no error
  /// 500 - server error
  Future<SimpleResponse> ping() async {
    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (RequestType.get, '/_ping',
            preprocessor: (Object s) => '{"response": "${s}"}');
    if (response['response'] == 'OK') {
      return new SimpleResponse.fromJson(null, remoteApiVersion);
    }
    throw new DockerRemoteApiError(500, 'ping failed', response['response']);
  }

  /// Create a new image from a container's changes.
  /// [config] The container's configuration
  /// [container] Source container
  /// [repo] Repository
  /// [tag] Tag
  /// [comment] Commit message
  /// [author] Author (e.g., "John Hannibal Smith <hannibal@a-team.com>")
  /// Status Codes:
  /// 201 – no error
  /// 404 – no such container
  /// 500 – server error
  Future<CommitResponse> commit(CommitRequest config, Container container,
      {String repo, String tag, String comment, String author}) async {
    assert(config != null);
    assert(config != null);
    Map<String, String> query = <String, String>{};
    if (container != null) query['container'] = container.id;
    if (repo != null) query['repo'] = repo;
    if (tag != null) query['tag'] = tag;
    if (comment != null) query['comment'] = comment;
    if (author != null) query['author'] = author;

    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (RequestType.post, '/commit',
            query: query, body: config.toJson());
    return new CommitResponse.fromJson(response, remoteApiVersion);
  }

  /// Get container events from docker, either in real time via streaming, or
  /// via polling (using since).
  /// Docker containers will report the following events:
  ///     create, destroy, die, exec_create, exec_start, export, kill, oom,
  ///     pause, restart, start, stop, unpause
  ///   and Docker images will report:
  ///      untag, delete
  ///
  /// [since] Timestamp used for polling
  /// [until] Timestamp used for polling
  /// [filters] A json encoded value of the filters (a map[string][]string) to
  ///     process on the event list. Available filters:
  ///         event=<string> - event to filter
  ///         image=<string> - image to filter
  ///         container=<string> - container to filter
  /// Status Codes:
  /// 200 - no error
  /// 500 - server error
  Stream<EventsResponse> events(
      {DateTime since, DateTime until, EventsFilter filters}) async* {
    Map<String, String> query = <String, String>{};
    if (since != null) query['since'] =
        (since.toUtc().millisecondsSinceEpoch ~/ 1000).toString();
    if (until != null) query['until'] =
        (until.toUtc().millisecondsSinceEpoch ~/ 1000).toString();
    if (filters != null) query['filters'] = JSON.encode(filters.toJson());

    final Stream<List<int>> response =
        await _requestStream(RequestType.get, '/events', query: query);
    if (response != null) {
      await for (List<int> e in response) {
//        print(UTF8.decode(e));
        yield new EventsResponse.fromJson(
            JSON.decode(UTF8.decode(e)) as Map<String, dynamic>,
            remoteApiVersion);
      }
    }
  }

  /// Get a tarball containing all images and metadata for the repository
  /// specified by [image.name].
  /// If [image.name] is a specific name and tag (e.g. `ubuntu:latest`), then
  /// only that image (and its parents) are returned. If [image.name] is an
  /// image ID, similarly only tha image (and its parents) are returned, but
  /// with the exclusion of the 'repositories' file in the tarball, as there
  /// were no image names referenced.
  /// See the [image tarball format](https://docs.docker.com/reference/api/docker_remote_api_v1.18/#image-tarball-format)
  /// for more details.
  /// Status Codes:
  /// 200 - no error
  /// 500 - server error
  Future<http.ByteStream> get(Image image) async {
    assert(image != null && image.name != null && image.name.isNotEmpty);
    return _requestStream(RequestType.get, '/images/${image.name}/get')
        as http.ByteStream;
  }

  /// Get a tarball containing all images and metadata for one or more
  /// repositories.
  /// For each value of the names parameter: if it is a specific name and tag
  /// (e.g. ubuntu:latest), then only that image (and its parents) are returned;
  /// if it is an image ID, similarly only that image (and its parents) are
  /// returned and there would be no names referenced in the 'repositories'
  /// file for this image ID.
  /// See the [image tarball format](https://docs.docker.com/reference/api/docker_remote_api_v1.18/#image-tarball-format)
  /// Status Codes:
  /// 200 - no error
  /// 500 - server error
  Future<Stream<List<int>>> getAll() async {
    return _requestStream(RequestType.get, '/images/get');
  }

  /// Load a set of images and tags into the docker repository.
  /// See the [image tarball format](https://docs.docker.com/reference/api/docker_remote_api_v1.18/#image-tarball-format)
  /// Status Codes:
  /// 200 - no error
  /// 500 - server error
  Future<SimpleResponse> load(Stream<List<int>> stream) async {
    final http.ByteStream response =
        await _streamRequestStream('/images/load', stream);
    List<int> buf = <int>[];
    final Completer<SimpleResponse> completer = new Completer<SimpleResponse>();
    response.listen(buf.addAll, onDone: () {
      final SimpleResponse result = new SimpleResponse.fromJson(
          JSON.decode(UTF8.decode(buf)) as Map<String, dynamic>,
          remoteApiVersion);
      completer.complete(result);
    });
    return completer.future;
  }

  /// Sets up an exec instance in a running [container]
  /// [attachStdin] Attaches to stdin of the exec command.
  /// [attachStdout] Attaches to stdout of the exec command.
  /// [attachStderr] Attaches to stderr of the exec command.
  /// [tty] Allocate a pseudo-TTY
  /// [cmd] Command to run specified as a string or an array of strings.
  /// Status Codes:
  /// 201 - no error
  /// 404 - no such container
  Future<Exec> execCreate(Container container,
      {bool attachStdin,
      bool attachStdout,
      bool attachStderr,
      bool tty,
      List<String> cmd}) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    assert(cmd != null &&
        cmd.isNotEmpty &&
        cmd.every((String e) => e != null && e.isNotEmpty));

    Map<String, dynamic> body = <String, dynamic>{};
    if (attachStdin != null) body['AttachStdin'] = attachStdin;
    if (attachStdout != null) body['AttachStdout'] = attachStdout;
    if (attachStderr != null) body['AttachStderr'] = attachStderr;
    if (tty != null) body['Tty'] = tty;
    if (cmd != null) body['Cmd'] = cmd;

    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.post, '/containers/${container.id}/exec',
            body: body);
    return new Exec.fromJson(response, remoteApiVersion);
  }

  /// Starts a previously set up [exec] instance. If [detach] is [:true:], this
  /// API returns after starting the exec command. Otherwise, this API sets up
  /// an interactive session with the exec command.
  /// [detach] Detach from the exec command
  /// [tty] Allocate a pseudo-TTY
  /// Status Codes:
  /// 201 - no error
  /// 404 - no such exec instance
  /// Stream details: Similar to the stream behavior of
  /// `POST /container/(id)/attach` API
  Future<DeMux> execStart(Exec exec, {bool detach, bool tty}) async {
    assert(exec != null && exec.id != null && exec.id.isNotEmpty);

    Map<String, dynamic> body = <String, dynamic>{};
    if (detach != null) body['Detach'] = detach;
    if (tty != null) body['Tty'] = tty;

    final Stream<List<int>> response = await _requestStream(
        RequestType.post, '/exec/${exec.id}/start',
        body: body);
    //print(response);
    return new DeMux(response);
  }

  /// Resizes the tty session used by [exec]. This API is valid only if tty was
  /// specified as part of creating and starting the exec command.
  /// [h] Height of tty session
  /// [w] Width
  /// Status Codes:
  /// 201 - no error
  /// 404 - no such exec instance
  Future<Exec> execResize(Exec exec, int height, int width) async {
    assert(exec != null && exec.id != null && exec.id.isNotEmpty);

    Map<String, dynamic> body = <String, dynamic>{};
    if (height != null) body['h'] = '${height}';
    if (width != null) body['width'] = '${width}';

    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.post, '/exec/${exec.id}/resize',
            body: body);
    return new Exec.fromJson(response, remoteApiVersion);
  }

  /// Return low-level information about the [exec].
  /// Status Codes:
  /// 200 – no error
  /// 404 – no such exec instance
  /// 500 - server error
  Future<ExecInfo> execInspect(Exec exec) async {
    assert(exec != null && exec.id != null && exec.id.isNotEmpty);

    final Map<String, dynamic> response =
        await _request /*<Map<String,dynamic>>*/ (
            RequestType.get, '/exec/${exec.id}/json');
    //print(response);
    return new ExecInfo.fromJson(response, remoteApiVersion);
  }
}


