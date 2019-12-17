# Teedy multi-architecture Docker images

Teedy (formerly Sismics Docs) is an open source, lightweight document management system. The source code and project can be found here - [https://github.com/sismics/docs](https://github.com/sismics/docs).

Prebuilt images are available on Docker Hub as [jdreinhardt/teedy](https://hub.docker.com/r/jdreinhardt/teedy)

Default credentials are `admin:admin` Make sure to update the default password after login.

## README

The `build.sh` is designed to simplify the generation of multi-architecture Docker images of Teedy. It also includes a number of safety checks and automations to simplify the build process. The overall build uses build arguments to target specific architectures.

Currently supported architectures are 
 - `amd64 (x86_64)`
 - `arm32v7 (armhf)`
 - `arm64v8 (arm64/aarch64)`

This list is not exhaustive and more can easily be added at the top of the script, or built manually. 

The `Dockerfile` uses a builder image to reduce the overall size of the image while also building Teedy directly from source ensure the images stay up-to-date with the source project. 

### Build Pattern

The `build.sh` script is the easiest way to build images yourself. For manual builds use the following build arguments
 - `DOCKER_ARCHITECTURE`
 - `CPU_ARCHITECTURE`

No other arguments are required. An example build command would be `docker build -t jdreinhardt/teedy:latest-arm32v7 --build-arg DOCKER_ARCHITECTURE=arm32v7 --build-arg CPU_ARCHITECTURE=armhf .`

### Usage Pattern

The following parameters are available 
 - `-e MAX_HEAP_SIZE` customize the maximum size of the JAVA heap
 - `-p 8080` web interface internal port
 - `-v /data` Teedy data location

Example run command `docker run -e MAX_HEAP_SIZE=1024m -p 80:8080 -v /mnt/teedy:/data jdreinhardt/teedy:latest`
