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

# 要编译的版本 这里也可以修改版本号
TARGET_VERSION=fdk-aac-2.0.0
IJK_UPSTREAM=https://jaist.dl.sourceforge.net/project/opencore-amr/fdk-aac/$TARGET_VERSION.tar.gz
DEST_EXTRA=extra
DEST_DIR=extra/$TARGET_VERSION

set -e

# $1 编译平台 $2 平台对应的cpu架构类型集合 $3源码fork到本地的路径
PLATPORM=$1
ARCHS=$2
PLATPORM_build_dir=$3

echo "== download fdk_aac =="
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
    if [ -d $PLATPORM_build_dir/fdk-aac-$arch ]; then
        rm -rf $PLATPORM_build_dir/fdk-aac-$arch
    fi

    cp -rf $DEST_DIR $PLATPORM_build_dir/fdk-aac-$arch
done







