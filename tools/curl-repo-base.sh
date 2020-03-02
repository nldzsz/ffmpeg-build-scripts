#! /usr/bin/env bash

REMOTE_REPO=$1
LOCAL_WORKSPACE=$2
LOCAL_WORKSPACE_DIR=$3


if [ -z $REMOTE_REPO -o -z $LOCAL_WORKSPACE -o -z $LOCAL_WORKSPACE_DIR]; then
    echo "invalid call pull-repo.sh '$REMOTE_REPO' '$LOCAL_WORKSPACE' '$LOCAL_WORKSPACE_DIR'"
elif [ ! -d $LOCAL_WORKSPACE_DIR ]; then
    # 下载指定的.tar.gz文件
    echo "== download $LOCAL_WORKSPACE_DIR =="
    cd $LOCAL_WORKSPACE
    curl -O $REMOTE_REPO
    tar zxf $LOCAL_WORKSPACE_DIR.tar.gz
    rm  $LOCAL_WORKSPACE_DIR.tar.gz
    cd -
    echo "download $LOCAL_WORKSPACE_DIR success"
else
    cd $LOCAL_WORKSPACE
    cd -
fi
