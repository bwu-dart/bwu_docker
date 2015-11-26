library bwu_docker.src.shared.exception;

/// Error thrown
class DockerRemoteApiError {
  final int statusCode;
  final String reason;
  final String body;
  final String message;

  DockerRemoteApiError(this.statusCode, this.reason, this.body, {this.message});

  @override
  String toString() =>
      '${super.toString()} - StatusCode: ${statusCode}, Reason: ${reason}, '
      'Body: ${body}, Message: ${message}';
}
