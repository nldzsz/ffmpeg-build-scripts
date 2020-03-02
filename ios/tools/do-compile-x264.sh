#!/bin/sh

CONFIGURE_FLAGS="--enable-static --enable-pic --disable-cli"

# 源码目录;与编译脚本同级目录，编译的中间产物.o,.d也会在这里
SOURCE=
# 编译最终的输出目录；必须为绝对路径，否则生成的库不会到这里去
OUT=`pwd`/"build"
# 接受参数 作为编译平台
ARCH=$1
# 编译的最低版本要求
target_ios=$2

# 开始编译
CWD=`pwd`

echo "building x264 $ARCH..."
SOURCE="forksource/x264-$ARCH"
cd $SOURCE
CFLAGS="-arch $ARCH"
ASFLAGS=

if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
then
    PLATFORM="iPhoneSimulator"
    CPU=
    if [ "$ARCH" = "x86_64" ]
    then
        CFLAGS="$CFLAGS -mios-simulator-version-min=$target_ios"
        HOST=
    else
        CFLAGS="$CFLAGS -mios-simulator-version-min=$target_ios"
        HOST="--host=i386-apple-darwin"
    fi
else
    PLATFORM="iPhoneOS"
    if [ $ARCH = "arm64" ]
    then
        HOST="--host=aarch64-apple-darwin"
        XARCH="-arch aarch64"
    else
        HOST="--host=arm-apple-darwin"
        XARCH="-arch arm"
    fi

    CFLAGS="$CFLAGS -fembed-bitcode -mios-version-min=$target_ios"
    ASFLAGS="$CFLAGS"
fi

# 意思是将echo $PLATFORM作为tr命令的输入，然后先转换成大写，在接着转换成小写，这里拿
# iPhoneSimulator举例，最终的结果就是iphonesimulator
XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
# 配置编译器，这里选择clang编译器
CC="xcrun -sdk $XCRUN_SDK clang"
if [ $PLATFORM = "iPhoneOS" ]
then
# 用于将汇编程序转变成机器代码
    export AS="$CWD/$SOURCE/tools/gas-preprocessor.pl $XARCH -- $CC"
else
# export -n意思就是取消存在的AS环境变量
    export -n AS
fi
CXXFLAGS="$CFLAGS"
LDFLAGS="$CFLAGS"
# 效果和./configre .... 一样
CC=$CC $CWD/$SOURCE/configure \
    $CONFIGURE_FLAGS \
    $HOST \
    --extra-cflags="$CFLAGS" \
    --extra-asflags="$ASFLAGS" \
    --extra-ldflags="$LDFLAGS" \
    --prefix="$OUT/x264-$ARCH/output" || exit 1

make -j3 install || exit 1
cd $CWD


# ====== 此段代码无用 =======
if [ "$LIPO" ]
then
	echo "building fat binaries..."
	mkdir -p $FAT/lib
    # set 命令的用法参考 http://www.ruanyifeng.com/blog/2017/11/bash-set.html
    # 该命令的作用就是 让$ARCHS作为当前执行脚本默认附带的参数，这样即使当前脚本没有参数，后面的$1
    # 也会从$ARCHS中去取值
	set - $ARCHS
	CWD=`pwd`
    echo "$THIN/$1/lib"
	cd $THIN/$1/lib
    # *.a 当前目录下所有以.a结尾的文件
	for LIB in *.a
	do
		cd $CWD
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB
	done

	cd $CWD
    # 随便拷贝一个架构平台的头文件作为合并后的架构平台的头文件(因为都一样)
	cp -rf $THIN/$1/include $FAT
fi
# ====== 此段代码无用=======
