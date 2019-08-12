#!/bin/sh

CONFIGURE_FLAGS="--enable-static --enable-pic --disable-cli"

#ARCHS="arm64 x86_64 i386 armv7 armv7s"
# 要编译的平台
ARCHS="arm64 x86_64"

# 当前编译脚本所在目录，源码与其在同级目录下
SHELL_ROOT_DIR=`pwd`
# 源码目录;与编译脚本同级目录，编译的中间产物.o,.d也会在这里
SOURCE=
# 编译最终的输出目录；必须为绝对路径，否则生成的库不会到这里去
OUT=`pwd`/"build"

COMPILE="y"
#LIPO="y"

#if [ "$*" ]
#then
#    if [ "$*" = "lipo" ]
#    then
#        # skip compile
#        COMPILE=
#    else
#        ARCHS="$*"
#        if [ $# -eq 1 ]
#        then
#            # skip lipo
#            LIPO=
#        fi
#    fi
#fi

if [ "$COMPILE" ]
then
    CWD=`pwd`
    for ARCH in $ARCHS
    do
        echo "building $ARCH..."
        SOURCE="x264-$ARCH"
        cd $SOURCE
        CFLAGS="-arch $ARCH"
        ASFLAGS=

        if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
        then
            PLATFORM="iPhoneSimulator"
            CPU=
            if [ "$ARCH" = "x86_64" ]
            then
                CFLAGS="$CFLAGS -mios-simulator-version-min=7.0"
                HOST=
            else
                CFLAGS="$CFLAGS -mios-simulator-version-min=5.0"
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

            CFLAGS="$CFLAGS -fembed-bitcode -mios-version-min=7.0"
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
            --prefix="$OUT/$SOURCE/output" || exit 1

        make -j3 install || exit 1
        cd $CWD
    done
fi

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
