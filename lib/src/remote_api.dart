library bwu_docker.src.remote_api.dart;

import 'dart:convert' show JSON, UTF8;
import 'package:crypto/crypto.dart' show CryptoUtils;
import 'dart:async' show Future, Stream, ByteStream;
import 'package:http/http.dart' as http;
import 'data_structures.dart';

class DockerConnection {
  final Map headersJson = {'Content-Type': 'application/json'};
  final Map headersTar = {'Content-Type': 'application/tar'};
  final String host;
  final int port;
  http.Client client;
  DockerConnection(this.host, this.port) {
    client = new http.Client();
  }

  /// Send a POST request to the Docker service.
  Future<dynamic> _post(String path,
      {Map json, Map query, Map<String, String> headers}) async {
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

    final http.Response response = await client.post(url,
        headers: headers != null ? headers : headersJson, body: data);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new DockerRemoteApiError(response.statusCode, response.reasonPhrase, response.body);
    }
    if (response.body != null && response.body.isNotEmpty) {
      return JSON.decode(response.body);
    }
    return null;
  }

  /// Send a POST request to the Docker service.
  /// This is to support the weird response content of some concatenated JSON
  /// parts. With some postprocessing valid parsable JSON is created.
  Future<Iterable<Map>> _postReturnListOfJson(String path,
      {Map json, Map query, Map<String, String> headers}) async {
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

    final http.Response response = await client.post(url,
        headers: headers != null ? headers : headersJson, body: data);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new DockerRemoteApiError(response.statusCode, response.reasonPhrase, response.body);
    }
    if (response.body != null && response.body.isNotEmpty) {
      return JSON.decode(
          '[${response.body.replaceAll(new RegExp(r'\}\s*\{', multiLine: true), '},\n{')}]');
    }
    return null;
  }

  /// Post request expecting a streamed response.
  Future<Stream> _postReturnStream(String path, {Map json,
      Map<String, String> query, Map<String, String> headers}) async {
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
    final request = new http.Request('POST', url)
      ..headers.addAll(headers != null ? headers : headersJson);
    if (data != null) {
      request.body = data;
    }
    final http.BaseResponse response =
        await request.send().then(http.Response.fromStream);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new DockerRemoteApiError(response.statusCode, response.reasonPhrase, null);
    }
    return (response as http.StreamedResponse).stream;
  }

  /// Send a POST request to the Docker service.
  Future<Stream> _postStreamReturnStream(String path, Stream<List<int>> stream,
      {Map<String, String> query}) async {
    assert(stream != null);
    final url = new Uri(
        scheme: 'http',
        host: host,
        port: port,
        path: path,
        queryParameters: query);
    final request = new http.StreamedRequest('POST', url)
      ..headers.addAll(headersTar);
    stream.listen(request.sink.add);
    final http.BaseResponse response =
        await request.send().then(http.Response.fromStream);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new DockerRemoteApiError(response.statusCode, response.reasonPhrase, null);
    }
    return (response as http.StreamedResponse).stream;
  }

  Future<dynamic> _get(String path, {Map<String, String> query}) async {
    final url = new Uri(
        scheme: 'http',
        host: host,
        port: port,
        path: path,
        queryParameters: query);
    final http.Response response = await client.get(url, headers: headersJson);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new DockerRemoteApiError(response.statusCode, response.reasonPhrase, response.body);
    }

    if (response.body != null && response.body.isNotEmpty) {
      return JSON.decode(response.body);
    }
    return null;
  }

  /// Get request expecting a streamed response.
  Future<http.ByteStream> _getReturnStream(String path,
      {Map<String, String> query}) async {
    final url = new Uri(
        scheme: 'http',
        host: host,
        port: port,
        path: path,
        queryParameters: query);
    final request = new http.Request('GET', url);
    request.headers.addAll(headersJson);
    final http.BaseResponse response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new DockerRemoteApiError(response.statusCode, response.reasonPhrase, null);
    }
    return (response as http.StreamedResponse).stream;
  }

  Future<dynamic> _delete(String path, {Map<String, String> query}) async {
    final url = new Uri(
        scheme: 'http',
        host: host,
        port: port,
        path: path,
        queryParameters: query);
    final http.Response response =
        await client.delete(url, headers: headersJson);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new DockerRemoteApiError(response.statusCode, response.reasonPhrase, response.body);
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
    //print(response);
    return response.map((e) => new Container.fromJson(e));
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
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
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
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
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
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
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

    return _getReturnStream('/containers/${container.id}/logs', query: query);
  }

  /// Inspect changes on [container]'s filesystem
  /// Status Codes:
  /// 200 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<ChangesResponse> changes(Container container) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
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
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    return _getReturnStream('/containers/${container.id}/export');
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
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
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
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
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
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
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
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
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
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
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
  Future<SimpleResponse> kill(Container container, {dynamic signal}) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
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
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
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
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    final Map response = await _post('/containers/${container.id}/pause');
    return new SimpleResponse.fromJson(response);
  }

  /// Unpause the [container].
  /// Status Codes:
  /// 204 - no error
  /// 404 - no such container
  /// 500 - server error
  Future<SimpleResponse> unpause(Container container) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
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
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    final query = {};
    if (logs != null) query['logs'] = logs.toString();
    if (stream != null) query['stream'] = stream.toString();
    if (stdin != null) query['stdin'] = stdin.toString();
    if (stdout != null) query['stdout'] = stdout.toString();
    if (stderr != null) query['stderr'] = stderr.toString();

    return _getReturnStream('/containers/${container.id}/attach', query: query);
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
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
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
  /// It seems the container must be stopped before it can be removed.
  Future<SimpleResponse> removeContainer(Container container,
      {bool removeVolumes, bool force}) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    final query = {};
    if (removeVolumes != null) query['v'] = removeVolumes.toString();
    if (force != null) query['force'] = force.toString();

    final Map response = await _delete('/containers/${container.id}');
    return new SimpleResponse.fromJson(response);
  }

  /// Copy files or folders of [container].
  /// Status Codes:
  /// 200 - no error
  /// 404 - no such container
  /// 500 - server error
  // TODO(zoechi) figure out whether it's possible to request more than one file
  // or directory with one request.
  /// [resource] is the path of a file or directory;
  Future<Stream> copy(Container container, String resource) async {
    assert(
        container != null && container.id != null && container.id.isNotEmpty);
    final json = new CopyRequestPath(resource).toJson();

    return _postReturnStream('/containers/${container.id}/copy', json: json);
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

    final List response = await _get('/images/json', query: query);
    return response.map((e) => new ImageInfo.fromJson(e));
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
  Future<Stream> build(Stream<List<int>> stream, {AuthConfig authConfig,
      String dockerfile, String t, String remote, bool q, bool noCache,
      bool pull, bool rm, bool forceRm, int memory, int memSwap,
      List<int> cpuShares, List<String> cpuSetCpus}) async {
    assert(stream != null);
    Map<String, String> query = {};

    final headers = headersTar;
    if (authConfig != null) {
      headers['X-Registry-Config'] = CryptoUtils
          .bytesToBase64(UTF8.encode(JSON.encode(authConfig.toJson())));
    }
    return _postStreamReturnStream('/build', stream, query: query);
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
  Future<List<CreateImageResponse>> createImage(String fromImage,
      {AuthConfig authConfig, String fromSrc, String repo, String tag,
      String registry}) async {
    assert(fromImage != null && fromImage.isNotEmpty);
    Map<String, String> query = {};
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

    final response = await _postReturnListOfJson('/images/create',
        query: query, headers: headers);
    return response.map((e) => new CreateImageResponse.fromJson(e));
  }

  /// Return low-level information on the [image].
  /// Status Codes:
  /// 200 - no error
  /// 404 - no such image
  /// 500 - server error
  Future<ImageInfo> image(Image image) async {
    assert(image != null && image.name != null && image.name.isNotEmpty);
    final Map response = await _get('/images/${image.name}/json');
    print(response);
    return new ImageInfo.fromJson(response);
  }

  /// Return the history of the [image].
  /// Status Codes:
  /// 200 - no error
  /// 404 - no such image
  /// 500 - server error
  Future<Iterable<ImageHistoryResponse>> history(Image image) async {
    assert(image != null && image.name != null && image.name.isNotEmpty);
    final List response = await _get('/images/${image.name}/history');
    print(response);
    return response.map((e) => new ImageHistoryResponse.fromJson(e));
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

    final response = await _postReturnListOfJson('/images${reg}/${image.name}/push',
        query: query, headers: headers);
    return response.map((e) => new ImagePushResponse.fromJson(e));
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
  Future<SimpleResponse> tag(Image image, String repo, String tag, {bool force}) async {
    assert(image != null && image.name != null && image.name.isNotEmpty);
    assert(tag != null && tag.isNotEmpty);
    assert(repo != null && repo.isNotEmpty);

    Map<String, String> query = {};
    if (tag != null) query['tag'] = tag;
    if (repo != null) query['repo'] = repo;
    if (force != null) query['force'] = force.toString();

    final Map response = await _post('/images/${image.name}/tag', query: query);
    return new SimpleResponse.fromJson(response);
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
  Future<Iterable<ImageRemoveResponse>> removeImage(Image image, {bool force, bool noPrune}) async {
    assert(image != null && image.name != null && image.name.isNotEmpty);

    Map<String, String> query = {};
    if (force != null) query['force'] = force.toString();
    if (noPrune != null) query['noprune'] = noPrune.toString();

    final List response = await _delete('/images/${image.name}', query: query);
    return response.map((e) => new ImageRemoveResponse.fromJson(e));
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

    final List response = await _get('/images/search', query: query);
    return response.map((e) => new SearchResponse.fromJson(e));
  }

  /// Get the default username and email.
  /// Status Codes:
  /// 200 - no error
  /// 204 - no error
  /// 500 - server error
  Future<AuthResponse> auth(AuthRequest auth) async {
    assert(auth != null);

    final Map response = await _post('/auth', json: auth.toJson());
    return new AuthResponse.fromJson(response);
  }

  /// Get system-wide information.
  /// Status Codes:
  /// 200 - no error
  /// 500 - server error
  Future<InfoResponse> info() async {

    final Map response = await _get('/info');
    return new InfoResponse.fromJson(response);
  }

  Future<VersionResponse> version() async {

    final Map response = await _get('/version');
    return new VersionResponse.fromJson(response);
  }
}


