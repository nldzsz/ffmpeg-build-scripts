#! /usr/bin/env bash

REMOTE_REPO=$1
LOCAL_WORKSPACE=$2
TARGET_VERSION=$3


if [ -z $LOCAL_WORKSPACE -o -z $TARGET_VERSION ]; then
    echo "invalid call pull-repo.sh '$LOCAL_WORKSPACE' '$TARGET_VERSION'"
    exit 1
fi

# 目录已经存在 则先删除
if [ -d $LOCAL_WORKSPACE/$TARGET_VERSION ]; then
    rm -rf $LOCAL_WORKSPACE/$TARGET_VERSION
fi

# 解压指定的.tar.xz文件
echo "== tar $TARGET_VERSION xz =="
cd $LOCAL_WORKSPACE
mkdir -p $TARGET_VERSION
tar -xvJf $TARGET_VERSION.tar.xz --strip-components 1 -C $TARGET_VERSION
cd -
echo "tar $TARGET_VERSION xz success"
