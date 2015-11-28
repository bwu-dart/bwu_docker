# How to run the tests

## Grinder 

```bash
pub global activate grinder
grind
```

Grinder starts 

- `pub run test` and launches two Docker in Docker instances (see also 
https://hub.docker.com/_/docker/).
One Docker instance (port 3376) is used to run the tasks_test.dart, the other 
(port 3375) to run all remaining tests.
  

## Debug

- start two Docker in Docker instances
```bash
docker run -ti --privileged -d -p 3375:2375 -e PORT=2375 docker:1.9-dind 
docker run -ti --privileged -d -p 3376:2375 -e PORT=2375 docker:1.9-dind 
```              

Set the environment variable
`DOCKER_HOST_REMOTE_API=http://localhost:3375`

Debug the tests from your IDE like any other Dart script.

## Tips

- before running tests, ensure no container (running or not) are left in the
Docker services started above. This shouldn't happen but there seem to be 
issues with reliable cleanup.

```
# list containers
docker ps -a
# connect to one container 
docker exect -it <containerid> sh
# remove leftover containers
docker rm -f <id1> <id2> ...
``` 
