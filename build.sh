#!/usr/bin/bash
#
# +-------------+--------------+-----------------+------------------+
# | Docker arch |   uname -m   | multi-arch code |       Note       |
# +-------------+--------------+-----------------+------------------+
# | amd64       | x86_64       | x86_64          |                  |
# | arm32v7     | armhf, arm7l | arm             | Raspberry Pis    |
# | arm64v8     | aarch6       | aarch64         | A53, H3, H5 ARMs |
# +-------------+--------------+-----------------+------------------+
# Additional architectures can be found at https://github.com/multiarch/qemu-user-static/releases/latest

DOCKER_ARCHS=(amd64 arm32v7 arm64v8)
TEEDY_VERS="1.8"
IMAGE_NAME="jdreinhardt/teedy"
MA_ARCHS=()

echo "##"
echo "## Teedy Docker Build Script"
echo "##"
echo "## Image Name: ${IMAGE_NAME}"
echo "## Tags: latest ${TEEDY_VERS}"
echo "## Architectures: ${DOCKER_ARCHS[@]}"
echo "##"

for arch in ${DOCKER_ARCHS[@]}; do
    case $arch in
    amd64     ) MA_ARCHS+=(x86_64) ;;
    arm32v7   ) MA_ARCHS+=(arm)    ;;
    arm64v8   ) MA_ARCHS+=(aarch64);;
    esac
done

# Download multiarch libraries 
echo -e "##\n## Downloading multiarch libraries\n##"
for arch in ${MA_ARCHS[@]}; do
    wget -N https://github.com/multiarch/qemu-user-static/releases/latest/download/x86_64_qemu-${arch}-static.tar.gz
    tar -xvf x86_64_qemu-${arch}-static.tar.gz
done

# Enable multiarch build support locally
echo -e "##\n## Enabling multiarch build support for Docker\n##"
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Build the requested images
echo -e "##\n## Starting Docker build\n##"
for arch in ${DOCKER_ARCHS[@]}; do
    # Prepare Dockerfile for current architecture
    echo -e "##\n## Now building ${IMAGE_NAME} for ${arch}\n##"
    cp Dockerfile.template Dockerfile.${arch}
    for index in "${!DOCKER_ARCHS[@]}"; do
        [[ "${DOCKER_ARCHS[$i]}" = "${arch}" ]] && break
    done
    sed -i -e "s/__DOCKER_ARCH__/${arch}/g" Dockerfile.${arch}
    sed -i -e "s/__MA_ARCH__/${MA_ARCHS[$index]}/g" Dockerfile.${arch}
    # Update Java parameters to fit build architecture
    if [ ${arch} == 'arm32v7' ]; then
        sed -i -e "s/__JAVA_HOME__/armhf/g" Dockerfile.${arch}
        sed -i -e 's/__MAX_HEAP__/512/g' Dockerfile.${arch}
    elif [ ${arch} == 'arm64v8' ]; then
        sed -i -e "s/__JAVA_HOME__/arm64/g" Dockerfile.${arch}
        sed -i -e 's/__MAX_HEAP__/1024/g' Dockerfile.${arch}
    else
        sed -i -e "s/__JAVA_HOME__/${arch}/g" Dockerfile.${arch}
        sed -i -e 's/__MAX_HEAP__/1024/g' Dockerfile.${arch}
    fi
    # Build and push image
    docker build -f Dockerfile.${arch} -t ${IMAGE_NAME}:latest-${arch} -t ${IMAGE_NAME}:${TEEDY_VERS}-${arch} . --no-cache
    docker push ${IMAGE_NAME}:latest-${arch}
    docker push ${IMAGE_NAME}:${TEEDY_VERS}-${arch}
done

# Generate multi-arch manifests based on requested versions
echo -e "##\n## Generating Docker manifest\n##"
for version in latest $TEEDY_VERS; do
    ALL_TAGS=''
    for arch in ${DOCKER_ARCHS[@]}; do
        ALL_TAGS+=${IMAGE_NAME}:${version}-${arch}' '
    done

    # Check if manifest already exists. Remove if it does to prevent failed update
    if [ -d ~/.docker/manifests/docker.io_${IMAGE_NAME/'/'/'_'}-${version} ]; then
        rm -r ~/.docker/manifests/docker.io_${IMAGE_NAME/'/'/'_'}-${version}
    fi
    docker manifest create ${IMAGE_NAME}:${version} $ALL_TAGS
    # Update manifest to specify architectures for arm builds
    for arch in ${DOCKER_ARCHS[@]}; do
        if [ ${arch} == 'arm32v7' ]; then
            docker manifest annotate ${IMAGE_NAME}:${version} ${IMAGE_NAME}:${version}-${arch} --os linux --arch arm
        elif [ ${arch} == 'arm64v8' ]; then
            docker manifest annotate ${IMAGE_NAME}:${version} ${IMAGE_NAME}:${version}-${arch} --os linux --arch arm64 --variant armv8
        fi
    done
    # Push manifest then remove local manifest to prevent future collisions
    docker manifest push ${IMAGE_NAME}:${version}
    rm -r ~/.docker/manifests/docker.io_${IMAGE_NAME/'/'/'_'}-${version}
done
echo -e "##\n## Complete!\n##"