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

# This script is based on projects below
# https://github.com/kolyvan/kxmovie
# https://github.com/yixia/FFmpeg-Android
# http://git.videolan.org/?p=vlc-ports/android.git;a=summary
# https://github.com/kewlbear/FFmpeg-iOS-build-script/

#--------------------
echo "===================="
echo "[*] check host"
echo "===================="
# 当脚本执行出现错误时，直接退出脚本的执行
set -e

#--------------------
# include


#--------------------
# common defines
FF_ARCH=$1
FF_BUILD_OPT=$2
echo "FF_ARCH=$FF_ARCH"
echo "FF_BUILD_OPT=$FF_BUILD_OPT"
if [ -z "$FF_ARCH" ]; then
    echo "You must specific an architecture 'armv7, armv7s, arm64, i386, x86_64, ...'.\n"
    exit 1
fi


FF_BUILD_ROOT=`pwd`
FF_TAGET_OS="darwin"

# ---shell 中export、bash、source的区别
# export可新增，修改或删除环境变量，供后续执行的程序使用。同时，重要的一点是，export的效力仅及
# 于该次登陆操作。注销或者重新开一个窗口，export命令给出的环境变量都不存在了。
# export -n 变量 表示删除环境变量中的指定变量
# bash是用来执行shell脚本的;bash filename;sh filename;./filename三者都是用来执行filename
# 指定文件的命令;区别是bash/sh命令下，filename文件可以无"执行权限";对于./命令,filename文件
# 必须要有执行权限
# source和前一个等同,用于执行文件中命令,如：source filename;. filename，无需执行权限
# ffmpeg build params
# 这里先导入环境变量COMMON_FF_CFG_FLAGS,然后执行config/module.sh并为该变量赋值
export COMMON_FF_CFG_FLAGS=
source $FF_BUILD_ROOT/../config/module.sh

# FFMPEG_CFG_FLAGS变量的配置最终都会作为./configure 命令的输入参数
# 最终会将变量COMMON_FF_CFG_FLAGS的值导入到变量FFMPEG_CFG_FLAGS中
FFMPEG_CFG_FLAGS=
FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS $COMMON_FF_CFG_FLAGS"

# Optimization options (experts only):
# FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --disable-armv5te"
# FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --disable-armv6"
# FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --disable-armv6t2"

# Advanced options (experts only):
#--enable-cross-compile: 交叉编译(要编译ios平台的ffmpeg，则必须使用该选项)
FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --enable-cross-compile"
# --disable-symver may indicate a bug
# FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --disable-symver"

# Developer options (useful when working on FFmpeg itself):
# 开发阶段可以开启，正式版关闭
FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --disable-stripping"

# --arch:CPU平台架构类型
# --target-os:目标系统->darwin(mac系统早起版本名字)
# --enable-static:编译静态库(.a)
# --disable-shared:不编译共享库(.so)
FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --arch=$FF_ARCH"
FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --target-os=$FF_TAGET_OS"
FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --enable-static"
FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --disable-shared"
FFMPEG_EXTRA_CFLAGS=

# i386, x86_64
FFMPEG_CFG_FLAGS_SIMULATOR=
FFMPEG_CFG_FLAGS_SIMULATOR="$FFMPEG_CFG_FLAGS_SIMULATOR --disable-asm"
FFMPEG_CFG_FLAGS_SIMULATOR="$FFMPEG_CFG_FLAGS_SIMULATOR --disable-mmx"
FFMPEG_CFG_FLAGS_SIMULATOR="$FFMPEG_CFG_FLAGS_SIMULATOR --assert-level=2"

# armv7, armv7s, arm64
FFMPEG_CFG_FLAGS_ARM=
FFMPEG_CFG_FLAGS_ARM="$FFMPEG_CFG_FLAGS_ARM --enable-pic"
FFMPEG_CFG_FLAGS_ARM="$FFMPEG_CFG_FLAGS_ARM --enable-neon"

# *)代表任意值，可以是空或者出debug外的任意值;
# 这里用于编译debug阶段和正式版阶段的优化选项
case "$FF_BUILD_OPT" in
    debug)
        FFMPEG_CFG_FLAGS_ARM="$FFMPEG_CFG_FLAGS_ARM --disable-optimizations"
        FFMPEG_CFG_FLAGS_ARM="$FFMPEG_CFG_FLAGS_ARM --enable-debug"
        FFMPEG_CFG_FLAGS_ARM="$FFMPEG_CFG_FLAGS_ARM --disable-small"
    ;;
    *)
        FFMPEG_CFG_FLAGS_ARM="$FFMPEG_CFG_FLAGS_ARM --enable-optimizations"
        FFMPEG_CFG_FLAGS_ARM="$FFMPEG_CFG_FLAGS_ARM --enable-debug"
        FFMPEG_CFG_FLAGS_ARM="$FFMPEG_CFG_FLAGS_ARM --enable-small"
    ;;
esac

echo "build_root: $FF_BUILD_ROOT"

#--------------------
echo "===================="
echo "[*] check gas-preprocessor"
echo "===================="
FF_TOOLS_ROOT="$FF_BUILD_ROOT/../extra"
export PATH="$FF_TOOLS_ROOT/gas-preprocessor:$PATH"

echo "gasp: $FF_TOOLS_ROOT/gas-preprocessor/gas-preprocessor.pl"

#--------------------
echo "===================="
echo "[*] config arch $FF_ARCH"
echo "===================="

FF_BUILD_NAME="unknown"
FF_XCRUN_PLATFORM="iPhoneOS"
FF_XCRUN_OSVERSION=
FF_GASPP_EXPORT=
FF_DEP_OPENSSL_INC=
FF_DEP_OPENSSL_LIB=
FF_XCODE_BITCODE=

if [ "$FF_ARCH" = "i386" ]; then
    FF_BUILD_NAME="ffmpeg-i386"
    FF_BUILD_NAME_OPENSSL=openssl-i386
    FF_BUILD_NAME_X264=x264-i386
    FF_XCRUN_PLATFORM="iPhoneSimulator"
    FF_XCRUN_OSVERSION="-mios-simulator-version-min=10.0"
    FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS $FFMPEG_CFG_FLAGS_SIMULATOR"
elif [ "$FF_ARCH" = "x86_64" ]; then
    FF_BUILD_NAME="ffmpeg-x86_64"
    FF_BUILD_NAME_OPENSSL=openssl-x86_64
    FF_BUILD_NAME_X264=x264-x86_64
    FF_XCRUN_PLATFORM="iPhoneSimulator"
    FF_XCRUN_OSVERSION="-mios-simulator-version-min=10.0"
    FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS $FFMPEG_CFG_FLAGS_SIMULATOR"
elif [ "$FF_ARCH" = "armv7" ]; then
    FF_BUILD_NAME="ffmpeg-armv7"
    FF_BUILD_NAME_OPENSSL=openssl-armv7
    FF_BUILD_NAME_X264=x264-armv7
    FF_XCRUN_OSVERSION="-miphoneos-version-min=10.0"
    FF_XCODE_BITCODE="-fembed-bitcode"
    FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS $FFMPEG_CFG_FLAGS_ARM"
#    FFMPEG_CFG_CPU="--cpu=cortex-a8"
elif [ "$FF_ARCH" = "armv7s" ]; then
    FF_BUILD_NAME="ffmpeg-armv7s"
    FF_BUILD_NAME_OPENSSL=openssl-armv7s
    FF_BUILD_NAME_X264=x264-armv7s
    FFMPEG_CFG_CPU="--cpu=swift"
    FF_XCRUN_OSVERSION="-miphoneos-version-min=10.0"
    FF_XCODE_BITCODE="-fembed-bitcode"
    FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS $FFMPEG_CFG_FLAGS_ARM"
elif [ "$FF_ARCH" = "arm64" ]; then
    FF_BUILD_NAME="ffmpeg-arm64"
    FF_BUILD_NAME_OPENSSL=openssl-arm64
    FF_BUILD_NAME_X264=x264-arm64
    FF_XCRUN_OSVERSION="-miphoneos-version-min=10.0"
    FF_XCODE_BITCODE="-fembed-bitcode"
    FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS $FFMPEG_CFG_FLAGS_ARM"
    FF_GASPP_EXPORT="GASPP_FIX_XCODE5=1"
else
    echo "unknown architecture $FF_ARCH";
    exit 1
fi

echo "build_name: $FF_BUILD_NAME"
echo "platform:   $FF_XCRUN_PLATFORM"
echo "osversion:  $FF_XCRUN_OSVERSION"

#--------------------
echo "===================="
echo "[*] make ios toolchain $FF_BUILD_NAME"
echo "===================="

FF_BUILD_SOURCE="$FF_BUILD_ROOT/forksource/$FF_BUILD_NAME"
FF_BUILD_PREFIX="$FF_BUILD_ROOT/build/$FF_BUILD_NAME/output"
#--prefix：静态库输出目录
FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --prefix=$FF_BUILD_PREFIX"

mkdir -p $FF_BUILD_PREFIX

echo "build_source: $FF_BUILD_SOURCE"
echo "build_prefix: $FF_BUILD_PREFIX"

#--------------------
#tr命令可以对来自标准输入的字符进行替换、压缩和删除
#'[:upper:]'->将小写转成大写
#'[:lower:]'->将大写转成小写
#将platform->转成大写或者小写
# xcrun -sdk $FF_XCRUN_SDK clang表示使用clang作为ffmpeg的编译器
# xcrun 做的是定位到 clang，并执行它，附带输入 clang 后面的参数
# -sdk 表示参数表示选择的平台是iPhoneSimulator还是iPhoneOS
echo "\n--------------------"
echo "[*] configurate ffmpeg"
echo "--------------------"
FF_XCRUN_SDK=`echo $FF_XCRUN_PLATFORM | tr '[:upper:]' '[:lower:]'`
FF_XCRUN_CC="xcrun -sdk $FF_XCRUN_SDK clang"

FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS $FFMPEG_CFG_CPU"

FFMPEG_CFLAGS=
FFMPEG_CFLAGS="$FFMPEG_CFLAGS -arch $FF_ARCH"
FFMPEG_CFLAGS="$FFMPEG_CFLAGS $FF_XCRUN_OSVERSION"
FFMPEG_CFLAGS="$FFMPEG_CFLAGS $FFMPEG_EXTRA_CFLAGS"
FFMPEG_CFLAGS="$FFMPEG_CFLAGS $FF_XCODE_BITCODE"
FFMPEG_LDFLAGS="$FFMPEG_CFLAGS"
FFMPEG_DEP_LIBS=

# 外部库
EXT_LIBS="ssl x264 fdk-aac mp3lame"
for lib in $EXT_LIBS
do
    echo "\n--------------------"
    echo "[*] check $lib"
    echo "----------------------"
    FF_BUILD_NAME=$lib-$FF_ARCH

    FFMPEG_DEP_INC=$FF_BUILD_ROOT/build/$FF_BUILD_NAME/output/include
    FFMPEG_DEP_LIB=$FF_BUILD_ROOT/build/$FF_BUILD_NAME/output/lib

    ENABLE_FLAGS=
    LD_FLAGS=
    if [ $lib = "ssl" ]; then
        ENABLE_FLAGS="--enable-openssl"
    LD_FLAGS="-lssl -lcrypto"
    fi
    # 这里必须要--enable-encoder --enable-decoder的方式开启libx264，libfdk_aac，libmp3lame
    # 否则外部库无法加载到ffmpeg中
    if [ $lib = "x264" ]; then
        ENABLE_FLAGS="--enable-gpl --enable-libx264 --enable-encoder=libx264 --enable-decoder=h264"
    fi

    if [ $lib = "fdk-aac" ]; then
        ENABLE_FLAGS="--enable-nonfree --enable-libfdk-aac --enable-encoder=libfdk_aac --enable-decoder=libfdk_aac"
    fi

    if [ $lib = "mp3lame" ]; then
        ENABLE_FLAGS="--enable-libmp3lame --enable-encoder=libmp3lame --enable-decoder=libmp3lame"
    fi

    if [ -f "${FFMPEG_DEP_LIB}/lib$lib.a" ]; then
        FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS $ENABLE_FLAGS"

        FFMPEG_CFLAGS="$FFMPEG_CFLAGS -I${FFMPEG_DEP_INC}"
        FFMPEG_DEP_LIBS="$FFMPEG_DEP_LIBS -L${FFMPEG_DEP_LIB} $LD_FLAGS"
    fi
done

#--------------------
echo "\n--------------------"
echo "[*] configure"
echo "----------------------"

if [ ! -d $FF_BUILD_SOURCE ]; then
    echo ""
    echo "!! ERROR"
    echo "!! Can not find FFmpeg directory for $FF_BUILD_NAME"
    echo "!! Run 'sh init-ios.sh' first"
    echo ""
    exit 1
fi

# xcode configuration
export DEBUG_INFORMATION_FORMAT=dwarf-with-dsym

cd $FF_BUILD_SOURCE
if [ -f "./config.h" ]; then
    echo 'reuse configure'
else
    echo "config: $FFMPEG_CFG_FLAGS $FFMPEG_CFG_CPU --extra-cflags:$FFMPEG_CFLAGS --extra-ldflags:$FFMPEG_LDFLAGS $FFMPEG_DEP_LIBS $FF_XCRUN_CC "
    ./configure \
        $FFMPEG_CFG_FLAGS \
        --cc="$FF_XCRUN_CC" \
        $FFMPEG_CFG_CPU \
        --extra-cflags="$FFMPEG_CFLAGS" \
        --extra-cxxflags="$FFMPEG_CFLAGS" \
        --extra-ldflags="$FFMPEG_LDFLAGS $FFMPEG_DEP_LIBS"
    make clean
fi

#--------------------
echo "\n--------------------"
echo "[*] compile ffmpeg"
echo "--------------------"
cp config.* $FF_BUILD_PREFIX
make -j3 $FF_GASPP_EXPORT
make install
mkdir -p $FF_BUILD_PREFIX/include/libffmpeg
cp -f config.h $FF_BUILD_PREFIX/include/libffmpeg/config.h
