#!/bin/bash

CONFIGURE_FLAGS="--enable-static --enable-shared --enable-pic --disable-cli --enable-strip"

# 源码目录;与编译脚本同级目录，编译的中间产物.o,.d也会在这里
SOURCE=
# 编译最终的输出目录；必须为绝对路径，否则生成的库不会到这里去
OUT=`pwd`/"android/build"
# 接受参数 作为编译平台
ARCH=$1
# 编译的API要求
target_API=$2

echo ""
echo "building x264 $ARCH..."
echo ""

# 创建独立工具链
# 通过此种方式执行sh 文件中的export变量才有效。如果换成sh ./do-envbase-tool.sh $ARCH 则不行
. ./android/do-envbase-tool.sh $ARCH


SOURCE="android/forksource/x264-$ARCH"
cd $SOURCE

CROSS_PREFIX=""
HOST=""
PREFIX=$OUT/x264-$ARCH

if [ "$ARCH" = "x86_64" ]; then
    CROSS_PREFIX=x86_64-linux-android-
    HOST="x86_64-linux"
elif [ "$ARCH" = "armv7a" ]; then
    CROSS_PREFIX=arm-linux-androideabi-
    HOST="arm-linux"
elif [ "$ARCH" = "arm64" ]; then
    CROSS_PREFIX=aarch64-linux-android-
    HOST="aarch64-linux"
else
    CROSS_PREFIX=arm-linux-androideabi-
    HOST="arm-linux"
fi

echo "CONFIGURE_FLAGS:$CONFIGURE_FLAGS"
echo "sysroot:$FF_SYSROOT"
echo "cross-prefix:$CROSS_PREFIX"
echo "prefix:$PREFIX"
echo "host:$HOST"

# 取消外部的干扰
unset CFLAGS
unset CPPFLAGS
unset LDFLAGS
unset PKG_CONFIG_PATH

# 效果和./configre .... 一样
./configure \
  ${CONFIGURE_FLAGS} \
  --prefix=$PREFIX \
  --host=$HOST \
  --cross-prefix=$CROSS_PREFIX \
  --extra-cflags="-D__ANDROID_API__=$FF_ANDROID_API" \
  --sysroot=$FF_SYSROOT || exit 1
make $FF_MAKE_FLAGS install
cd -
