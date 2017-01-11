#!/bin/bash 

set -ex

LAYERS=$1

OIFS=$IFS
IFS=','

#sed -i "s/  \"//g" build/conf/bblayers.conf
#sed -i "/^$/d" build/conf/bblayers.conf
head build/conf/bblayers.conf -n -3 > build/conf/bblayers.conf.tmp
mv build/conf/bblayers.conf.tmp build/conf/bblayers.conf
for trip in $LAYERS;
do
	LAYER_NAME=`echo $trip | cut -f 1 -d ':'`
	LAYER_REPO=`echo $trip | cut -f 2 -d ':'`
	LAYER_BRANCH=`echo $trip | cut -f 3 -d ':'`	
	echo "  \${TOPDIR}/repos/$LAYER_NAME \\" >> build/conf/bblayers.conf
	
	cd build/repos
	git clone -b $LAYER_BRANCH git://$LAYER_REPO
	cd ../../
	
done

echo "  \"" >> build/conf/bblayers.conf

IFS=$OIFS
