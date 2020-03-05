#!/bin/bash


FF_ARCH=$1

# 开始编译 pwd代表的执行该脚本脚本的所在目录(不一定是该脚本所在目录)
FF_BUILD_ROOT=`pwd`/android

#----------
UNAME_S=$(uname -s)
UNAME_SM=$(uname -sm)
echo "-------do-envbase-tools.sh-------"
echo "build on $UNAME_SM"
echo "NDK_PATH=$NDK_PATH"
echo "FF_BUILD_ROOT=$FF_BUILD_ROOT"

export IJK_NDK_REL=$(grep -o '^r[0-9]*.*' $NDK_PATH/RELEASE.TXT 2>/dev/null | sed 's/[[:space:]]*//g' | cut -b2-)
case "$IJK_NDK_REL" in
    10e*)
        # we don't use 4.4.3 because it doesn't handle threads correctly.
        if test -d ${NDK_PATH}/toolchains/arm-linux-androideabi-4.8
        # if gcc 4.8 is present, it's there for all the archs (x86, mips, arm)
        then
            echo "NDKr$IJK_NDK_REL detected"

            case "$UNAME_S" in
                Darwin)
                    export FF_MAKE_TOOLCHAIN_FLAGS="$FF_MAKE_TOOLCHAIN_FLAGS --system=darwin-x86_64"
                ;;
                CYGWIN_NT-*)
                    export FF_MAKE_TOOLCHAIN_FLAGS="$FF_MAKE_TOOLCHAIN_FLAGS --system=windows-x86_64"
                ;;
            esac
        else
            echo "You need the NDKr10e or later"
            exit 1
        fi
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

case "$UNAME_S" in
    Darwin)
        export FF_MAKE_FLAGS=-j`sysctl -n machdep.cpu.thread_count`
    ;;
    CYGWIN_NT-*)
        IJK_WIN_TEMP="$(cygpath -am /tmp)"
        export TEMPDIR=$IJK_WIN_TEMP/

        echo "Cygwin temp prefix=$IJK_WIN_TEMP/"
    ;;
esac

FF_CROSS_PREFIX=
if [ "$FF_ARCH" = "x86_64" ]
then
    FF_CROSS_PREFIX=x86_64-linux-android
elif [ "$FF_ARCH" = "armv7" ]
then
    FF_CROSS_PREFIX=arm-linux-androideabi
elif [ "$FF_ARCH" = "arm64" ]
then
    FF_CROSS_PREFIX=aarch64-linux-android
else
    FF_CROSS_PREFIX=arm-linux-androideabi
fi

#--------------------
echo ""
echo "--------------------"
echo "[*] make NDK standalone toolchain"
echo "--------------------"
echo "FF_MAKE_TOOLCHAIN_FLAGS=$FF_MAKE_TOOLCHAIN_FLAGS"
echo "FF_MAKE_FLAGS=$FF_MAKE_FLAGS"
echo "FF_CC_VER=$FF_CC_VER"
echo "FF_ANDROID_API=$FF_ANDROID_API"
echo "--------------------"
echo ""

# ==== 创建独立工具链 参考https://developer.android.com/ndk/guides/standalone_toolchain
FF_TOOLCHAIN_PATH=$FF_BUILD_ROOT/forksource/toolchain-$FF_ARCH
FF_TOOLCHAIN_TOUCH="$FF_TOOLCHAIN_PATH/touch"
if [ ! -f "$FF_TOOLCHAIN_TOUCH" ]; then
# 该脚本将ndk目录下的编译工具复制到指定的位置，后面./configure配置的时候指定的路径就可以写这里指定的位置了
    $NDK_PATH/build/tools/make-standalone-toolchain.sh \
        --install-dir=$FF_TOOLCHAIN_PATH \
        --platform="android-$FF_ANDROID_API" \
        --toolchain=${FF_CROSS_PREFIX}-${FF_CC_VER}
# 避免重复执行make-standalone-toolchain.sh指令
    touch $FF_TOOLCHAIN_TOUCH;
fi
# ==== 创建独立工具链

export FF_SYSROOT=$FF_TOOLCHAIN_PATH/sysroot
export PATH=$FF_TOOLCHAIN_PATH/bin/:$PATH
# 编译缓存，可以加快编译
#export CC="ccache ${FF_CROSS_PREFIX}-gcc"
export CPP=${FF_CROSS_PREFIX}-cpp
export AR=${FF_CROSS_PREFIX}-ar
# 开启该选项后x264的编译选项 -DSTAK_ALIGNMENT=会加入到AS中，导致编译失败。如果没有定义这个，-DSTAK_ALIGNMENT=会作为gccmingl的参数，则编译通过
#export AS=${FF_CROSS_PREFIX}-as
export NM=${FF_CROSS_PREFIX}-nm
export CC=${FF_CROSS_PREFIX}-gcc
export CXX=${FF_CROSS_PREFIX}-g++
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
