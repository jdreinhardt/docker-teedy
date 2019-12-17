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

IMAGE_NAME="jdreinhardt/teedy"
LATEST_TAG="latest"
VERS_TAG="1.8"
DATE_TAG=$(date +%Y%m%d)

BUILD_LATEST='true'
BUILD_VERS='true'
BUILD_DATE='true'
PUSH_BUILDS='true'
CREATE_MANIFESTS='true'

# Currently supported architectures are amd64, arm32v7, and arm64v8
DOCKER_ARCHS=(amd64 arm32v7 arm64v8)
CPU_ARCHS=()
BUILD_TAGS=()

for arch in ${DOCKER_ARCHS[@]}; do
    case $arch in
    amd64     ) CPU_ARCHS+=(amd64) ;;
    arm32v7   ) CPU_ARCHS+=(armhf) ;;
    arm64v8   ) CPU_ARCHS+=(arm64) ;;
    esac
done


if [ ${BUILD_LATEST} == 'true' ]; then
    if [ ! -z ${LATEST_TAG} ]; then
        BUILD_TAGS+=($LATEST_TAG);
    else   
        echo -e "##\n##\e[31;3m ERROR: latest build requested, but tag label not set\e[0m\n##"
        exit 1
    fi
fi
if [ ${BUILD_VERS} == 'true' ]; then
    if [ -n ${VERS_TAG} ]; then
        BUILD_TAGS+=($VERS_TAG);
    else   
        echo -e "##\n##\e[31;3m ERROR: version build requested, but tag label not set\e[0m\n##"
        exit 1
    fi
fi
if [ ${BUILD_DATE} == 'true' ]; then
    if [ -n ${DATE_TAG} ]; then
        BUILD_TAGS+=($DATE_TAG);
    else   
        echo -e "##\n##\e[31;3m ERROR: date build requested, but tag label not set\e[0m\n##"
        exit 1
    fi
fi
if [ ${CREATE_MANIFESTS} == 'true' ]; then
    if [ ${PUSH_BUILDS} == 'false' ]; then
        echo -e "##\n##\e[31;3m ERROR: manifest build requested, but build push is false\e[0m\n##"
        exit 1
    fi
fi

# Print configuration details before build
clear
echo -e "## \e[1;3;4mTeedy Multi-architecture Docker Build Script\e[0m\n##"
echo -e "## \e[1mImage Name:\e[0m ${IMAGE_NAME}\n##"
echo -e "## \e[1mArchitectures to build:\e[0m"
for arch in ${DOCKER_ARCHS[@]}; do
    echo -e "##\t- ${arch}"
done
echo -e "##\n## \e[1mTags to generate:\e[0m"
for tag in ${BUILD_TAGS[@]}; do
    echo -e "##\t- ${tag}"
done
echo -e "##\n## \e[1mPush Builds:\e[0m ${PUSH_BUILDS}"
echo -e "## \e[1mPush Manifests:\e[0m ${CREATE_MANIFESTS}"
echo -e "##\n## \e[31;3mVerify the above is correct. If not then press Ctrl-C now and update the script.\e[0m"
echo "##"
PAUSE=5
for (( i=${PAUSE}; i>=1; i--)) do
    echo -e "\r\033[1A\033[0K$@## \e[3mPausing for $i seconds...\e[0m"
    sleep 1
done

# Enable multiarch build support locally
echo -e "##\n## Enabling multiarch build support for Docker\n##"
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Build the requested images
echo -e "##\n## Starting Docker build\n##"
for arch in ${DOCKER_ARCHS[@]}; do
    # Correlate Docker and CPU architectures for build args
    echo -e "##\n## Now building ${IMAGE_NAME} for ${arch}\n##"
    for index in "${!DOCKER_ARCHS[@]}"; do
        [[ "${DOCKER_ARCHS[$index]}" = "${arch}" ]] && break
    done
    cpu_arch="${CPU_ARCHS[index]}"

    # Build and push image
    ALL_TAGS=''
    for tag in ${BUILD_TAGS[@]}; do
        ALL_TAGS+='-t '${IMAGE_NAME}:${tag}-${arch}' '
    done
    docker build -f Dockerfile --build-arg DOCKER_ARCHITECTURE=${arch} --build-arg CPU_ARCHITECTURE=${cpu_arch} ${ALL_TAGS} . --no-cache
    docker rmi $(docker images -q -f dangling=true)
    if [ ${PUSH_BUILDS} == 'true' ]; then
        for tag in ${BUILD_TAGS[@]}; do 
            docker push ${IMAGE_NAME}:${tag}-${arch}
        done
    fi
done

# Generate multi-arch manifests based on requested versions
if [ ${CREATE_MANIFESTS} == 'true' ]; then
    if [ ${PUSH_BUILDS} != 'true' ]; then
        echo -e "##\n## Create manifest is true, but images were not pushed\n##"
        exit 1
    else
        echo -e "##\n## Generating Docker manifests\n##"
        for version in ${BUILD_TAGS[@]}; do
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
    fi
fi
echo -e "##\n## Complete!\n##"