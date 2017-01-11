#!/bin/bash

BUILDID=$1
BRANCH=$2

umask 0022

cd build/openxt

cp git_heads build-output/*-dev-${BUILDID}-${BRANCH}/
./do_build.sh -i $BUILDID -s xctools,ship,extra_pkgs,copy,packages_tree
ret=$?
if [ $ret -ne 0 ]; then
	echo Failed
	exit $ret
fi
echo The build is done and copied to the main server.

# Not running sync_cache_back

cd ../..

rm -rf last_build
mv build last_build
