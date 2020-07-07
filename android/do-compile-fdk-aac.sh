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

CONFIGURE_FLAGS="--with-pic "

# 源码目录;与编译脚本同级目录，编译的中间产物.o,.d也会在这里
SOURCE=
# 编译最终的输出目录；必须为绝对路径，否则生成的库不会到这里去
OUT=`pwd`/"android/build"
# 接受参数 作为编译平台
ARCH=$1
# 编译的API要求
target_API=$2

echo ""
echo "building fdk-aac $ARCH..."
echo ""

# 创建独立工具链
# 通过此种方式执行sh 文件中的export变量才有效。如果换成sh ./do-envbase-tool.sh $ARCH 则不行
. ./android/do-envbase-tool.sh $ARCH

SOURCE="android/forksource/fdk-aac-$ARCH"
cd $SOURCE
# 默认为编译动态库;fdk_aac 这个选项无效
shared_enable="--enable-shared"
static_enable=""
# 默认生成动态库时会带版本号，这里通过匹配去掉了版本号
if [ $FF_COMPILE_SHARED != "TRUE" ];then
shared_enable=""
fi
if [ $FF_COMPILE_STATIC == "TRUE" ];then
static_enable="--enable-static"
fi
CONFIGURE_FLAGS="$CONFIGURE_FLAGS $shared_enable $static_enable"

HOST=""
PREFIX=$OUT/fdk-aac-$ARCH

if [ "$ARCH" = "x86_64" ]
then
    HOST="x86_64-linux"
elif [ "$ARCH" = "armv7a" ]
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

CFLAGS="--sysroot=${FF_SYSROOT} -I${FF_SYSROOT}/usr/include -I${FF_TOOLCHAIN_PATH}/include -D__ANDROID_API__=$FF_ANDROID_API"
LDFLAGS="-L${FF_SYSROOT}/usr/lib -L${FF_SYSROOT}/lib"
if [ ! -z $FF_SYSROOT ];then
CFLAGS="-D__ANDROID_API__=$FF_ANDROID_API"
LDFLAGS=""
fi
CPPFLAGS="${CFLAGS}"


# fdk-aac的配置与ffmpeg不同，ffmpeg是通过--extra-cflags等参数来配置编译器参数的，这里是通过CFLAGS环境变量配置的
export CFLAGS
export CPPFLAGS
export LDFLAGS

# 遇到问题：Linux下编译时提示"error: version mismatch.  This is Automake 1.15.1"
# 分析原因：fdk-aac自带的生成的configure.ac和Linux系统的Automake不符合
# 解决方案：命令autoreconf重新配置configure.ac即可

UNAME_S=$(uname -s)
if [ $UNAME_S == "Linux" ];then
autoreconf
fi
# 效果和./configre .... 一样
./configure \
${CONFIGURE_FLAGS} \
--prefix=$PREFIX \
--host=$HOST || exit 1

make $FF_MAKE_FLAGS install
cd -
