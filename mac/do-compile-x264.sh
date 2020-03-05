#!/bin/bash

CONFIGURE_FLAGS="--enable-static --enable-shared --enable-pic --disable-cli --enable-strip"

# 源码目录;与编译脚本同级目录，编译的中间产物.o,.d也会在这里
SOURCE=
# 编译最终的输出目录；必须为绝对路径，否则生成的库不会到这里去
OUT=`pwd`/"mac/build"
# 接受参数 作为编译平台
ARCH=$1

echo "building x264 $ARCH..."

SOURCE="mac/forksource/x264-$ARCH"
cd $SOURCE
PREFIX=$OUT/x264-$ARCH

echo "CONFIGURE_FLAGS:$CONFIGURE_FLAGS"
echo "prefix:$PREFIX"
echo ""

# 效果和./configre .... 一样
./configure \
  ${CONFIGURE_FLAGS} \
  --prefix=$PREFIX

make && make install
cd -
