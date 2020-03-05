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

#----------
# modify for your build tool

labrry_name=mp3lame
CONFIGURE_FLAGS="--disable-shared --disable-frontend"



#ARCHS="arm64 x86_64 i386 armv7 armv7s"
ARCHS="arm64 x86_64"
# 当前编译脚本所在目录，源码与其在同级目录下
SHELL_ROOT_DIR=`pwd`
# 源码目录;与编译脚本同级目录，编译的中间产物.o,.d也会在这里
SOURCE=
# 编译最终的输出目录；必须为绝对路径，否则生成的库不会到这里去
OUT=`pwd`/"ios/build"

CWD=`pwd`

# 接受外部输入 $1代表编译平台 $2代表编译系统的最低版本要求
ARCH=$1
target_ios=$2
SOURCE=ios/forksource/$labrry_name-$ARCH

if [ "$1" = "clean" ]; then
    echo "=================="
    for ARCH in $ARCHS
    do
        echo "clean $labrry_name-$ARCH"
        echo "=================="
        cd $labrry_name-$ARCH && make clean && cd -
    done
    echo "clean build cache"
    echo "================="
    rm -rf build/$labrry_name-*
    rm -rf build/$labrry_name-*
    echo "clean success"
else
    echo "building lame $ARCH..."
    cd $SOURCE

    if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
    then
        PLATFORM="iPhoneSimulator"
        if [ "$ARCH" = "x86_64" ]
        then
            SIMULATOR="-mios-simulator-version-min=$target_ios"
            HOST=x86_64-apple-darwin
        else
            SIMULATOR="-mios-simulator-version-min=$target_ios"
            HOST=i386-apple-darwin
        fi
    else
        PLATFORM="iPhoneOS"
        SIMULATOR=
        HOST=arm-apple-darwin
    fi

    XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
    
    CC="xcrun -sdk $XCRUN_SDK clang -arch $ARCH"
    #AS="$CWD/$SOURCE/extras/gas-preprocessor.pl $CC"
    CFLAGS="-arch $ARCH $SIMULATOR -fembed-bitcode"
    CXXFLAGS="$CFLAGS"
    LDFLAGS="$CFLAGS"

    CC=$CC $CWD/$SOURCE/configure \
        CFLAGS="$CFLAGS" \
        LDFLAGS="$LDFLAGS" \
        $CONFIGURE_FLAGS \
        --host=$HOST \
        --prefix="$OUT/$labrry_name-$ARCH" \

    make -j3 install
    cd -
fi
