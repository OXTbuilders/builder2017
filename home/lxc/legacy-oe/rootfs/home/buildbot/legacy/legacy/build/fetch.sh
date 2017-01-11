#!/bin/bash

BUILDID=$1

rm -rf /tmp/git_heads_$BUILDID
for i in git/*.git; do
    echo -n "Fetching `basename $i`: "
    cd $i
    git fetch --all > /dev/null 2>&1
    git log -1 --pretty='tformat:%H'
    cd - > /dev/null
done | tee /tmp/git_heads_$BUILDID
