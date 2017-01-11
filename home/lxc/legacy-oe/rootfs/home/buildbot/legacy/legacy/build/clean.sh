#!/bin/bash

umask 0022
rm -rf build
mkdir build

# Reset git mirrors to stock, to revert overrides
mv git git.old
mkdir git
for repo in `ls git.old`; do
    git clone --mirror git://github.com/openxt/$repo git/$repo
done
rm -rf git.old
