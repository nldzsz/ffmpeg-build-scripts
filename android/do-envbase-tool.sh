#!/bin/bash


FF_ARCH=$1

UNAME_S=$(uname -s)
UNAME_SM=$(uname -sm)
IJK_NDK_REL=$(grep -o '^r[0-9]*.*' $NDK_PATH/RELEASE.TXT 2>/dev/null | sed 's/[[:space:]]*//g' | cut -b2-)
case "$IJK_NDK_REL" in
    10e*)
        echo "You need the NDKr10e or later"
        exit 1
    ;;
    *)
        IJK_NDK_REL=$(grep -o '^Pkg\.Revision.*=[0-9]*.*' $NDK_PATH/source.properties 2>/dev/null | sed 's/[[:space:]]*//g' | cut -d "=" -f 2)
        echo "IJK_NDK_REL=$IJK_NDK_REL"
        case "$IJK_NDK_REL" in
            1*|2*)
                if test -d ${NDK_PATH}/toolchains/arm-linux-androideabi-4.9
                then
                    echo "NDKr$IJK_NDK_REL detected"
                else
                    echo "You need the NDKr10e or later"
                    exit 1
                fi
            ;;
            *)
                echo "You need the NDKr10e or later"
                exit 1
            ;;
        esac
    ;;
esac

# 开始编译 pwd代表的执行该脚本脚本的所在目录(不一定是该脚本所在目录)
export WORK_PATH=`pwd`
case "$UNAME_S" in
    Darwin)
        export FF_MAKE_FLAGS=-j`sysctl -n machdep.cpu.thread_count`
    ;;
    CYGWIN_NT-*)
        IJK_WIN_TEMP="$(cygpath -am /tmp)"
        export TEMPDIR=$IJK_WIN_TEMP/
        echo "Cygwin temp prefix=$IJK_WIN_TEMP/"
		export WORK_PATH="$(cygpath -am `pwd`)"
    ;;
esac

FF_BUILD_ROOT=$WORK_PATH/android
echo ""
echo "-------do-envbase-tools.sh-------"
echo "build on $UNAME_SM"
echo "NDK_PATH=$NDK_PATH"
echo "WORK_PATH=$WORK_PATH"
echo ""


FF_CROSS_PREFIX=
FF_CC_CPP_PREFIX=
FF_ARCH_1=arm
FF_CC=gcc
FF_CPP=g++
FF_SYSROOT=""
FF_HOST_OS=
if [ "$FF_ARCH" = "x86_64" ]; then
	FF_ARCH_1=x86_64
    FF_CROSS_PREFIX=x86_64-linux-android
	FF_CC_CPP_PREFIX=x86_64-linux-android$FF_ANDROID_API
elif [ "$FF_ARCH" = "armv7a" ]; then
	FF_ARCH_1=arm
    FF_CROSS_PREFIX=arm-linux-androideabi
	FF_CC_CPP_PREFIX=armv7a-linux-androideabi$FF_ANDROID_API
elif [ "$FF_ARCH" = "arm64" ]; then
	FF_ARCH_1=arm64
    FF_CROSS_PREFIX=aarch64-linux-android
	FF_CC_CPP_PREFIX=aarch64-linux-android$FF_ANDROID_API
else
	FF_ARCH_1=arm
    FF_CROSS_PREFIX=arm-linux-androideabi
fi

FF_TOOLCHAIN_PATH=$FF_BUILD_ROOT/forksource/toolchain-$FF_ARCH
FF_TOOLCHAIN_TOUCH="$FF_TOOLCHAIN_PATH/touch"
FF_SAVE_NDK_VERSION="1.0"
if [ -f "$FF_TOOLCHAIN_TOUCH" ]; then
    FF_SAVE_NDK_VERSION=`cat "$FF_TOOLCHAIN_TOUCH"`
fi
echo "local $FF_SAVE_NDK_VERSION cur $IJK_NDK_REL $UNAME_S"
if [ "$FF_SAVE_NDK_VERSION" != "$IJK_NDK_REL" ];then
	echo ""
	echo "--------------------"
	echo "[*] make NDK standalone toolchain"
	echo "--------------------"
	echo "FF_MAKE_TOOLCHAIN_FLAGS=$FF_MAKE_TOOLCHAIN_FLAGS"
	echo "FF_MAKE_FLAGS=$FF_MAKE_FLAGS"
	echo "FF_ANDROID_API=$FF_ANDROID_API"
	echo "--------------------"
	echo ""
fi

# 遇到问题：cygwin编译x264时环境变量不起作用。
# 分析原因：对于cyg编译工具的PATH环境变量，x264的编译脚本无法识别C:这样的盘符(它用:/cygdrive/c来表示C盘)
# 解决方案：直接指定AR，CC，CPP的绝对路径
# 创建独立工具链 参考https://developer.android.com/ndk/guides/standalone_toolchain
#export PATH=$FF_TOOLCHAIN_PATH/bin/:$PATH
if [[ "$UNAME_S" == CYGWIN_NT-* ]]; then
	
	if [ "$FF_SAVE_NDK_VERSION" != "$IJK_NDK_REL" ]; then
		
		# NDK版本不一样了，则先删除以前的
		if [ -f "$FF_TOOLCHAIN_TOUCH" ]; then
			rm -rf $FF_TOOLCHAIN_PATH
		fi
		
		
		#遇到问题：cyg调用dnk17以下版本的make-standalone-toolchain.sh脚本会出错，而且ndk21的此脚本也是各种问题
		#分析原因：可能此脚本不同版本的兼容性未做好
		#解决方案：cyg调用bat脚本来安装独立工具链则很好的解决了兼容性问题
		#windows的cyg编译则调用bat脚本来安装独立工具链
		echo "cwgwin windows bat install maketool..."
		$WORK_PATH/maketool_install.bat "$WIN_PYTHON_PATH" "$NDK_PATH" $FF_ARCH_1 $FF_ANDROID_API "$FF_TOOLCHAIN_PATH"
		
		# 避免重复执行make-standalone-toolchain.sh指令
		touch $FF_TOOLCHAIN_TOUCH;
		echo "$IJK_NDK_REL" >$FF_TOOLCHAIN_TOUCH
	fi
	
	# 定义cyg的C编译器和CPP编译器
	FF_CC=clang.cmd
	FF_CPP=clang++.cmd

	FF_SYSROOT=$FF_TOOLCHAIN_PATH/sysroot
	FF_CROSS_PREFIX=$FF_TOOLCHAIN_PATH/bin/${FF_CROSS_PREFIX}
	FF_CC_CPP_PREFIX=$FF_CROSS_PREFIX
	FF_HOST_OS=windows-x86_64
else
	# 其他系统 mac和linux
	if [ "$FF_SAVE_NDK_VERSION" != "$IJK_NDK_REL" ]; then
		
        
		# NDK版本不一样了，则先删除以前的
		if [ -f "$FF_TOOLCHAIN_TOUCH" ]; then
			rm -rf $FF_TOOLCHAIN_PATH
		fi
		
        # ndk19以前才需要，但是ndk20在ubunto上编译mp3lame时报错，21没问题，所以21以下统一用此方法，21及以上才不用安装独立工具链
        if [[ "$IJK_NDK_REL" < "21" ]]; then
            # 该脚本将ndk目录下的编译工具复制到指定的位置，后面./configure配置的时候指定的路径就可以写这里指定的位置了
            $NDK_PATH/build/tools/make-standalone-toolchain.sh \
                --install-dir=$FF_TOOLCHAIN_PATH \
                --platform="android-$FF_ANDROID_API" \
                --arch=$FF_ARCH_1   \
                --toolchain=${FF_CROSS_PREFIX}-4.9
                
            # 避免重复执行make-standalone-toolchain.sh指令
            touch $FF_TOOLCHAIN_TOUCH;
            echo "$IJK_NDK_REL" >$FF_TOOLCHAIN_TOUCH
        fi
        
	fi
	
    if [ "$UNAME_S" == "Linux" ];then
        FF_HOST_OS=linux-x86_64
    else
        FF_HOST_OS=darwin-x86_64
    fi
    
    FF_CC=clang
    FF_CPP=clang++
	if [[ "$IJK_NDK_REL" < "21" ]]; then
		FF_SYSROOT=$FF_TOOLCHAIN_PATH/sysroot
		FF_CROSS_PREFIX=$FF_TOOLCHAIN_PATH/bin/${FF_CROSS_PREFIX}
		FF_CC_CPP_PREFIX=$FF_CROSS_PREFIX
	else	
		# ndk 19以后则直接使用ndk原来的目录即可;而且FF_SYSROOT不需要用--sysroot来指定了，否则编译会出错
		FF_SYSROOT=""
		FF_CROSS_PREFIX=$NDK_PATH/toolchains/llvm/prebuilt/$FF_HOST_OS/bin/${FF_CROSS_PREFIX}
		FF_CC_CPP_PREFIX=$NDK_PATH/toolchains/llvm/prebuilt/$FF_HOST_OS/bin/${FF_CC_CPP_PREFIX}
	fi

fi

export FF_SYSROOT
export FF_CROSS_PREFIX
# 编译缓存，可以加快编译
#export CC="ccache ${FF_CROSS_PREFIX}-gcc"
# fixbug:ndk20版本之后，预编译器cpp已经内置到CC中了，所以如果这里再指定会出现找不到cpp的错误
#export CPP=${FF_CROSS_PREFIX}-cpp
export AR=${FF_CROSS_PREFIX}-ar
# 开启该选项后x264的编译选项 -DSTAK_ALIGNMENT=会加入到AS中，导致编译失败。如果没有定义这个，
# -DSTAK_ALIGNMENT=会作为gccmingl的参数，则编译通过
#export AS=${FF_CROSS_PREFIX}-as
export NM=${FF_CROSS_PREFIX}-nm
export CC=${FF_CC_CPP_PREFIX}-$FF_CC
export CXX=${FF_CC_CPP_PREFIX}-$FF_CPP
export LD=${FF_CROSS_PREFIX}-ld
export RANLIB=${FF_CROSS_PREFIX}-ranlib
export STRIP=${FF_CROSS_PREFIX}-strip
export OBJDUMP=${FF_CROSS_PREFIX}-objdump
export OBJCOPY=${FF_CROSS_PREFIX}-objcopy
export ADDR2LINE=${FF_CROSS_PREFIX}-addr2line
export READELF=${FF_CROSS_PREFIX}-readelf
export SIZE=${FF_CROSS_PREFIX}-size
export STRINGS=${FF_CROSS_PREFIX}-strings
export ELFEDIT=${FF_CROSS_PREFIX}-elfedit
export GCOV=${FF_CROSS_PREFIX}-gcov
export GDB=${FF_CROSS_PREFIX}-gdb
export GPROF=${FF_CROSS_PREFIX}-gprof
