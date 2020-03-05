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

CONFIGURE_FLAGS="--enable-static --enable-shared --disable-frontend "

# 源码目录;与编译脚本同级目录，编译的中间产物.o,.d也会在这里
SOURCE=
# 编译最终的输出目录；必须为绝对路径，否则生成的库不会到这里去
OUT=`pwd`/"mac/build"
# 接受参数 作为编译平台
ARCH=$1

echo "building mp3lame $ARCH..."

SOURCE="mac/forksource/mp3lame-$ARCH"
cd $SOURCE

# Fix undefined symbol error _lame_init_old
sed -i '' '/lame_init_old/d' include/libmp3lame.sym

PREFIX=$OUT/mp3lame-$ARCH

echo "CONFIGURE_FLAGS:$CONFIGURE_FLAGS"
echo "prefix:$PREFIX"
echo ""

# 效果和./configre .... 一样
./configure \
  ${CONFIGURE_FLAGS} \
  --prefix=$PREFIX
  
make && make install
cd -


