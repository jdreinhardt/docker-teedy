#!/usr/bin/env bash

# Image Configurations
IMAGE_NAME="jdreinhardt/teedy"
LATEST_TAG="latest"
VERS_TAG="1.9"
DATE_TAG=$(date +%Y%m%d)

# Enables multi-arch build support in buildx with a builder named xbuilder
# Set to false if xbuilder already exists with required arch support
CREATE_BUILDER='false'

BUILD_LATEST='true'
BUILD_VERS='true'
BUILD_DATE='true'
PUSH_BUILDS='true'

# Target Architectures. Current supported architectures:
# - linux/amd64
# - linux/386
# - linux/arm/v7
# - linux/arm64
# Coming eventually. (these will require a different source for ffmpeg)
# - linux/arm/v6
# - linux/ppc64le
# - linux/s390x
# - linux/riscv64
TARGETARCHS=(linux/amd64 linux/arm/v7 linux/arm64)

BUILD_TAGS=()

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
if [ ${PUSH_BUILDS} == 'false' ]; then
    if [ ${#TARGETARCHS[@]} -gt 1 ]; then
        echo -e "##\n##\e[31;3m ERROR: local build only requested with more than one architecture. Buildx currently only supports single architecture builds for local load\e[0m\n##"
        exit 1
    fi
fi
if [ -z $(docker buildx version | awk 'NR==1{print $1}') ]; then
    echo -e "##\n##\e[31;3m ERROR: buildx required for image build\e[0m\n##"
    exit 1
fi

# Print configuration details before build
clear
echo -e "## \e[1;3;4mTeedy Multi-architecture Docker Build Script\e[0m\n##"
echo -e "## \e[1mImage Name:\e[0m ${IMAGE_NAME}\n##"
echo -e "## \e[1mArchitectures to build:\e[0m"
for arch in ${TARGETARCHS[@]}; do
    echo -e "##\t- ${arch}"
done
echo -e "##\n## \e[1mTags to generate:\e[0m"
for tag in ${BUILD_TAGS[@]}; do
    echo -e "##\t- ${tag}"
done
echo -e "##\n## \e[1mPush Builds:\e[0m ${PUSH_BUILDS}"
echo -e "##\n## \e[31;3mVerify the above is correct. If not then press Ctrl-C now and update the script.\e[0m"
echo "##"
PAUSE=5
for (( i=${PAUSE}; i>=1; i--)) do
    echo -e "\r\033[1A\033[0K$@## \e[3mPausing for $i seconds...\e[0m"
    sleep 1
done

if [ ${CREATE_BUILDER} == 'true' ]; then
    # Enable multiarch build support locally
    echo -e "##\n## Enabling multiarch build support for Docker\n##"
    docker run --rm --privileged linuxkit/binfmt:v0.8

    # Configure Buildx builder
    echo -e "##\n## Configuring Buildx builder for build\n##"
    docker buildx rm xbuilder
    docker buildx create --name xbuilder
    docker buildx use xbuilder
    docker buildx inspect --bootstrap
fi

# Build the requested images
echo -e "##\n## Starting Docker build\n##"

# Build and push image
ALL_TAGS=''
for tag in ${BUILD_TAGS[@]}; do
    ALL_TAGS+='-t '${IMAGE_NAME}:${tag}' '
done
if [ ${PUSH_BUILDS} == "true" ]; then
    docker buildx build -f Dockerfile --platform=$(IFS=$','; echo "${TARGETARCHS[*]}") --push ${ALL_TAGS} . --no-cache
else 
    docker buildx build -f Dockerfile --platform=${TARGETARCHS[0]} --load ${ALL_TAGS} . --no-cache
fi
docker rmi $(docker images -q -f dangling=true)

echo -e "##\n## Complete!\n##"
