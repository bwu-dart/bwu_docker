library bwu_docker.src.shared.remote_api;

import 'dart:async' show Stream, StreamController;
import 'package:http/http.dart' as http;

import 'version.dart';

export 'version.dart';

typedef String ResponsePreprocessor(String s);

/// The OS environment variable pointing to the Uri Docker remote API service.
/// `DOCKER_HOST` might be set to `tcp://localhost:2375` which is not supported
/// by bwu_docker because Dart doesn't support unix sockets (tcp) yet.
/// `DOCKER_HOST_REMOTE_API` should be something like `http://localhost:2375`
String dockerHostFromEnvironment = 'DOCKER_HOST_REMOTE_API';

class RequestType {
  static const RequestType post = const RequestType('POST');
  static const RequestType get = const RequestType('GET');
  static const RequestType delete = const RequestType('DELETE');

  final String value;

  const RequestType(this.value);

  @override
  String toString() => value;
}

class ServerReference {
  final Uri uri;
  http.Client client;
  final RemoteApiVersion remoteApiVersion;
  String _versionPath;
  ServerReference(this.uri, this.client, {this.remoteApiVersion}) {
    if (remoteApiVersion != null && remoteApiVersion.isSupported) {
      _versionPath = remoteApiVersion.asDirectory;
    } else {
      _versionPath = '';
    }
  }

  Uri buildUri(String path, Map<String, String> queryParameters) {
    return new Uri(
        scheme: uri.scheme,
        userInfo: uri.userInfo,
        host: uri.host,
        port: uri.port,
        path: '${_versionPath}${path}',
        queryParameters: queryParameters);
  }
}

class DeMux {
  static const int _stdin = 0;
  static const int _stdout = 1;
  static const int _stderr = 2;
  static const int _headerLength = 8;
  static const int _firstLengthBytePos = 4;

  final Stream<List<int>> _stream;

  final StreamController<List<int>> _stdinController =
      new StreamController<List<int>>();
  Stream<List<int>> get stdin => _stdinController.stream;

  final StreamController<List<int>> _stdoutController =
      new StreamController<List<int>>();

  Stream<List<int>> get stdout => _stdoutController.stream;

  final StreamController<List<int>> _stderrController =
      new StreamController<List<int>>();
  Stream<List<int>> get stderr => _stderrController.stream;

  DeMux(this._stream) {
    _processData();
  }

  void _processData() {
    StreamController current;
    int byteCountdown = 0;

    List<int> buf = <int>[];
    _stream.listen((List<int> data) {
      buf.addAll(data);
      while (buf.length > _headerLength) {
        if (byteCountdown == 0) {
          if (buf.length >= _headerLength) {
            final List<int> header = buf.sublist(0, _headerLength);
            buf.removeRange(0, _headerLength);

            switch (header[0]) {
              case _stdin:
                current = _stdinController;
                break;
              case _stdout:
                current = _stdoutController;
                break;
              case _stderr:
                current = _stderrController;
                break;
              default:
                throw 'Must not be reached.';
            }
            byteCountdown = (header[_firstLengthBytePos] << 24) |
                (header[_firstLengthBytePos + 1] << 16) |
                (header[_firstLengthBytePos + 2] << 8) |
                header[_firstLengthBytePos + 3];
          }
        }
        if (byteCountdown > 0) {
          if (buf.length <= byteCountdown) {
            current.add(buf);
            byteCountdown -= buf.length;
            buf = <int>[];
          } else {
            current.add(buf.sublist(0, byteCountdown));
            buf = buf.sublist(byteCountdown);
            byteCountdown = 0;
          }
        }
      }
    },
        onDone: () => _close(),
        onError: (dynamic e, StackTrace s) => _error(e, s));
  }

  void _error(dynamic e, StackTrace s) {
    _stdinController.addError(e, s);
    _stderrController.addError(e, s);
    _stdoutController.addError(e, s);
    _close();
  }

  void _close() {
    _stdinController.close();
    _stderrController.close();
    _stdoutController.close();
  }
}
