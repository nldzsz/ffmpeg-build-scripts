#! /usr/bin/env bash

REMOTE_REPO=$1
LOCAL_WORKSPACE=$2
TARGET_VERSION=$3


if [ -z $REMOTE_REPO -o -z $LOCAL_WORKSPACE -o -z $TARGET_VERSION ]; then
    echo "invalid call pull-repo.sh '$REMOTE_REPO' '$LOCAL_WORKSPACE' '$TARGET_VERSION'"
    exit 1
fi

# 目录已经存在 则先删除
if [ -d $LOCAL_WORKSPACE/$TARGET_VERSION ]; then
    rm -rf $LOCAL_WORKSPACE/$TARGET_VERSION
fi

# 如果之前未下载完成，先删除残余
rm -rf $TARGET_VERSION.tar.xz
# 下载指定的.tar.xz文件
echo "== download $TARGET_VERSION xz =="
echo "wget $REMOTE_REPO"
cd $LOCAL_WORKSPACE
wget -O $TARGET_VERSION.tar.xz -c $REMOTE_REPO  || exit 1
mkdir -p $TARGET_VERSION
tar -xvJf $TARGET_VERSION.tar.xz --strip-components 1 -C $TARGET_VERSION
rm -rf $TARGET_VERSION.tar.xz
cd -
echo "download $TARGET_VERSION xz success"
