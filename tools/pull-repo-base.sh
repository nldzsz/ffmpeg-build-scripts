#! /usr/bin/env bash

REMOTE_REPO=$1
LOCAL_WORKSPACE=$2


if [ -z $REMOTE_REPO -o -z $LOCAL_WORKSPACE ]; then
    echo "invalid call pull-repo.sh '$REMOTE_REPO' '$LOCAL_WORKSPACE'"
    exit 1
elif [ ! -d $LOCAL_WORKSPACE ]; then
    git clone $REMOTE_REPO $LOCAL_WORKSPACE || exit 1
else
    cd $LOCAL_WORKSPACE
    git fetch --all --tags || exit 1
    cd -
fi
