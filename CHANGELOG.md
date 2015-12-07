## UNRELEASED

# 0.3.0
- Some code restructuring because at some point it seemed necessary to split 
 code int pre 1.20 and 1.20 or higher but actually wasn't. 
- Doesn't throw on unexpected JSON items anymore. This can be enabled by setting
`bool doCheckSurplusItems = true`;
- Partial support for Docker API v 1.20 and v.121 # TODO (zoechi) implement all new features
- support in `DockerConnection` to use a specific remote API version
- improve Docker container creation for running tests
- update config for linter (Grinder task)
- Started implementation of a `run` task
  - add `publish` parameter
  - add `rm` parameter
  - add `link` parameter
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
