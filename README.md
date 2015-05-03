# Dart client for the Docker remote API

See https://docs.docker.com/reference/api/docker_remote_api_v1.18/#image-tarball-format 
for more details.

This package provides a typed interface to the Docker REST API and classes the 
JSON response is automatically deserialized to.

Currently only requests which are available in Docker version 1.3.3 
(Server, Server API version: 1.15) are tested.

This package is intended to make it easy to automate Docker tasks like for 
example from [Grinder](https://pub.dartlang.org/packages/grinder) tasks.

## TODO

- Test all methods with recent Docker version (> 1.3.3)
- Demultiplex multiplexed streams (stdout/stdin/stderr)
