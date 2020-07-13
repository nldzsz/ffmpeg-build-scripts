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
# FF_ALL_ARCHS_IOS="armv7 armv7s arm64 i386 x86_64"
export FF_ALL_ARCHS_IOS="arm64 x86_64"
target_ios=10.0

# 是否将这些外部库添加进去;如果不添加 则将对应的值改为FALSE即可；默认添加三个库
export lIBS=(x264 fdk-aac mp3lame)
export LIBFLAGS=(TRUE FALSE TRUE)


# 内部调试用
export INTERNAL_DEBUG=FALSE
#----------
UNI_BUILD_ROOT=`pwd`/ios
# 通过. xx.sh的方式执行shell脚本，变量会被覆盖
FF_TARGET=$1

set -e
#----------

ffmpeg_uni_output_dir=$UNI_BUILD_ROOT/build/ffmpeg-a1universal
if [ $INTERNAL_DEBUG = "TRUE" ];then
    ffmpeg_uni_output_dir=/Users/apple/devoloper/mine/ffmpeg/ffmpeg-demo/demo-ios/ffmpeglib
fi
do_lipo_lib () {
    
    # 将ffmpeg的各个模块生成的库以及引用的外部库按照要编译的平台合并成一个库(比如指定了x86_64和arm64两个平台，那么执行此命令后将对应生成各自平台的两个库)
    LIB_FILE=$1.a
    LIPO_FLAGS=
    for ARCH in $FF_ALL_ARCHS_IOS
    do
        ARCH_LIB_FILE="$UNI_BUILD_ROOT/build/ffmpeg-$ARCH/lib/$LIB_FILE"
        if [ -f "$ARCH_LIB_FILE" ]; then
            LIPO_FLAGS="$LIPO_FLAGS $ARCH_LIB_FILE"
        else
            echo "skip $LIB_FILE of $ARCH";
        fi
    done
    
    ffmpeg_output_dir=$ffmpeg_uni_output_dir/lib/$LIB_FILE
    xcrun lipo -create $LIPO_FLAGS -output $ffmpeg_output_dir
    xcrun lipo -info $ffmpeg_output_dir
}

FF_FFMPEG_LIBS="libavcodec libavfilter libavformat libavutil libswscale libswresample"
do_lipo_all () {
    mkdir -p $UNI_BUILD_ROOT/build/ffmpeg-a1universal
    echo ""
    echo "lipo archs: $FF_ALL_ARCHS_IOS"
    
    # 合并ffmpeg库各个模块的不同平台库
    for LIB in $FF_FFMPEG_LIBS
    do
        do_lipo_lib $LIB
    done
    
    # 合并ffmpeg库引用的第三方库的各个平台的库;${#array[@]}获取数组长度用于循环
    for(( i=0;i<${#lIBS[@]};i++))
    do
        lib=${lIBS[i]};
        if [[ ${LIBFLAGS[i]} == "TRUE" ]]; then
            do_lipo_lib lib"$lib";
        fi
    done;
    
    # 拷贝ffmpeg头文件
    ANY_ARCH=
    for ARCH in $FF_ALL_ARCHS_IOS
    do
        ARCH_INC_DIR="$UNI_BUILD_ROOT/build/ffmpeg-$ARCH/include"
        if [ -d "$ARCH_INC_DIR" ]; then
            if [ -z "$ANY_ARCH" ]; then
                ANY_ARCH=$ARCH
                cp -R "$ARCH_INC_DIR" "$UNI_BUILD_ROOT/build/ffmpeg-a1universal/include"
            fi

            UNI_INC_DIR="$UNI_BUILD_ROOT/build/ffmpeg-a1universal/include"

            mkdir -p "$UNI_INC_DIR/libavutil/$ARCH"
            cp -f "$ARCH_INC_DIR/libavutil/avconfig.h"  "$UNI_INC_DIR/libavutil/$ARCH/avconfig.h"
            cp -f ios/avconfig.h                      "$UNI_INC_DIR/libavutil/avconfig.h"
            cp -f "$ARCH_INC_DIR/libavutil/ffversion.h" "$UNI_INC_DIR/libavutil/$ARCH/ffversion.h"
            cp -f ios/ffversion.h                     "$UNI_INC_DIR/libavutil/ffversion.h"
            # 引用 ijkplayer 暂时不知道撒用 先屏蔽
            # mkdir -p "$UNI_INC_DIR/libffmpeg/$ARCH"
            # cp -f "$ARCH_INC_DIR/libffmpeg/config.h"    "$UNI_INC_DIR/libffmpeg/$ARCH/config.h"
            # cp -f tools/config.h                        "$UNI_INC_DIR/libffmpeg/config.h"
        fi
    done
}

# 编译外部库
function compile_external_lib()
{
    FF_ARCH=$1
    
    #${#array[@]}获取数组长度用于循环
    for(( i=0;i<${#lIBS[@]};i++))
    do
        lib=${lIBS[i]};
        FF_BUILD_NAME=$lib-$FF_ARCH
        FFMPEG_DEP_LIB=$UNI_BUILD_ROOT/build/$FF_BUILD_NAME/lib

        if [[ ${LIBFLAGS[i]} == "TRUE" ]]; then
            if [ ! -f "${FFMPEG_DEP_LIB}/lib$lib.a" ]; then
                # 编译
                . ./ios/do-compile-$lib.sh $FF_ARCH $target_ios
            fi
        fi
    done;
}

#----------
if [ "$FF_TARGET" = "armv7" -o "$FF_TARGET" = "armv7s" -o "$FF_TARGET" = "arm64" -o "$FF_TARGET" = "i386" -o "$FF_TARGET" = "x86_64" -o "$FF_TARGET" = "all" ]; then
    # 获取源码，不存在在则拉取
    . ./compile-init.sh ios "offline"
    
    # 删除ffmpeg库目录
    rm -rf ios/build/ffmpeg-*

    if [ "$FF_TARGET" != "all" ];then
        # 编译外部库，已经编译过则跳过。如果要重新编译，删除build下的外部库
        compile_external_lib $FF_TARGET
        
        # 编译ffmpeg
        . ./ios/do-compile-ffmpeg.sh $FF_TARGET $target_ios
    else
        
        for ARCH in $FF_ALL_ARCHS_IOS
        do
            # 编译外部库，已经编译过则跳过。如果要重新编译，删除build下的外部库
            compile_external_lib $ARCH
            
            # 编译ffmpeg库
            . ./ios/do-compile-ffmpeg.sh $ARCH $target_ios
        done
    fi
    
    # 合并库
    do_lipo_all
elif [ "$FF_TARGET" = "clean" ]; then

    echo "=================="
    echo "clean ............"
    echo "================="
    rm -rf ios/build
    rm -rf ios/forksource
    echo "clean success"
else
    echo "Usage:"
    echo "  compile-ffmpeg.sh arm64|x86_64"
    echo "  compile-ffmpeg.sh all"
    echo "  compile-ffmpeg.sh clean"
    exit 1
fi
