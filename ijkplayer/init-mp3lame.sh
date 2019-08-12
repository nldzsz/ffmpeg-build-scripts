#! /usr/bin/env bash
#
# Copyright (C) 2013-2015 Bilibili
# Copyright (C) 2013-2015 Zhang Rui <bbcallen@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


TARGET_VERSION=lame-3.100
IJK_UPSTREAM=https://jaist.dl.sourceforge.net/project/lame/lame/3.100/$TARGET_VERSION.tar.gz
DEST_EXTRA=extra
DEST_DIR=extra/$TARGET_VERSION
ARCHS="arm64 x86_64"

set -e
PLATPORM=$1
PLATPORM_build_dir=ios
if [ $1 == "android" ]; then
    PLATPORM_build_dir=android/contrib
fi
case $PLATPORM in
    "android"|"ios")
        echo "platmform is $PLATPORM"
    ;;
    *)
        echo "invalid platform, must be ios or android"
        exit 1
    ;;
esac

echo "== download lame =="
# 若没有下载过源代码
if [ ! -d $DEST_DIR ]; then
# 下载指定的.tar.gz文件
    cd $DEST_EXTRA
    curl -O $IJK_UPSTREAM
    tar zxf $TARGET_VERSION.tar.gz
    rm  $TARGET_VERSION.tar.gz
    cd -
    echo "download $DEST_DIR success"
fi

# 将源码拷贝到指定平台目录
for arch in $ARCHS
do
    if [ -d $PLATPORM_build_dir/mp3lame-$arch ]; then
        rm -rf $PLATPORM_build_dir/mp3lame-$arch
    fi

    cp -rf $DEST_DIR $PLATPORM_build_dir/mp3lame-$arch
done
