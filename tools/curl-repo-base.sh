#! /usr/bin/env bash

REMOTE_REPO=$1
LOCAL_WORKSPACE=$2
TARGET_VERSION=$3


if [ -z $REMOTE_REPO -o -z $LOCAL_WORKSPACE -o -z $TARGET_VERSION ]; then
    echo "invalid call pull-repo.sh '$REMOTE_REPO' '$LOCAL_WORKSPACE' '$TARGET_VERSION'"
elif [ ! -d $LOCAL_WORKSPACE/$TARGET_VERSION ]; then
    # 下载指定的.tar.gz文件
    echo "== download $TARGET_VERSION =="
    cd $LOCAL_WORKSPACE
    curl -O $REMOTE_REPO
    tar zxf $TARGET_VERSION.tar.gz
    rm  $TARGET_VERSION.tar.gz
    cd -
    echo "download $TARGET_VERSION success"
else
    cd $LOCAL_WORKSPACE
    cd -
fi
