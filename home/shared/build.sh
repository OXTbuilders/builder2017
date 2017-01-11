#!/bin/bash

BUILD_ID=$1
BRANCH=$2

umask 0022

LOCAL_USER=`whoami`
cd ~
LOCAL_HOME=`pwd`
cd - > /dev/null

if [ "${BRANCH}" = "None" ]; then
    BRANCH=master
fi

rm -rf /home/git/${LOCAL_USER}/*

echo "Cloning all repos..."
for repo in `/home/shared/list_repos.sh`; do
    git clone --quiet --mirror https://github.com/OpenXT/${repo} /home/git/${LOCAL_USER}/${repo}.git
    # TODO: overrides
done

rm -rf openxt
git clone -b ${BRANCH} file:///home/git/${LOCAL_USER}/openxt.git

cd openxt/build-scripts

# Modifying the build-scripts the way setup.sh would.
# Change the following if setup.sh changes
sed -i "s|\%CONTAINER_USER\%|build|"    build.sh
sed -i "s|\%SUBNET_PREFIX\%|172.21|"    build.sh
# No clean.sh in stable-6
if [[ $BRANCH != stable-6* ]]; then
    sed -i "s|\%CONTAINER_USER\%|build|"    clean.sh
    sed -i "s|\%SUBNET_PREFIX\%|172.21|"    clean.sh
fi
sed -i "s|\%GIT_ROOT_PATH\%|/home/git|" fetch.sh
cp ../version .

# Doing custom modifications to the scripts
# Hopefully we can keep it to a minimum
# 1. we just have one shared Windows VM, no per-user one
sed -i "s|^IP=.*$|IP=windows|"          windows/build.sh
# 2. we're running in a subdir here, not in ~, tell everybody
sed -i "s|^ALL_BUILDS_SUBDIR_NAME=|ALL_BUILDS_SUBDIR_NAME=${LOCAL_HOME}/|" oe/build.sh
sed -i "s|^ALL_BUILDS_SUBDIR_NAME=|ALL_BUILDS_SUBDIR_NAME=${LOCAL_HOME}/|" debian/build.sh
sed -i "s|^ALL_BUILDS_SUBDIR_NAME=|ALL_BUILDS_SUBDIR_NAME=${LOCAL_HOME}/|" centos/build.sh
sed -i "s|^DEST=|DEST=${LOCAL_HOME}/|" windows/build.sh
# 3. stable-6 doesn't remove the dkms stuff properly in centos
if [[ $BRANCH = stable-6* ]]; then
    sed 's|sudo rm -rf /usr/src/\${tool}-1.0|sudo rm -rf /usr/src/${tool}-1.0 /var/lib/dkms/${tool}|'
fi

# Remove all builds in oe container before starting a new one
echo "Removing old build(s)..."
ssh oe "rm -rf [0-9]*"

# Build
echo "Starting the build"
if [[ $BRANCH = stable-6* ]]; then
    # stable-6 still uses do_build.sh and supports only one option (BUILD_ID)
    sed -i "s|^BRANCH=.*$|BRANCH=${BRANCH}|" build.sh
    ./build.sh ${BUILD_ID}
else
    ./build.sh -j 12 -i ${BUILD_ID} -b ${BRANCH}
fi

cd - > /dev/null

scp -r ~/xt-builds/${BUILD_ID} builds@144.217.69.51:/home/builds/regular/${BRANCH}/
