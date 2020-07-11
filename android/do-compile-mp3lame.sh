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

# with-pic=PIC 表示编译独立的代码，最好开启此选项，否则引入android时提示出错
CONFIGURE_FLAGS="--disable-frontend --with-pic=PIC"

# 源码目录;与编译脚本同级目录，编译的中间产物.o,.d也会在这里
SOURCE=
# 编译最终的输出目录；必须为绝对路径，否则生成的库不会到这里去
OUT=`pwd`/"android/build"
# 接受参数 作为编译平台
ARCH=$1
# 编译的API要求
target_API=$2

echo ""
echo "building mp3lame $ARCH..."
echo ""

# 创建独立工具链
# 通过此种方式执行sh 文件中的export变量才有效。如果换成sh ./do-envbase-tool.sh $ARCH 则不行
. ./android/do-envbase-tool.sh $ARCH


SOURCE="android/forksource/mp3lame-$ARCH"
cd $SOURCE

# 默认为编译动态库
shared_enable="--enable-shared=no"
static_enable="--enable-static=no"
# 默认生成动态库时会带版本号，这里通过匹配去掉了版本号
if [ $FF_COMPILE_SHARED == "TRUE" ];then
shared_enable="--enable-shared=yes"
fi
if [ $FF_COMPILE_STATIC == "TRUE" ];then
static_enable="--enable-static=yes"
fi
CONFIGURE_FLAGS="$CONFIGURE_FLAGS $shared_enable $static_enable"

CROSS_PREFIX=""
PREFIX=$OUT/mp3lame-$ARCH

if [ "$ARCH" = "x86_64" ]; then
    CROSS_PREFIX=x86_64-linux-android
elif [ "$ARCH" = "armv7a" ]; then
    CROSS_PREFIX=arm-linux-androideabi
elif [ "$ARCH" = "arm64" ]; then
    CROSS_PREFIX=aarch64-linux-android
else
    CROSS_PREFIX=arm-linux-androideabi
fi

echo "CONFIGURE_FLAGS:$CONFIGURE_FLAGS"
echo "sysroot:$FF_SYSROOT"
echo "cross-prefix:$CROSS_PREFIX"
echo "prefix:$PREFIX"

CFLAGS="--sysroot=${FF_SYSROOT} -I${FF_SYSROOT}/usr/include -I${FF_TOOLCHAIN_PATH}/include -D__ANDROID_API__=$FF_ANDROID_API -fPIC "
LDFLAGS="-L${FF_SYSROOT}/usr/lib -L${FF_SYSROOT}/lib"
if [ ! -z $FF_SYSROOT ];then
CFLAGS="-D__ANDROID_API__=$FF_ANDROID_API -fPIC "
LDFLAGS=""
fi
CPPFLAGS="${CFLAGS}"

# mp3lame的配置与ffmpeg不同，ffmpeg是通过--extra-cflags等参数来配置编译器参数的，这里是通过CFLAGS环境变量配置的
export CFLAGS
export CPPFLAGS
export LDFLAGS
export PKG_CONFIG_PATH=${TOOLCHAINS}/lib/pkgconfig

# 遇到问题：当编译过一次后改变编译参数不生效(先编译动态库，接着想添加静态库的编译，依然是编译的静态库)
# 解决方案：利用make clean刷新编译参数
make clean

# 效果和./configre .... 一样
./configure \
  ${CONFIGURE_FLAGS} \
  --prefix=$PREFIX \
  --host=$CROSS_PREFIX || exit 1
make $FF_MAKE_FLAGS install
cd -


