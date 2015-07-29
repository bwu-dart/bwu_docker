## UNRELEASED
- Started implementation of a `run` task
  - add `publish` parameter
  - add `rm` parameter
- Breaking change:
  - Changed the `PortBindings` structure and implementation (fromJson/toJson)

## 0.2.1
- Support for Docker API v 1.19 
- DockerConnection now takes an Uri instead of parts
- Test and grinder read DOCKER_HOST_REMOTE environment variable to find the 
Docker service
- A http.client needs to be passed to DockerConnection to allow to use it also
in the browser
- change `toJson()` methods so that only fields != null are added to the JSON 
output.
