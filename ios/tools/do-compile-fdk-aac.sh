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

labrry_name=fdk-aac
CONFIGURE_FLAGS="--enable-static --with-pic=yes --disable-shared"

# 源码目录;与编译脚本同级目录，编译的中间产物.o,.d也会在这里
SOURCE=
# 编译最终的输出目录；必须为绝对路径，否则生成的库不会到这里去
OUT=`pwd`/"build"

CWD=`pwd`

# 接受外部输入 $1代表编译平台 $2代表编译系统的最低版本要求
ARCH=$1
target_ios=$2
echo "building fdk-aac $ARCH..."
SOURCE="forksource/$labrry_name-$ARCH"
cd $SOURCE

CFLAGS="-arch $ARCH"

if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
then
	PLATFORM="iPhoneSimulator"
	CPU=
	if [ "$ARCH" = "x86_64" ]
	then
	   	CFLAGS="$CFLAGS -mios-simulator-version-min=$target_ios"
	   	HOST="--host=x86_64-apple-darwin"
	else
	    CFLAGS="$CFLAGS -mios-simulator-version-min=$target_ios"
		HOST="--host=i386-apple-darwin"
	fi
else
	PLATFORM="iPhoneOS"
	if [ "$ARCH" = "arm64" ]
	then
#		    CFLAGS="$CFLAGS -D__arm__ -D__ARM_ARCH_7EM__" # hack!
        CFLAGS="$CFLAGS -mios-version-min=$target_ios"
        HOST="--host=aarch64-apple-darwin"
    else
        CFLAGS="$CFLAGS -mios-version-min=$target_ios"
        HOST="--host=arm-apple-darwin"
    fi
    CFLAGS="$CFLAGS -fembed-bitcode"
fi

XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
	
CC="xcrun -sdk $XCRUN_SDK clang -Wno-error=unused-command-line-argument-hard-error-in-future"
# gas-preprocessor.pl作用就是将汇编代码转换成机器码，是编译过程中必须要的东西;有两种配置方式，手动指定或者自动在环境变量中查找
# gas-preprocessor.pl下载地址：https://github.com/libav/gas-preprocessor/blob/master/gas-preprocessor.pl。可以下载后拷贝到目录extras下
# 方法一：手动指定路径；方式如下，如果这里指定的路径不存在，将去环境变量指定的路径中查找该文件
# 方法二：自动在环境变量中查找；只需要将gas-preprocessor.pl下载下来 拷贝到/usr/local/bin目录中然后 执行 chmod 777 /usr/local/bin/gas-preprocessor.pl
AS="$CWD/$SOURCE/extras/gas-preprocessor.pl $CC"
CXXFLAGS="$CFLAGS"
LDFLAGS="$CFLAGS"

$CWD/$SOURCE/configure \
    $CONFIGURE_FLAGS \
    $HOST \
    $CPU \
    CC="$CC" \
    CXX="$CC" \
    CPP="$CC -E" \
    AS="$AS" \
    CFLAGS="$CFLAGS" \
    LDFLAGS="$LDFLAGS" \
    CPPFLAGS="$CFLAGS" \
    --prefix="$OUT/$labrry_name-$ARCH/output"

make -j3 install
cd $CWD
