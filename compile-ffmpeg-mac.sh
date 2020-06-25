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
set -e

# 由于目前MAC设备都是电脑64位 所以这里脚本默认只支持 x86_64平台
# FF_ALL_ARCHS="i386 x86_64"
FF_ALL_ARCHS="x86_64"

# 是否将这些外部库添加进去;如果不添加 则将对应的值改为FALSE即可；默认添加3个库
export lIBS=(x264 fdk-aac mp3lame)
export LIBFLAGS=(TRUE FALSE TRUE)

#----------
UNI_BUILD_ROOT=`pwd`
FF_TARGET=$1

# 编译外部库
compile_external_lib()
{
    #${#array[@]}获取数组长度用于循环
    for(( i=0;i<${#lIBS[@]};i++)) 
    do
        lib=${lIBS[i]};
        FF_ARCH=$1
        FF_BUILD_NAME=$lib-$FF_ARCH
        FFMPEG_DEP_LIB=$UNI_BUILD_ROOT/mac/build/$FF_BUILD_NAME/lib

        if [[ ${LIBFLAGS[i]} == "TRUE" ]]; then
            if [ ! -f "${FFMPEG_DEP_LIB}/lib$lib.a" ]; then
                # 编译
                . ./mac/do-compile-$lib.sh $FF_ARCH
            fi
        fi
    done;
}

# 命令开始执行处----------
if [ "$FF_TARGET" == "reset" ]; then
    # 重新拉取所有代码
    echo "....repull all source...."
    rm -rf mac/forksource
    . ./compile-init.sh mac
elif [ "$FF_TARGET" == "all" ]; then
    
    # 开始之前先检查fork的源代码是否存在
    if [ ! -d mac/forksource ]; then
        . ./compile-init.sh mac "offline"
    fi
    
    rm -rf mac/build/ffmpeg-*
    for ARCH in $FF_ALL_ARCHS
    do
        # 先编译外部库
        compile_external_lib $ARCH
        
        # 最后编译ffmpeg
        . ./mac/do-compile-ffmpeg.sh $ARCH
    done
    
elif [ "$FF_TARGET" = "clean" ]; then

    echo "=================="
    for ARCH in $FF_ALL_ARCHS
    do
        echo "clean ffmpeg-$ARCH"
        echo "=================="
        cd mac/forksource/ffmpeg-$ARCH && git clean -xdf && cd -
#        cd mac/forksource/x264-$ARCH && git clean -xdf && cd -
#        cd mac/forksource/mp3lame-$ARCH && make clean && cd -
#        cd mac/forksource/fdk-aac-$ARCH && make clean && cd -
    done
    echo "clean build cache"
    echo "================="
    rm -rf mac/build/ffmpeg-*
    echo "clean success"
else
    echo "Usage:"
    echo "  compile-ffmpeg.sh all"
    echo "  compile-ffmpeg.sh clean"
    echo "  compile-ffmpeg.sh reset"
    exit 1
fi
