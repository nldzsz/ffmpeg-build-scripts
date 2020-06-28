#! /usr/bin/env bash

REMOTE_REPO=$1
LOCAL_WORKSPACE=$2
TARGET_VERSION=$3


if [ -z $REMOTE_REPO -o -z $LOCAL_WORKSPACE -o -z $TARGET_VERSION ]; then
    echo "invalid call pull-repo.sh '$REMOTE_REPO' '$LOCAL_WORKSPACE' '$TARGET_VERSION'"
    exit 1
elif [ ! -d $LOCAL_WORKSPACE/$TARGET_VERSION ]; then
    # 下载指定的.tar.gz文件
    echo "== download $TARGET_VERSION =="
    echo "url $REMOTE_REPO"
    cd $LOCAL_WORKSPACE
    #设置超时时间
    wget $REMOTE_REPO || exit 1
    tar zxf $TARGET_VERSION.tar.gz
    rm  $TARGET_VERSION.tar.gz
    cd -
    echo "download $TARGET_VERSION success"
else
    cd $LOCAL_WORKSPACE
    cd -
fi
