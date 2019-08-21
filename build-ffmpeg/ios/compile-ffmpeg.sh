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

# 由于目前设备基本都是电脑64位 手机64位 所以这里脚本默认只支持 arm64 x86_64两个平台
# FF_ALL_ARCHS="armv7 armv7s arm64 i386 x86_64"
FF_ALL_ARCHS="arm64 x86_64"
target_ios=10.0

# 是否将这些外部库添加进去;如果不添加 则将对应的值改为FALSE即可；默认添加三个库
lIBS=(x264 fdk-aac mp3lame)
LIBFLAGS=(TRUE TRUE TRUE)

#----------
UNI_BUILD_ROOT=`pwd`
UNI_TMP="$UNI_BUILD_ROOT/tmp"
UNI_TMP_LLVM_VER_FILE="$UNI_TMP/llvm.ver.txt"
FF_TARGET=$1
FF_TARGET_EXTRA=$2
set -e
#----------

echo_archs() {
    echo "===================="
    echo "[*] check xcode version"
    echo "===================="
    echo "FF_ALL_ARCHS = $FF_ALL_ARCHS"
}

FF_LIBS="libavcodec libavfilter libavformat libavutil libswscale libswresample"
do_lipo_ffmpeg () {
    LIB_FILE=$1
    LIPO_FLAGS=
    for ARCH in $FF_ALL_ARCHS
    do
        ARCH_LIB_FILE="$UNI_BUILD_ROOT/build/ffmpeg-$ARCH/output/lib/$LIB_FILE"
        if [ -f "$ARCH_LIB_FILE" ]; then
            LIPO_FLAGS="$LIPO_FLAGS $ARCH_LIB_FILE"
        else
            echo "skip $LIB_FILE of $ARCH";
        fi
    done

    xcrun lipo -create $LIPO_FLAGS -output $UNI_BUILD_ROOT/build/universal/lib/$LIB_FILE
    xcrun lipo -info $UNI_BUILD_ROOT/build/universal/lib/$LIB_FILE
}

EXT_LIBS="crypto ssl fdk-aac mp3lame x264"
do_lipo_lib () {
    LIB=$1
    LIB_FILE=lib$LIB.a
    LIPO_FLAGS=
    for ARCH in $FF_ALL_ARCHS
    do
        ARCH_LIB_FILE="$UNI_BUILD_ROOT/build/$LIB-$ARCH/output/lib/$LIB_FILE"
        if [ -f "$ARCH_LIB_FILE" ]; then
            LIPO_FLAGS="$LIPO_FLAGS $ARCH_LIB_FILE"
        else
            echo "skip $LIB_FILE of $ARCH";
        fi
    done

    if [ "$LIPO_FLAGS" != "" ]; then
        xcrun lipo -create $LIPO_FLAGS -output $UNI_BUILD_ROOT/build/universal/lib/$LIB_FILE
        xcrun lipo -info $UNI_BUILD_ROOT/build/universal/lib/$LIB_FILE
    fi
}

do_lipo_all () {
    mkdir -p $UNI_BUILD_ROOT/build/universal/lib
    echo "lipo archs: $FF_ALL_ARCHS"
    for FF_LIB in $FF_LIBS
    do
        do_lipo_ffmpeg "$FF_LIB.a";
    done

    ANY_ARCH=
    for ARCH in $FF_ALL_ARCHS
    do
        ARCH_INC_DIR="$UNI_BUILD_ROOT/build/ffmpeg-$ARCH/output/include"
        if [ -d "$ARCH_INC_DIR" ]; then
            if [ -z "$ANY_ARCH" ]; then
                ANY_ARCH=$ARCH
                cp -R "$ARCH_INC_DIR" "$UNI_BUILD_ROOT/build/universal/"
            fi

            UNI_INC_DIR="$UNI_BUILD_ROOT/build/universal/include"

            mkdir -p "$UNI_INC_DIR/libavutil/$ARCH"
            cp -f "$ARCH_INC_DIR/libavutil/avconfig.h"  "$UNI_INC_DIR/libavutil/$ARCH/avconfig.h"
            cp -f tools/avconfig.h                      "$UNI_INC_DIR/libavutil/avconfig.h"
            cp -f "$ARCH_INC_DIR/libavutil/ffversion.h" "$UNI_INC_DIR/libavutil/$ARCH/ffversion.h"
            cp -f tools/ffversion.h                     "$UNI_INC_DIR/libavutil/ffversion.h"
            # 引用 ijkplayer 暂时不知道撒用 先屏蔽
            # mkdir -p "$UNI_INC_DIR/libffmpeg/$ARCH"
            # cp -f "$ARCH_INC_DIR/libffmpeg/config.h"    "$UNI_INC_DIR/libffmpeg/$ARCH/config.h"
            # cp -f tools/config.h                        "$UNI_INC_DIR/libffmpeg/config.h"
        fi
    done

    for EXT_LIB in $EXT_LIBS
    do
        do_lipo_lib "$EXT_LIB";
    done
}

# 配置外部库
function config_external_lib()
{
    

    for(( i=0;i<${#lIBS[@]};i++)) 
    do
        #${#array[@]}获取数组长度用于循环
        lib=${lIBS[i]};
        for FF_ARCH in $FF_ALL_ARCHS 
        do
            FF_BUILD_NAME=$lib-$FF_ARCH
            FFMPEG_DEP_LIB=$UNI_BUILD_ROOT/build/$FF_BUILD_NAME/output/lib

            if [[ ${LIBFLAGS[i]} == "TRUE" ]]; then
                if [ ! -f "${FFMPEG_DEP_LIB}/lib$lib.a" ]; then
                    # 编译
                    sh tools/do-compile-$lib.sh $FF_ARCH $target_ios
                fi
            else
                if [ -f "${FFMPEG_DEP_LIB}/lib$lib.a" ]; then
                    # 删除 该库
                    rm "${FFMPEG_DEP_LIB}/lib$lib.a"
                fi
            fi
        done;
    done;
}

#----------
if [ "$FF_TARGET" = "armv7" -o "$FF_TARGET" = "armv7s" -o "$FF_TARGET" = "arm64" ]; then
    # 先编译外部库
    config_external_lib
    sh tools/do-compile-ffmpeg.sh $FF_TARGET $FF_TARGET_EXTRA
    do_lipo_all
elif [ "$FF_TARGET" = "i386" -o "$FF_TARGET" = "x86_64" ]; then
    # 先编译外部库
    config_external_lib
    sh tools/do-compile-ffmpeg.sh $FF_TARGET $FF_TARGET_EXTRA
    do_lipo_all
elif [ "$FF_TARGET" = "lipo" ]; then
    do_lipo_all
elif [ "$FF_TARGET" = "all" ]; then
    # 先编译外部库
    config_external_lib
    for ARCH in $FF_ALL_ARCHS
    do
        sh tools/do-compile-ffmpeg.sh $ARCH $FF_TARGET_EXTRA
    done

    do_lipo_all
elif [ "$FF_TARGET" = "check" ]; then
    # 分支下必须要有语句 否则出错
    echo "check"
elif [ "$FF_TARGET" = "clean" ]; then

    echo "=================="
    for ARCH in $FF_ALL_ARCHS
    do
        echo "clean ffmpeg-$ARCH"
        echo "=================="
        cd ffmpeg-$ARCH && git clean -xdf && cd -
    done
    echo "clean build cache"
    echo "================="
    rm -rf build/ffmpeg-*
    rm -rf build/openssl-*
    rm -rf build/universal/include
    rm -rf build/universal/lib
    echo "clean success"
else
    echo "Usage:"
    echo "  compile-ffmpeg.sh armv7|arm64|i386|x86_64"
    echo "  compile-ffmpeg.sh armv7s (obselete)"
    echo "  compile-ffmpeg.sh lipo"
    echo "  compile-ffmpeg.sh all"
    echo "  compile-ffmpeg.sh clean"
    echo "  compile-ffmpeg.sh check"
    exit 1
fi