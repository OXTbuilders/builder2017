#!/bin/bash

BUILD_ID=$1
BRANCH=$2
LAYERS=$3
OVERRIDES=$4
ISSUE=$5
DISTRO=$6

umask 0022

LOCAL_USER=`whoami`
cd ~
LOCAL_HOME=`pwd`
cd - > /dev/null

if [ "${BRANCH}" = "None" ]; then
    BRANCH=master
fi

if [[ "$LAYERS"    = "None" ]] && \
   [[ "$OVERRIDES" = "None" ]] && \
   [[ "$ISSUE"     = "None" ]] && \
   [[ "$DISTRO"    = "None" ]]; then
    CUSTOM=0
#    NAME_SITE="oxt"
    echo "No override found, starting a regular build."
else
    CUSTOM=1
# TODO: stable-6 still has a site name, should we set it?
#    NAME_SITE="custom"
    echo "Override(s) found, starting a custom build."
fi

do_overrides () {
    for trip in $OVERRIDES; do
	name=$(echo $trip | cut -f 1 -d ':')
	git=$(echo $trip | cut -f 2 -d ':')
	branch=$(echo $trip | cut -f 3 -d ':')

	rm -rf /home/git/${LOCAL_USER}/$name.git
	git clone --mirror git://$git/$name /home/git/${LOCAL_USER}/$name.git
	# The following code will name the override $BRANCH, to match what we're building
	if [[ $branch != "${BRANCH}" ]]; then
	    pushd /home/git/${LOCAL_USER}/$name.git
	    # Avoid being on a releavant branch by moving the HEAD to a tmp branch
	    git branch tmp
	    git symbolic-ref HEAD refs/heads/tmp
	    # Move $BRANCH to a backup location (avoid removing it, since some branches can't be removed)
	    #   Do not fail if the branch doesn't exist, it can happen
	    git branch -m $BRANCH original$BRANCH || true
	    # Create a branch named $BRANCH out of the $branch requested by the override
	    git branch $BRANCH $branch
	    # Make $BRANCH the head of the repository
	    git symbolic-ref HEAD refs/heads/$BRANCH
	    popd
	fi
    done
}

rm -rf /home/git/${LOCAL_USER}/*

echo "Cloning all repos..."
for repo in `/home/shared/list_repos.sh`; do
    git clone --quiet --mirror https://github.com/OpenXT/${repo} /home/git/${LOCAL_USER}/${repo}.git
    # Handle overrides
    #   Note: It is against policy to set both $ISSUE and $OVERRIDES in the buildbot ui
    if [[ $ISSUE != 'None' && $OVERRIDES != 'None' ]]; then
	echo "Cannot pass both a Jira ticket and custom repository overrides to build from."
	exit -1
    elif [[ $ISSUE != 'None' && $OVERRIDES == 'None' ]]; then
	OVERRIDES=$( /home/shared/build_for_issue.sh $ISSUE )
    else
	echo "Building using method other than Jira ticket."
    fi
    OFS=$IFS
    IFS=','
    [ "$OVERRIDES" != "None" ] && do_overrides
    IFS=$OFS
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
    sed 's|sudo rm -rf /usr/src/\${tool}-1.0|sudo rm -rf /usr/src/${tool}-1.0 /var/lib/dkms/${tool}|' centos/build.sh
fi
# 4. stable-6 doesn't handle build IDs?!
if [[ $BRANCH = stable-6* ]]; then
    sed "s#^./do_build.sh | tee build.log$#./do_build.sh ${BUILD_ID} | tee build.log#" oe/build.sh
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

if [ $CUSTOM -eq 0 ]; then
    scp -r ~/xt-builds/${BUILD_ID} builds@144.217.69.51:/home/builds/regular/${BRANCH}/
else
    scp -r ~/xt-builds/${BUILD_ID} builds@144.217.69.51:/home/builds/custom/${BRANCH}/
fi
