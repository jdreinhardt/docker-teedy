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

for arch in ${DOCKER_ARCHS[@]}; do
    case $arch in
    amd64     ) MA_ARCHS+=(x86_64) ;;
    arm32v7   ) MA_ARCHS+=(arm)    ;;
    arm64v8   ) MA_ARCHS+=(aarch64);;
    esac
done

for arch in ${MA_ARCHS[@]}; do
    wget -N https://github.com/multiarch/qemu-user-static/releases/latest/download/x86_64_qemu-${arch}-static.tar.gz
    tar -xvf x86_64_qemu-${arch}-static.tar.gz
done

docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Build the requested images
for arch in ${DOCKER_ARCHS[@]}; do
    cp Dockerfile.template Dockerfile.${arch}
    for index in "${!DOCKER_ARCHS[@]}"; do
        [[ "${DOCKER_ARCHS[$i]}" = "${arch}" ]] && break
    done
    sed -i -e "s/__DOCKER_ARCH__/${arch}/g" Dockerfile.${arch}
    sed -i -e "s/__MA_ARCH__/${MA_ARCHS[$index]}/g" Dockerfile.${arch}
    # Because arm is special
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
    docker build -f Dockerfile.${arch} -t ${IMAGE_NAME}:latest-${arch} -t ${IMAGE_NAME}:${TEEDY_VERS}-${arch} . --no-cache
    docker push ${IMAGE_NAME}:latest-${arch}
    docker push ${IMAGE_NAME}:${TEEDY_VERS}-${arch}
done

# Generate multi-arch manifests based on requested versions
for version in latest $TEEDY_VERS; do
    ALL_TAGS=''
    for arch in ${DOCKER_ARCHS[@]}; do
        ALL_TAGS+=${IMAGE_NAME}:${version}-${arch}' '
    done

    docker manifest create ${IMAGE_NAME}:${version} $ALL_TAGS
    for arch in ${DOCKER_ARCHS[@]}; do
        if [ ${arch} == 'arm32v7' ]; then
            docker manifest annotate ${IMAGE_NAME}:${version} ${IMAGE_NAME}:${version}-${arch} --os linux --arch arm
        elif [ ${arch} == 'arm64v8' ]; then
            docker manifest annotate ${IMAGE_NAME}:${version} ${IMAGE_NAME}:${version}-${arch} --os linux --arch arm64 --variant armv8
        fi
    done
    docker manifest push ${IMAGE_NAME}:${version}
    rm -r ~/.docker/manifests/docker.io_${IMAGE_NAME/'/'/'_'}-${version}
done
