#! /usr/bin/env bash
#
# Copyright (C) 2013-2014 Bilibili
# Copyright (C) 2013-2014 Zhang Rui <bbcallen@gmail.com>
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

CONFIGURE_FLAGS="--enable-static --enable-shared --enable-pic --enable-nasm --with-pic "

# 源码目录;与编译脚本同级目录，编译的中间产物.o,.d也会在这里
SOURCE=
# 编译最终的输出目录；必须为绝对路径，否则生成的库不会到这里去
OUT=`pwd`/"android/build"
# 接受参数 作为编译平台
ARCH=$1
# 编译的API要求
target_API=$2

# 创建独立工具链
# 通过此种方式执行sh 文件中的export变量才有效。如果换成sh ./do-envbase-tool.sh $ARCH 则不行
. ./android/do-envbase-tool.sh $ARCH

echo "building fdk-aac $ARCH..."

SOURCE="android/forksource/fdk-aac-$ARCH"
cd $SOURCE

HOST=""
PREFIX=$OUT/fdk-aac-$ARCH

if [ "$ARCH" = "x86_64" ]
then
    HOST="x86_64-linux"
elif [ "$ARCH" = "armv7" ]
then
    HOST="arm-linux"
elif [ "$ARCH" = "arm64" ]
then
    HOST="aarch64-linux"
else
    HOST="arm-linux"
fi

echo "CONFIGURE_FLAGS:$CONFIGURE_FLAGS"
echo "sysroot:$FF_SYSROOT"
echo "prefix:$PREFIX"
echo "host:$HOST"

CFLAGS="${CFLAGS} --sysroot=${FF_SYSROOT} -I${FF_SYSROOT}/usr/include -I${FF_TOOLCHAIN_PATH}/include -D__ANDROID_API__=$FF_ANDROID_API"
CPPFLAGS="${CFLAGS}"
LDFLAGS="${LDFLAGS} -L${FF_SYSROOT}/usr/lib -L${FF_SYSROOT}/lib"

# fdk-aac的配置与ffmpeg不同，ffmpeg是通过--extra-cflags等参数来配置编译器参数的，这里是通过CFLAGS环境变量配置的
export CFLAGS
export CPPFLAGS
export LDFLAGS

# 效果和./configre .... 一样
./configure \
${CONFIGURE_FLAGS} \
--prefix=$PREFIX \
--host=$HOST || exit 1

make $FF_MAKE_FLAGS install
cd -
