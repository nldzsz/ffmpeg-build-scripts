#! /usr/bin/env bash
#
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
# https://github.com/yixia/FFmpeg-Android
# http://git.videolan.org/?p=vlc-ports/android.git;a=summary

FF_BUILD_ROOT=`pwd`/mac
echo "FF_BUILD_ROOT=$FF_BUILD_ROOT"

#--------------------
# 目标平台 armv7a arm64(armv8) x86....
FF_ARCH=$1
# 编译选项 是否开启debug选项等等，默认为发布版本
FF_BUILD_OPT=$2
echo "FF_ARCH=$FF_ARCH"
echo "FF_BUILD_OPT=$FF_BUILD_OPT"
if [ -z "$FF_ARCH" ]; then
    echo "You must specific an architecture 'arm, armv7a, x86, ...'."
    echo ""
    exit 1
fi

# 对于每一个库，他们的./configure 他们的配置参数以及关于交叉编译的配置参数可能不一样，具体参考它的./configure文件
# 用于./configure 的--cross_prefix 参数
FF_CROSS_PREFIX=
# 用于./configure 的--arch 参数
FF_CROSS_ARCH=
# 用于./configure 的参数
FF_CFG_FLAGS=

# 用于./configure 关于--extra-cflags 的参数，该参数包括如下内容：
# 1、关于cpu的指令优化
# 2、关于编译器指令有关参数优化
# 3、指定引用三方库头文件路径或者系统库的路径
FF_EXTRA_CFLAGS=
# 用于./configure 关于--extra-ldflags 的参数
# 1、指定引用三方库的路径及库名称 比如-L<x264_path> -lx264
FF_EXTRA_LDFLAGS=

FF_BUILD_NAME=ffmpeg-x86_64

# 各个平台对应的源码目录
FF_SOURCE=$FF_BUILD_ROOT/forksource/$FF_BUILD_NAME
if [ ! -d $FF_SOURCE ]; then
    echo ""
    echo "!! ERROR"
    echo "!! Can not find FFmpeg directory for $FF_BUILD_NAME"
    echo "!! Run 'sh init-android.sh' first"
    echo ""
    exit 1
fi

FF_PREFIX=$FF_BUILD_ROOT/build/$FF_BUILD_NAME

mkdir -p $FF_PREFIX

# 开始编译
# 导入ffmpeg 的配置
export COMMON_FF_CFG_FLAGS=
. $FF_BUILD_ROOT/../config/module.sh


#导入ffmpeg的外部库
EXT_ALL_LIBS=
#${#array[@]}获取数组长度用于循环
for(( i=0;i<${#lIBS[@]};i++))
do
    lib=${lIBS[i]};
    lib_name=$lib-$FF_ARCH
    lib_inc_dir=$FF_BUILD_ROOT/build/$lib_name/include
    lib_lib_dir=$FF_BUILD_ROOT/build/$lib_name/lib
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
    if [[ ${LIBFLAGS[i]} == "TRUE" ]];then
        COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS $ENABLE_FLAGS"

        FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS -I${lib_inc_dir}"
        FF_EXTRA_LDFLAGS="$FF_EXTRA_LDFLAGS -L${lib_lib_dir} $LD_FLAGS"
        
        EXT_ALL_LIBS="$EXT_ALL_LIBS $lib_lib_dir/lib$lib.a"
    fi
done

FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS $FF_CFG_FLAGS"

#--------------------
echo ""
echo "--------------------"
echo "[*] configurate ffmpeg"
echo "--------------------"
echo "FF_CFG_FLAGS=$FF_CFG_FLAGS \n"
echo "--extra-cflags=$FF_EXTRA_CFLAGS \n"
echo "--extra-ldflags=$FF_EXTRA_LDFLAGS \n"

cd $FF_SOURCE
# 当执行过一次./configure 会在源码根目录生成config.h文件
# which 是根据使用者所配置的 PATH 变量内的目录去搜寻可执行文件路径，并且输出该路径
./configure $FF_CFG_FLAGS \
    --prefix=$FF_PREFIX \
    --extra-cflags="$FF_EXTRA_CFLAGS" \
    --extra-ldflags="$FF_EXTRA_LDFLAGS"

#------- 编译和连接 -------------
#生成各个模块对应的静态或者动态库(取决于前面是生成静态还是动态库)
echo ""
echo "--------------------"
echo "[*] compile ffmpeg"
echo "--------------------"
cp config.* $FF_PREFIX
make && make install
mkdir -p $FF_PREFIX/include/libffmpeg
cp -f config.h $FF_PREFIX/include/libffmpeg/config.h
# 拷贝外部库
for lib in $EXT_ALL_LIBS
do
    cp -f $lib $FF_PREFIX/lib
done
cd -
