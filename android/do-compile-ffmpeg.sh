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

FF_BUILD_ROOT=`pwd`/android
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

FF_BUILD_NAME=
# ffmpeg增加了neon以及thumb的支持，通过--enable-neon这些选项开启这些支持，其它库不一定有neon的支持，
if [ "$FF_ARCH" = "armv7a" ]; then
    FF_BUILD_NAME=ffmpeg-armv7a
    FF_CROSS_PREFIX=arm-linux-androideabi
    FF_CROSS_ARCH="--arch=arm --cpu=cortex-a8"
    # 下面两个是ffmpeg 库针armv7a架构对特有的，其它库不一定有下面这两个选项
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-neon"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-thumb"
    # 下面两个是针对armv7a架构的cpu指令优化选项，这是针对cpu的，所以每个库都可以这样设定，但是有的库比如x264的./configure文件自动添加了这些配置，就不需要手动添加
    # 参考
    FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS -march=armv7-a -mcpu=cortex-a8 -mfpu=vfpv3-d16 -mfloat-abi=softfp -mthumb"
    FF_EXTRA_LDFLAGS="$FF_EXTRA_LDFLAGS -Wl,--fix-cortex-a8"
elif [ "$FF_ARCH" = "armv5" ]; then
    FF_BUILD_NAME=ffmpeg-armv5
    FF_CROSS_PREFIX=arm-linux-androideabi
    FF_CROSS_ARCH="--arch=arm"
    FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS -march=armv5te -mtune=arm9tdmi -msoft-float"
    FF_EXTRA_LDFLAGS="$FF_EXTRA_LDFLAGS"

elif [ "$FF_ARCH" = "x86_64" ]; then
    FF_BUILD_NAME=ffmpeg-x86_64
    FF_CROSS_PREFIX=x86_64-linux-android
    FF_CROSS_ARCH="--arch=x86_64"
    FF_CFG_FLAGS="$FF_CFG_FLAGS  --enable-yasm"
    FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS"
    FF_EXTRA_LDFLAGS="$FF_EXTRA_LDFLAGS"

elif [ "$FF_ARCH" = "arm64" ]; then
    FF_BUILD_NAME=ffmpeg-arm64
    FF_CROSS_PREFIX=aarch64-linux-android
    FF_CROSS_ARCH="--arch=aarch64"
    # arm64 默认就开启了neon，所以不需要像armv7a那样手动开启
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-yasm"
    FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS"
    FF_EXTRA_LDFLAGS="$FF_EXTRA_LDFLAGS"

else
    echo "unknown architecture $FF_ARCH";
    exit 1
fi

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
# -D__ANDROID_API__=$API 解决用NDK15以后出现的undefined reference to 'stderr'问题
# 参考官网https://android.googlesource.com/platform/ndk/+/ndk-r15-release/docs/UnifiedHeaders.md
# -Wno-psabi -Wa,--noexecstack 去掉-Wno-psabi(该选项作用未知) 选项变成 -Wa,--noexecstack;否则会一直打出warning: unknown warning option '-Wno-psabi'的警告
FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS -O3 -Wall -pipe \
    -std=c99 \
    -ffast-math \
    -fstrict-aliasing -Werror=strict-aliasing \
    -Wa,--noexecstack \
    -DANDROID -DNDEBUG -D__ANDROID_API__=$FF_ANDROID_API"

# cause av_strlcpy crash with gcc4.7, gcc4.8
# -fmodulo-sched -fmodulo-sched-allow-regmoves

# 导入ffmpeg 的配置
export COMMON_FF_CFG_FLAGS=
. $FF_BUILD_ROOT/../config/module.sh

# 开启Android的MediaCodec GPU编码；必须要开启--enable-jni才能将mediacodec编译进去
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-jni"
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-mediacodec"
# 默认为编译动态库
shared_enable="--enable-shared"
static_enable="--disable-static"
# 默认生成动态库时会带版本号，这里通过匹配去掉了版本号
if [ $FF_COMPILE_SHARED != "TRUE" ];then
shared_enable="--disable-shared"
fi
if [ $FF_COMPILE_STATIC == "TRUE" ];then
static_enable="--enable-static"
fi
export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS $shared_enable $static_enable"

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
    # libx264和mp3lame只提供编码功能，他们的解码是额外的库
    if [ $lib = "x264" ]; then
        ENABLE_FLAGS="--enable-gpl --enable-libx264 --enable-encoder=libx264 --enable-decoder=h264"
    fi

    if [ $lib = "fdk-aac" ]; then
        ENABLE_FLAGS="--enable-nonfree --enable-libfdk-aac --enable-encoder=libfdk_aac --enable-decoder=libfdk_aac"
    fi

    if [ $lib = "mp3lame" ]; then
        ENABLE_FLAGS="--enable-libmp3lame --enable-encoder=libmp3lame --enable-decoder=mp3float"
    fi
    if [[ ${LIBFLAGS[i]} == "TRUE" ]];then
        COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS $ENABLE_FLAGS"

        FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS -I${lib_inc_dir}"
        FF_EXTRA_LDFLAGS="$FF_EXTRA_LDFLAGS -L${lib_lib_dir} $LD_FLAGS"
        
        EXT_ALL_LIBS="$EXT_ALL_LIBS $lib_lib_dir/lib$lib.a"
    fi
done

FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS $FF_CFG_FLAGS"

# 编译库安装目录
FF_CFG_FLAGS="$FF_CFG_FLAGS --prefix=$FF_PREFIX"
FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-pic"

# -----交叉编译配置 -------
FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-cross-compile"
# 注意后面的 "-" 不要少
FF_CFG_FLAGS="$FF_CFG_FLAGS --cross-prefix=${FF_CROSS_PREFIX}-"
FF_CFG_FLAGS="$FF_CFG_FLAGS --target-os=android"
FF_CFG_FLAGS="$FF_CFG_FLAGS $FF_CROSS_ARCH"
# -----交叉编译配置 -------


if [ "$FF_ARCH" = "x86" ]; then
    FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-asm"
else
    # Optimization options (experts only):
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-asm"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-inline-asm"
fi

case "$FF_BUILD_OPT" in
    debug)
        FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-optimizations"
        FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-debug"
        FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-small"
    ;;
    *)
        FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-optimizations"
        FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-debug"
        FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-small"
    ;;
esac

# 创建独立工具链
# 通过此种方式执行sh 文件中的export变量才有效。如果换成sh ./do-make-standalone-tool.sh $ARCH 则不行
. ./android/do-envbase-tool.sh $FF_ARCH

#--------------------
echo ""
echo "--------------------"
echo "[*] configurate ffmpeg"
echo "--------------------"
echo "FF_CFG_FLAGS=$FF_CFG_FLAGS \n"
echo "--extra-cflags=$FF_EXTRA_CFLAGS \n"
echo "--extra-ldflags=$FF_EXTRA_LDFLAGS \n"
# 各个cpu架构的源码 比如/Users/apple/devoloper/mine/ijkplayer/android/contribffmpeg-armv7a
cd $FF_SOURCE
# 当执行过一次./configure 会在源码根目录生成config.h文件
#if [ -f "./config.h" ]; then
#    echo 'reuse configure'
#else
#    # which 是根据使用者所配置的 PATH 变量内的目录去搜寻可执行文件路径，并且输出该路径
#    ./configure $FF_CFG_FLAGS \
#        --extra-cflags="$FF_EXTRA_CFLAGS" \
#        --extra-ldflags="$FF_EXTRA_LDFLAGS"
#    make clean
#fi
# which 是根据使用者所配置的 PATH 变量内的目录去搜寻可执行文件路径，并且输出该路径
./configure $FF_CFG_FLAGS \
    --extra-cflags="$FF_EXTRA_CFLAGS" \
    --extra-ldflags="$FF_EXTRA_LDFLAGS"
make clean

#------- 编译和连接 -------------
#生成各个模块对应的静态或者动态库(取决于前面是生成静态还是动态库)
echo ""
echo "--------------------"
echo "[*] compile ffmpeg"
echo "--------------------"
#cp config.* $FF_PREFIX
make $FF_MAKE_FLAGS > /dev/null
make install
mkdir -p $FF_PREFIX/include/libffmpeg
#cp -f config.h $FF_PREFIX/include/libffmpeg/config.h
cd -

# 执行拷贝
#${#array[@]}获取数组长度用于循环
for(( i=0;i<${#lIBS[@]};i++))
do
    lib=${lIBS[i]};
    lib_name=$lib-$FF_ARCH
    lib_lib_dir=$FF_BUILD_ROOT/build/$lib_name/lib
    ext=".so"
    if [ $FF_COMPILE_STATIC == "TRUE" ];then
        ext=".a"
    fi
    
    if [[ ${LIBFLAGS[i]} == "TRUE" ]];then
        cp $lib_lib_dir/lib$lib$ext $FF_PREFIX/lib/lib$lib$ext
    fi
done

#--------- 将前面生成的静态库合并成一个动态库 这里会将外部.a库也合并进来;只用于静态编译的ffmpeg-----------
# todo:下面的连接器ndk20执行会出错，ndk17则没问题(原因未知)
#$LD -rpath-link=$FF_SYSROOT/usr/lib \
#    -L$FF_SYSROOT/usr/lib \
#    -soname libxrzffmpeg.so -shared -nostdlib -Bsymbolic --whole-archive --no-undefined \
#    -o $FF_PREFIX/libxrzffmpeg.so \
#    $FF_PREFIX/lib/libavcodec.a $FF_PREFIX/lib/libavfilter.a $FF_PREFIX/lib/libavformat.a \
#    $FF_PREFIX/lib/libavutil.a $FF_PREFIX/lib/libswresample.a $FF_PREFIX/lib/libswscale.a \
#    $EXT_ALL_LIBS \
#    -lc -lm -lz -ldl -llog --dynamic-linker=/system/bin/linker \
#    $FF_TOOLCHAIN_PATH/lib/gcc/$FF_CROSS_PREFIX/4.9.x/libgcc.a

# 对包的大小进行优化，根据测试 优化由19M到3.3M了
#$STRIP $FF_PREFIX/libxrzffmpeg.so
