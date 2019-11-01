# Teedy multi-architecture Docker

Teedy (formerly Sismics Docs) is an open source, lightweight document management system. The source code and project can be found here - [https://github.com/sismics/docs](https://github.com/sismics/docs).

The `build.sh` will generate multi-architecture builds for Teedy. Current architectures are `amd64`, `arm32v7`, and `arm64v8`, but more can easily be added at the top of the script. The `Dockerfile` uses a builder image to reduce the overall size of the image while also building Teedy directly from source ensure the image stays up-to-date.

Prebuilt iamges are available on Docker Hub as [jdreinhardt/teedy](https://hub.docker.com/r/jdreinhardt/teedy)

Default credentials are ``admin:admin`` Make sure to update the default password.
