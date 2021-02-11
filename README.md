# Teedy multi-architecture Docker images

Teedy (formerly Sismics Docs) is an open source, lightweight document management system. The source code and project can be found here - [https://github.com/sismics/docs](https://github.com/sismics/docs).

Prebuilt images are available on Docker Hub as [jdreinhardt/teedy](https://hub.docker.com/r/jdreinhardt/teedy)

Default credentials are `admin:admin` Make sure to update the default password after login.

## README

The `build.sh` is designed to simplify the generation of multi-architecture Docker images of Teedy. It also includes a number of safety checks and automations to simplify the build process. A few customizations are available as variables at the top of the `build.sh` script.

Currently supported architectures are 
 - `amd64 (x86_64)`
 - `arm32v7 (armhf)`
 - `arm64 (aarch64)`

This list is not exhaustive and more can easily be added at the top of the script, or built manually. 

The `Dockerfile` uses a builder image to reduce the overall size of the image while also building Teedy directly from source ensure the images stay up-to-date with the source project. Current image sizes are approximately half the size of the official images. 

### Build Pattern

The `build.sh` script is the easiest way to build images yourself. For manual builds you will need to enable buildx on your system. Once you enable buildx you will need to also run the following:
 - `docker run --rm --privileged linuxkit/binfmt:v0.8` (This is only required if you want to build for architectures other than your build system)
 - `docker buildx create --name xbuilder`
 - `docker buildx use xbuilder`
 - `docker buildx inspect --bootstrap`

After running these commands you will have a new buildx builder running. You can use `docker buildx ls` to view all builders and their supported architectures.

One build argument is required: `TEEDY_BRANCH` which is used to specify the Git branch to use for the build. An example build command would be `docker buildx build -f Dockerfile --build-arg TEEDY_BRANCH=master --platform=linux/arm/v7,linux/amd64,linux/arm64 --push -t jdreinhardt/teedy:latest .`

### Usage Pattern

The following parameters are available 
 - `-e JAVA_OPTIONS` customize the Java Options (default: -Xmx512m)
 - `-e OCR_LANGS` *(>= 1.10)* add additional OCR language support. Only English by default
 - `-p 8080` web interface internal port
 - `-v /data` Teedy data location

#### Supported OCR Languages

Specifying additional languages is only supported started with version 1.10. Version 1.9 and earlier include all languages by default. 

`ara`, `chi-sim`, `chi-tra`, `dan`, `deu`, `fin`, `fra`, `heb`, `hin`, `hun`, `ita`, `jpn`, `jpn`, `kor`, `lav`, `nld`, `nor`, `pol`, `por`, `rus`, `spa`, `swe`, `tha`, `tur`, `ukr`

Multiple languages can be added by comma separating them.

### Examples

Basic: `docker run -p 80:8080 -v /mnt/teedy:/data jdreinhardt/teedy:latest`

Advanced: `docker run -e JAVA_OPTIONS=-Xmx1024m -e OCR_LANGS=spa,fra -p 80:8080 -v /mnt/teedy:/data jdreinhardt/teedy:latest`
