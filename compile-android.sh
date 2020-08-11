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
set -e
# 通过. xx.sh的方式执行shell脚本，变量会被覆盖
. ./common.sh

export FF_ALL_ARCHS_ANDROID="armv7a arm64"
# 编译的API级别 (最小5.0以上系统)
export FF_ANDROID_API=21
# 根据实际情况填写ndk路径;(备注:mac和linux平台下，如果从小于19和19以上版本之间切换过ndk版本，那么最好先删掉android/forksource目录重新编译拉取代码，
# 否则编译fdk-aac时会出现libtool执行错误,导致编译结束)
# windows，linux，mac平台有各自对应的ndk版本下载地址 https://developer.android.google.cn/ndk/downloads
#export NDK_PATH=C:/cygwin64/home/Administrator/android-ndk-r21b
#export NDK_PATH=/Users/apple/devoloper/mine/android/android-ndk-r17c
#export NDK_PATH=/Users/apple/devoloper/mine/android/android-ndk-r19c
#export NDK_PATH=/Users/apple/devoloper/mine/android/android-ndk-r20b
export NDK_PATH=/Users/apple/devoloper/mine/android/android-ndk-r21b
#export NDK_PATH=/home/zsz/android-ndk-r20b
# 编译动态库，默认开启;FALSE则关闭动态库 编译静态库;动态库和静态库同时只能开启一个，不然导入android使用时会出错
export FF_COMPILE_SHARED=TRUE

# windows下统一用bat脚本来生成独立工具编译目录(因为低于18的ndk库中的make_standalone_toolchain.py脚本在cygwin中执行会出错)
export WIN_PYTHON_PATH=C:/Users/Administrator/AppData/Local/Programs/Python/Python38-32/python.exe

# 是否编译这些库;如果不编译将对应的值改为FALSE即可；如果ffmpeg对应的值为TRUE时，还会将其它库引入ffmpeg中，否则单独编译其它库
# 如果要开启drawtext滤镜，则必须要编译fribidi expat fontconfig freetype库;如果要开启subtitles滤镜，则还要编译ass库
# 遇到问题：以静态库的方式引入android studio时 提示"undefined reference to xxxx"
# 分析原因：此问题为偶然发现，以静态库方式导入可执行程序时(如果引用的库中又引用了其它库或者各个模块之间有相互引用时)那么就一定要注意连接顺序的问题，所以最后一定要按照如下顺序导入到android中(其中ffmpeg库的顺序也要固定)
# libavformat.a libavcodec.a libavfilter.a  libavutil.a libswresample.a libswscale.a libass.a libfontconfig.a libexpat.a libfreetype.a libfribidi.a libmp3lame.a libx264.a
export LIBFLAGS=(
[ffmpeg]=TRUE [x264]=TRUE [fdkaac]=FALSE [mp3lame]=TRUE [fribidi]=TRUE [freetype]=TRUE [expat]=TRUE [fontconfig]=TRUE [ass]=TRUE [openssl]=TRUE
)

# 内部调试用
export INTERNAL_DEBUG=FALSE
# 开启硬编解码
ENABLE_GPU=TRUE

UNI_BUILD_ROOT=`pwd`
FF_TARGET=$1
#----------

create_zlib_system_package_config() {
    local tool_chain_path=$1
    local pkg_path=$2
    ZLIB_VERSION=$(grep '#define ZLIB_VERSION' ${tool_chain_path}/sysroot/usr/include/zlib.h | grep -Eo '\".*\"' | sed -e 's/\"//g')

    cat > "${pkg_path}/zlib.pc" << EOF
prefix=${tool_chain_path}/sysroot/usr
exec_prefix=\${prefix}
libdir=\${prefix}/usr/lib
includedir=\${prefix}/include

Name: zlib
Description: zlib compression library
Version: ${ZLIB_VERSION}

Requires:
Libs: -L\${libdir} -lz
Cflags: -I\${includedir}
EOF
}

# 配置交叉编译环境
set_toolchain_path()
{
    local FF_ARCH=$1
    local IJK_NDK_REL=$(grep -o '^Pkg\.Revision.*=[0-9]*.*' $NDK_PATH/source.properties 2>/dev/null | sed 's/[[:space:]]*//g' | cut -d "=" -f 2)
    # 开始编译 pwd代表的执行该脚本脚本的所在目录(不一定是该脚本所在目录)
    export WORK_PATH=`pwd`
    case "$uname" in
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
    
    HOST_PKG_CONFIG_PATH=`command -v pkg-config`
    if [ -z ${HOST_PKG_CONFIG_PATH} ]; then
        echo -e "pkg-config command not found\n"
        exit 1
    fi
    export HOST_PKG_CONFIG_PATH
    
    FF_SYSROOT=""
    FF_CROSS_PREFIX=
    FF_TOOLCHAIN_PATH_EN=
    FF_TOOLCHAIN_PATH=$WORK_PATH/build/forksource/android-toolchain-$FF_ARCH
    
    local FF_CC_CPP_PREFIX=
    local FF_ARCH_1=arm
    local FF_CC=gcc
    local FF_CPP=g++
    local FF_HOST_OS=
    if [ "$FF_ARCH" = "armv7a" ]; then
        FF_ARCH_1=arm
        FF_CROSS_PREFIX=arm-linux-androideabi
        FF_CC_CPP_PREFIX=armv7a-linux-androideabi$FF_ANDROID_API
    elif [ "$FF_ARCH" = "arm64" ]; then
        FF_ARCH_1=arm64
        FF_CROSS_PREFIX=aarch64-linux-android
        FF_CC_CPP_PREFIX=aarch64-linux-android$FF_ANDROID_API
    else
        echo "unsurport platform !"
        exit 1
    fi

    local FF_TOOLCHAIN_TOUCH="$FF_TOOLCHAIN_PATH/touch"
    local FF_SAVE_NDK_VERSION="1.0"
    if [ -f "$FF_TOOLCHAIN_TOUCH" ]; then
        FF_SAVE_NDK_VERSION=`cat "$FF_TOOLCHAIN_TOUCH"`
    fi
    
    if [ "$FF_SAVE_NDK_VERSION" != "$IJK_NDK_REL" ];then
        echo "make NDK standalone toolchain...."
        echo ""
    fi

    # 遇到问题：cygwin编译x264时环境变量不起作用。
    # 分析原因：对于cyg编译工具的PATH环境变量，x264的编译脚本无法识别C:这样的盘符(它用:/cygdrive/c来表示C盘)
    # 解决方案：直接指定AR，CC，CPP的绝对路径
    # 创建独立工具链 参考https://developer.android.com/ndk/guides/standalone_toolchain
    #export PATH=$FF_TOOLCHAIN_PATH/bin/:$PATH
    if [[ "$uname" == CYGWIN_NT-* ]]; then
        
        if [ "$FF_SAVE_NDK_VERSION" != "$IJK_NDK_REL" ]; then
            
            # NDK版本不一样了，则先删除以前的
            rm -rf $FF_TOOLCHAIN_PATH
            rm -rf $WORK_PATH/build/android-$FF_ARCH
            
            
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
#        FF_CROSS_PREFIX=$FF_TOOLCHAIN_PATH/bin/${FF_CROSS_PREFIX}
        FF_CC_CPP_PREFIX=$FF_CROSS_PREFIX
        FF_HOST_OS=windows-x86_64
        FF_TOOLCHAIN_PATH_EN=$FF_TOOLCHAIN_PATH/bin
    else
        # 其他系统 mac和linux
        if [ "$FF_SAVE_NDK_VERSION" != "$IJK_NDK_REL" ]; then
            
            
            # NDK版本不一样了，则先删除以前的
            rm -rf $FF_TOOLCHAIN_PATH
            rm -rf $WORK_PATH/build/android-$FF_ARCH
            
            # ndk19以前才需要，但是ndk20在ubunto上编译mp3lame时报错，21没问题，所以21以下统一用此方法，21及以上才不用安装独立工具链
            if [[ "$IJK_NDK_REL" < "21" ]]; then
                # 该脚本将ndk目录下的编译工具复制到指定的位置，后面./configure配置的时候指定的路径就可以写这里指定的位置了
                $NDK_PATH/build/tools/make-standalone-toolchain.sh \
                    --install-dir=$FF_TOOLCHAIN_PATH \
                    --platform="android-$FF_ANDROID_API" \
                    --arch=$FF_ARCH_1   \
                    --toolchain=${FF_CROSS_PREFIX}-4.9
            fi
            # 避免重复执行make-standalone-toolchain.sh指令
            mkdir -p $FF_TOOLCHAIN_PATH
            touch $FF_TOOLCHAIN_TOUCH;
            echo "$IJK_NDK_REL" >$FF_TOOLCHAIN_TOUCH
        fi
        
        if [ "$uname" == "Linux" ];then
            FF_HOST_OS=linux-x86_64
        else
            FF_HOST_OS=darwin-x86_64
        fi
        
        FF_CC=clang
        FF_CPP=clang++
        if [[ "$IJK_NDK_REL" < "21" ]]; then
            FF_SYSROOT=$FF_TOOLCHAIN_PATH/sysroot
#            FF_CROSS_PREFIX=$FF_TOOLCHAIN_PATH/bin/${FF_CROSS_PREFIX}
            FF_CC_CPP_PREFIX=$FF_CROSS_PREFIX
            FF_TOOLCHAIN_PATH_EN=$FF_TOOLCHAIN_PATH/bin
        else
            # ndk 19以后则直接使用ndk原来的目录即可;而且FF_SYSROOT不需要用--sysroot来指定了，否则编译会出错
            FF_SYSROOT=""
#            FF_CROSS_PREFIX=$NDK_PATH/toolchains/llvm/prebuilt/$FF_HOST_OS/bin/${FF_CROSS_PREFIX}
#            FF_CC_CPP_PREFIX=$NDK_PATH/toolchains/llvm/prebuilt/$FF_HOST_OS/bin/${FF_CC_CPP_PREFIX}
            FF_CC_CPP_PREFIX=$FF_CC_CPP_PREFIX
            FF_TOOLCHAIN_PATH_EN=$NDK_PATH/toolchains/llvm/prebuilt/$FF_HOST_OS/bin
        fi

    fi
    
    export PATH=$FF_TOOLCHAIN_PATH_EN:$PATH
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
    export CC=${FF_CC_CPP_PREFIX}-$FF_CC
    export CXX=${FF_CC_CPP_PREFIX}-$FF_CPP
    export LD=${FF_CROSS_PREFIX}-ld
    export RANLIB=${FF_CROSS_PREFIX}-ranlib
    export STRIP=${FF_CROSS_PREFIX}-strip
    export PKG_CONFIG_LIBDIR="${UNI_BUILD_ROOT}/build/android-$ARCH/pkgconfig"
    export ZLIB_PACKAGE_CONFIG_PATH="${PKG_CONFIG_LIBDIR}/zlib.pc"
    mkdir -p $PKG_CONFIG_LIBDIR
    
    if [ ! -f ${ZLIB_PACKAGE_CONFIG_PATH} ]; then
        create_zlib_system_package_config $FF_TOOLCHAIN_PATH $PKG_CONFIG_LIBDIR
    fi
}
set_flags()
{
    local ARCH=$1
    # 用来配置编译器参数，一般包括如下几个部分：
    # 1、平台cpu架构相关的参数，比如arm64、x86_64不同cpu架构相关的参数也不一样，一般是固定的
    # 2、编译器相关参数，比如std=c99，不同的库所使用的语言以及语言的版本等等
    # 3、编译器优化相关参数，这部分参数往往跟平台以及库无关，比如-O2 -Wno-ignored-optimization-argument等等加快编译进度的参数 -g开启编译调试信息
    # 4、系统路径以及系统版本等相关参数 -isysroot=<SDK_PATH> -I<SDK_PATH>/usr/include
    CFLAGS=
    HOST=
    if [ $ARCH = "x86_64" ];then
        HOST=x86_64-linux-android
        CFLAGS="-march=x86-64 -msse4.2 -mpopcnt -m64 -mtune=intel"
    elif [ $ARCH = "armv7a" ];then
        HOST=arm-linux-androideabi
        # 下面是针对armv7a架构的cpu指令优化选项，这是针对cpu的，所以每个库都可以这样设定，但是有的库比如x264的./configure文件自动添加了这些配置，就不需要手动添加
        CFLAGS="-march=armv7-a -mcpu=cortex-a8 -mfpu=vfpv3-d16 -mfloat-abi=softfp -mthumb"
    elif [ $ARCH = "arm64" ];then
        HOST=aarch64-linux-android
        # arm64 默认就开启了neon，所以不需要像armv7a那样手动开启
        CFLAGS="-march=armv8-a"
    else
        echo "ext unsurported platform $ARCH !...."
        exit 1
    fi
    CFLAGS="$CFLAGS -fno-integrated-as -fstrict-aliasing -fPIC -DANDROID -D__ANDROID_API__=${FF_ANDROID_API}"
    
    CFLAGS="$CFLAGS $LL_CFLAGS"
    CPPFLAGS="${CFLAGS}"
    LDFLAGS="$CFLAGS $LL_LDFLAGS"
    
    # 对于符合GNU规范的configure配置脚本(比如通过Autoconf工具生成的),它一般具有如下通用配置参数选项：
    # 1、--host;表示编译出来的二进制程序(可执行程序和库)所执行的主机，如果是本机执行则无需指定。如果是交叉编译则需要指定
    # 2、--prefix;编译生成的库、可执行程序、.pc文件的存放路径
    # 3、--with-sysroot;指定查找系统库搜索的根路径(注意，这里是系统库的根路径，可能最终还是会按照linux规范在根路径的/usr/include /usr/local等目录下找)
    # 4、CFLAGS;用来指定C编译相关参数
    # 5、CPPFLAGS;用来指定C++/OC编译相关参数
    # 6、LDFLAGS;用来指定连接相关参数
    # 7、CC;指定C编译器，也可以通过export CC=C编译器路径方式指定
    # 8、PKG_CONFIG_PATH/PKG_CONFIG_LIBDIR;指定pkg-config工具所需要的.pc文件的搜索路径(备注：一般通过Autoconf生成的脚本都会根据此参数自动引入pkg-config)
    #
    # 备注：x264 ffmpeg等非Autoconf生成的configure配置脚本以及编译器参数，可能有些不同;CFLAGS可能不同的库有些一不一样
    # 遇到问题："引入fontconfig时提示"libtool: link: warning: library `/home/admin/usr/lib/freetype.la' was moved." ";因为fontcong依赖freetype，libass也依赖freetype。而fontconfig如果加入了--with-sysroot=参数
    # 则生成的fontconfig.la文件的dependency_libs字段 是-Lxxx/freetype/lib =/user/xxxxx/freetype.la的格式，导致libtool解析错误，所以这里fontconfig不需要添加"--with-root" 参数
    SYS_ROOT_CONF="--with-sysroot=${FF_SYSROOT}"
    if [ $lib = "x264" ];then
        SYS_ROOT_CONF="--sysroot=${FF_SYSROOT}"
    elif [ $lib = "fontconfig" ];then
        SYS_ROOT_CONF=
    elif [ $lib = "fdk-aac" ];then
        CFLAGS="$CFLAGS -Wno-error=unused-command-line-argument-hard-error-in-future"
    else
        # C语言标准，clang编译器默认使用gnu99的C语言标准。不同的库可能使用的C语言标准不一样，不过一般影响不大，如果有影响则需要特别指定
        # -Wunused表示所有未使用给与警告(-Wunused-xx 表示具体的未使用警告,-Wno-unused-xxx 表示取消具体未使用警告)
        CFLAGS="$CFLAGS -Wunused-function"
    fi
    
    # 像CC AR CFLAGS CXXFLAGS等等这一类makefile用于配置编译器参数的环境变量一定要用export导入，否则不会生效
    export HOST
    export CFLAGS
    export CXXFLAGS
    export CPPFLAGS
    export LDFLAGS
    export SYS_ROOT_CONF
}

real_do_compile()
{
    local CONFIGURE_FLAGS=$1
    local lib=$2
    local ARCH=$3
    local SOURCE=$UNI_BUILD_ROOT/build/forksource/$lib
    local PREFIX=$UNI_BUILD_ROOT/build/android-$ARCH/$lib
    cd $SOURCE
    
    echo ""
    echo "build $lib $ARCH ......."
    echo "CONFIGURE_FLAGS:$CONFIGURE_FLAGS"
    echo "prefix:$PREFIX"
    echo "FF_SYSROOT:$FF_SYSROOT"
    
    set_flags $ARCH
    
    set +e
    make distclean
    set -e
    
    if [ $lib = "ssl" ];then
        export ANDROID_NDK_HOME=$NDK_PATH
        local arch_flags=
        if [ $ARCH = "x86_64" ];then
            arch_flags=android-x86_64
        elif [ $ARCH = "armv7a" ];then
            arch_flags=android-arm
        elif [ $ARCH = "arm64" ];then
            arch_flags=android-arm64
        else
            echo "ext unsurported platform $ARCH !...."
            exit 1
        fi
        
        ./Configure \
            $CONFIGURE_FLAGS \
            $arch_flags \
            --prefix=$PREFIX
        
        # 修改编译android动态库时生成的后缀
        $OUR_SED 's/SHLIB_EXT=\.so\.\$(SHLIB_VERSION_NUMBER)/SHLIB_EXT=\.so/g' Makefile
        
        make -j$(get_cpu_count) && make install_sw || exit 1
        
    else
        ./configure \
            $CONFIGURE_FLAGS \
            --host=$HOST \
            --prefix=$PREFIX \
            $SYS_ROOT_CONF
            
        make -j$(get_cpu_count) && make install || exit 1
    fi

    if [ $lib = "mp3lame" ];then
        create_mp3lame_package_config "${PKG_CONFIG_LIBDIR}" "${PREFIX}"
    elif [ $lib = "freetype" ];then
        cp ${PREFIX}/lib/pkgconfig/*.pc ${PKG_CONFIG_LIBDIR} || exit 1
    elif [ $lib = "fontconfig" ];then
        create_fontconfig_package_config "${PKG_CONFIG_LIBDIR}" "${PREFIX}"
    else
        cp ./*.pc ${PKG_CONFIG_LIBDIR} || exit 1
    fi
    
    cd -
}
#编译x264
do_compile_x264()
{
    local CONFIGURE_FLAGS="--enable-static --enable-pic --disable-cli --enable-strip "
    if [ $FF_COMPILE_SHARED = "TRUE" ];then
        CONFIGURE_FLAGS="--enable-shared --enable-pic --disable-cli --enable-strip "
        # 默认生成动态库时会带版本号，这里通过匹配去掉了版本号
        cd $UNI_BUILD_ROOT/build/forksource/x264
        case "$uname" in
           Darwin)
               sed -i "" "s/echo \"SONAME=libx264.so.\$API\" >> config.mak/echo \"SONAME=libx264.so\" >> config.mak/g" configure
               sed -i "" "s/ln -f -s \$(SONAME) \$(DESTDIR)\$(libdir)\/libx264.\$(SOSUFFIX)//g" Makefile
           ;;
           Darwin)
               sed -i "s/echo \"SONAME=libx264.so.\$API\" >> config.mak/echo \"SONAME=libx264.so\" >> config.mak/g" configure
               sed -i "s/ln -f -s \$(SONAME) \$(DESTDIR)\$(libdir)\/libx264.\$(SOSUFFIX)//g" Makefile
           ;;
           CYGWIN_NT-*)
               sed -i "s/echo \"SONAME=libx264.so.\$API\" >> config.mak/echo \"SONAME=libx264.so\" >> config.mak/g" configure
               sed -i "s/ln -f -s \$(SONAME) \$(DESTDIR)\$(libdir)\/libx264.\$(SOSUFFIX)//g" Makefile
           ;;
        esac
        cd -
    fi
    
    real_do_compile "$CONFIGURE_FLAGS" "x264" $1
}

#编译fdk-aac
do_compile_fdk_aac()
{
    local CONFIGURE_FLAGS="--enable-static --with-pic "
    if [ $FF_COMPILE_SHARED = "TRUE" ];then
        CONFIGURE_FLAGS="--enable-shared --with-pic "
    fi
    # 遇到问题：Linux下编译时提示"error: version mismatch.  This is Automake 1.15.1"
    # 分析原因：fdk-aac自带的生成的configure.ac和Linux系统的Automake不符合
    # 解决方案：命令autoreconf重新配置configure.ac即可
    if [ $uname == "Linux" ];then
        cd $UNI_BUILD_ROOT/build/forksource/fdk-aac
        autoreconf
        cd -
    fi
    
    real_do_compile "$CONFIGURE_FLAGS" "fdk-aac" $1
}
#编译mp3lame
do_compile_mp3lame()
{
    local CONFIGURE_FLAGS="--enable-static --disable-shared --disable-frontend --with-pic=PIC "
    if [ $FF_COMPILE_SHARED = "TRUE" ];then
        CONFIGURE_FLAGS="--enable-static=no --enable-shared=yes --disable-frontend --with-pic=PIC "
    fi
    real_do_compile "$CONFIGURE_FLAGS" "mp3lame" $1
}
#编译ass
do_compile_ass()
{
    # ass 依赖于freetype和fribidi，所以需要检查一下
    local pkgpath=$UNI_BUILD_ROOT/build/android-$1/pkgconfig
    if [ ! -f $pkgpath/freetype2.pc ];then
        echo "libass dependency freetype please set [freetype]=TRUE "
        exit 1
    fi
    if [ ! -f $pkgpath/fribidi.pc ];then
        echo "libass dependency fribidi please set [fribidi]=TRUE "
        exit 1
    fi
    
    local CONFIGURE_FLAGS="--with-pic --disable-libtool-lock --enable-static --disable-shared --enable-fontconfig --disable-harfbuzz --disable-fast-install --disable-test --disable-profile --disable-coretext "
    if [ $FF_COMPILE_SHARED = "TRUE" ];then
        CONFIGURE_FLAGS="--with-pic --disable-libtool-lock --disable-static --enable-shared --enable-fontconfig --disable-harfbuzz --disable-fast-install --disable-test --disable-profile --disable-coretext "
    fi
    real_do_compile "$CONFIGURE_FLAGS" "ass" $1
}
#编译freetype
do_compile_freetype()
{
    if [ ! -f $UNI_BUILD_ROOT/build/forksource/freetype/configure ];then
        local SOURCE=$UNI_BUILD_ROOT/build/forksource/freetype
        cd $SOURCE
        ./autogen.sh
        cd -
    fi
    
    local CONFIGURE_FLAGS="--with-pic --with-zlib --without-png --without-harfbuzz --without-bzip2 --without-fsref --without-quickdraw-toolbox --without-quickdraw-carbon --without-ats --disable-fast-install --disable-mmap --enable-static --disable-shared "
    if [ $FF_COMPILE_SHARED = "TRUE" ];then
        CONFIGURE_FLAGS="--with-pic --with-zlib --without-png --without-harfbuzz --without-bzip2 --without-fsref --without-quickdraw-toolbox --without-quickdraw-carbon --without-ats --disable-fast-install --disable-mmap --disable-static --enable-shared "
    fi
    real_do_compile "$CONFIGURE_FLAGS" "freetype" $1
}
#编译fribidi
do_compile_fribidi()
{
    if [ ! -f $UNI_BUILD_ROOT/build/forksource/fribidi/configure ];then
        local SOURCE=$UNI_BUILD_ROOT/build/forksource/fribidi
        cd $SOURCE
        ./autogen.sh
        cd -
    fi
    local CONFIGURE_FLAGS="--with-pic --enable-static --disable-shared --disable-fast-install --disable-debug --disable-deprecated "
    if [ $FF_COMPILE_SHARED = "TRUE" ];then
        CONFIGURE_FLAGS="--with-pic --disable-static --enable-shared --disable-fast-install --disable-debug --disable-deprecated "
    fi
    real_do_compile "$CONFIGURE_FLAGS" "fribidi" $1
}
#编译expact
do_compile_expat()
{
    if [ $uname == "Linux" ];then
        cd $UNI_BUILD_ROOT/build/forksource/fontconfig
        autoreconf
        cd -
    fi
    local CONFIGURE_FLAGS="--with-pic --enable-static --disable-shared --disable-fast-install --without-docbook --without-xmlwf "
    if [ $FF_COMPILE_SHARED = "TRUE" ];then
        CONFIGURE_FLAGS="--with-pic --disable-static --enable-shared --disable-fast-install --without-docbook --without-xmlwf "
    fi
    real_do_compile "$CONFIGURE_FLAGS" "expat" $1
}
#编译fontconfig
do_compile_fontconfig()
{
    if [[ ! -f $UNI_BUILD_ROOT/build/android-$1/expat/lib/libexpat.a && ! -f $UNI_BUILD_ROOT/build/android-$1/expat/lib/libexpat.so ]];then
        echo "fontconfig dependency expat please set [expat]=TRUE "
        exit 1
    fi
    
    if [ $uname == "Linux" ];then
        cd $UNI_BUILD_ROOT/build/forksource/fontconfig
        autoreconf
        cd -
    fi
    local CONFIGURE_FLAGS="--with-pic --enable-static --disable-shared --disable-fast-install --disable-rpath --disable-libxml2 --disable-docs "
    if [ $FF_COMPILE_SHARED = "TRUE" ];then
        CONFIGURE_FLAGS="--with-pic --disable-static --enable-shared --disable-fast-install --disable-rpath --disable-libxml2 --disable-docs "
    fi
    real_do_compile "$CONFIGURE_FLAGS" "fontconfig" $1
}
#编译openssl
do_compile_ssl()
{
    local CONFIGURE_FLAGS="zlib-dynamic no-shared "
    if [ $FF_COMPILE_SHARED = "TRUE" ];then
        CONFIGURE_FLAGS="zlib-dynamic no-static-engine "
    fi
    
    real_do_compile "$CONFIGURE_FLAGS" "ssl" $1
}
# 编译ffmpeg
do_compile_ffmpeg()
{
    if [ ${LIBFLAGS[$ffmpeg]} == "FALSE" ];then
        echo "config not build ffmpeg....return"
        return
    fi
    
    local FF_BUILD_NAME=ffmpeg
    local FF_BUILD_ROOT=`pwd`
    local FF_ARCH=$1

    # 对于每一个库，他们的./configure 他们的配置参数以及关于交叉编译的配置参数可能不一样，具体参考它的./configure文件
    # 用于./configure 的参数
    FF_CFG_FLAGS=
    # 用于./configure 关于--extra-cflags 的参数，该参数包括如下内容：
    # 1、关于cpu的指令优化
    # 2、关于编译器指令有关参数优化
    # 3、指定引用三方库头文件路径或者系统库的路径
    FF_EXTRA_CFLAGS=""
    # 用于./configure 关于--extra-ldflags 的参数
    # 1、指定引用三方库的路径及库名称 比如-L<x264_path> -lx264
    FF_EXTRA_LDFLAGS=
    # 开始编译
    # 导入ffmpeg 的配置
    COMMON_FF_CFG_FLAGS=
    export COMMON_FF_CFG_FLAGS=
    . $FF_BUILD_ROOT/config/module.sh
    
    COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-cross-compile --enable-pic --enable-static --disable-shared --target-os=android --enable-jni"
    if [ $FF_COMPILE_SHARED = "TRUE" ];then
        COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-cross-compile --enable-pic --disable-static --enable-shared --target-os=android --enable-jni "
    fi
    set_flags $FF_ARCH
    
    local NEON_FLAG=
    local TARGET_ARCH=
    local TARGET_CPU=
    local FF_BUILD_NAME2=
    if [ "$FF_ARCH" = "x86_64" ]; then
        NEON_FLAG=" --disable-neon --enable-asm --enable-inline-asm"
        TARGET_CPU="x86_64"
        TARGET_CPU="x86_64"
        
    elif [ "$FF_ARCH" = "arm64" ]; then
        NEON_FLAG=" --enable-neon --enable-asm --enable-inline-asm"
        TARGET_ARCH="aarch64"
        TARGET_CPU="armv8-a"
        FF_BUILD_NAME2=arm64-v8a
    elif [ "$FF_ARCH" = "armv7a" ]; then
        NEON_FLAG=" --enable-neon --enable-asm --enable-inline-asm"
        TARGET_ARCH="armv7-a"
        TARGET_CPU="armv7-a"
        FF_BUILD_NAME2=armeabi-v7a
    else
        echo "unknown architecture $FF_ARCH";
        exit 1
    fi
    export CFLAGS="$CFLAGS"
    FF_SOURCE=$FF_BUILD_ROOT/build/forksource/$FF_BUILD_NAME
    FF_PREFIX=$FF_BUILD_ROOT/build/android-$FF_ARCH/$FF_BUILD_NAME
    if [ $INTERNAL_DEBUG = "TRUE" ];then
        COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-optimizations --enable-debug --disable-small";
    else
        COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-optimizations --disable-debug --enable-small"
    fi
    mkdir -p $FF_PREFIX
    
    # -D__ANDROID_API__=$API 解决用NDK15以后出现的undefined reference to 'stderr'问题
    # 参考官网https://android.googlesource.com/platform/ndk/+/ndk-r15-release/docs/UnifiedHeaders.md
    # -Wno-psabi -Wa,--noexecstack 去掉-Wno-psabi(该选项作用未知) 选项变成 -Wa,--noexecstack;否则会一直打出warning: unknown warning option '-Wno-psabi'的警告
    FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS -O3 -Wall -pipe \
        -std=c99 \
        -ffast-math \
        -fstrict-aliasing -Werror=strict-aliasing \
        -Wa,--noexecstack \
        -DANDROID -DNDEBUG -D__ANDROID_API__=$FF_ANDROID_API"
        
    #硬编解码，不同平台配置参数不一样
    if [ $ENABLE_GPU = "TRUE" ];then
        # 开启Android的MediaCodec GPU解码;ffmpeg只支持GPU解码
        export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-mediacodec --enable-decoder=h264_mediacodec"
    fi
    
    #导入ffmpeg的外部库，这里指定外部库的路径，配置参数则转移到了config/module.sh中
    EXT_ALL_LIBS=
    #${#array[@]}获取数组长度用于循环
    for(( i=$x264;i<${#LIBS_PKGS[@]};i++))
    do
        lib_pkg=${LIBS_PKGS[i]};
        if [[ ${LIBFLAGS[i]} == "TRUE" ]];then

            COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS ${LIBS_PARAM[i]}"

            FF_EXTRA_CFLAGS+=" $(pkg-config --cflags $lib_pkg)"
            FF_EXTRA_LDFLAGS+=" $(pkg-config --libs --static $lib_pkg)"
        fi
    done
    
    echo ""
    echo "build ffmpeg $FF_ARCH........$FF_SYSROOT"
    echo "FF_CFG_FLAGS $COMMON_FF_CFG_FLAGS"
    
    cd $FF_SOURCE
    set +e
    make distclean
    set -e
    ./configure $COMMON_FF_CFG_FLAGS \
        --cross-prefix="${FF_CROSS_PREFIX}-" \
        --sysroot=${FF_SYSROOT} \
        --prefix=${FF_PREFIX} \
        --pkg-config="${HOST_PKG_CONFIG_PATH}" \
        --arch="${TARGET_ARCH}" \
        --cpu="${TARGET_CPU}" \
        --ar="${AR}" \
        --cc="${CC}" \
        --cxx="${CXX}" \
        --as="${AS}" \
        --ranlib="${RANLIB}" \
        --strip="${STRIP}" \
        --extra-cflags="$FF_EXTRA_CFLAGS" \
        --extra-ldflags="$FF_EXTRA_LDFLAGS" \
        ${NEON_FLAG} \
        --ln_s="cp -rf" \

    make -j$(get_cpu_count) && make install || exit 1
    cd -
}

# 编译外部库
function compile_external_lib_ifneed()
{
    local FF_ARCH=$1
    local TYPE=a
    if [ $FF_COMPILE_SHARED = "TRUE" ];then
        TYPE=so
    fi
    for i in $(echo ${!LIBFLAGS[@]})
    do
        local lib=${LIBS[i]};
        if [ $lib = "ffmpeg" ];then
            continue
        fi
        
        local FF_BUILD_NAME=$lib
        local FFMPEG_DEP_LIB=$UNI_BUILD_ROOT/build/android-$FF_ARCH/$FF_BUILD_NAME/lib

        if [[ ${LIBFLAGS[i]} == "TRUE" ]]; then
            if [ ! -f "${FFMPEG_DEP_LIB}/lib$lib.$TYPE" ]; then
                # 编译
                if [ $lib = "fdk-aac" ];then
                    lib=fdk_aac
                fi
                do_compile_$lib $FF_ARCH $target_ios $FF_ARCH
            fi
        fi
    done;
}

do_lipo_all () {
    TYPE=a
    if [ $FF_COMPILE_SHARED = "TRUE" ];then
        TYPE=so
    fi
    for ARCH in $FF_ALL_ARCHS_ANDROID
    do
        ARCH2=
        if [ "$ARCH" = "x86_64" ]; then
            ARCH2=x86_64
        elif [ "$ARCH" = "arm64" ]; then
            ARCH2=arm64-v8a
        elif [ "$ARCH" = "armv7a" ]; then
            ARCH2=armeabi-v7a
        else
            echo "unknown architecture 1 $ARCH";
            exit 1
        fi
        
        # for external lib
        for(( i=$x264;i<${#LIBS[@]};i++))
        do
            lib=${LIBS[i]};
            uni_inc_dir=$UNI_BUILD_ROOT/build/android-universal/$ARCH2/$lib
            uni_lib_dir=$UNI_BUILD_ROOT/build/android-universal/$ARCH2/all-$TYPE
            if [[ ${LIBFLAGS[i]} == "TRUE" ]]; then
                mkdir -p $uni_lib_dir
                mkdir -p $uni_inc_dir
                cp -rf $UNI_BUILD_ROOT/build/android-arm64/$lib/include $uni_inc_dir
                if [ $INTERNAL_DEBUG = "TRUE" ];then
                    cp $UNI_BUILD_ROOT/build/android-$ARCH/$lib/lib/lib*.$TYPE /Users/apple/devoloper/mine/ffmpeg/ffmpeg-demo/demo-android/app/src/main/jniLibs/$ARCH2
                else
                    cp $UNI_BUILD_ROOT/build/android-$ARCH/$lib/lib/lib*.$TYPE $uni_lib_dir
                fi
            fi
        done
        
        # for ffmpeg
        local FF_FFMPEG_LIBS="libavcodec libavfilter libavformat libavutil libswscale libswresample"
        if [[ ${LIBFLAGS[$ffmpeg]} = "FALSE" ]]; then
            echo "set [ffmpeg]=TRUE first"
            exit 1
        fi
        
        uni_inc_dir=$UNI_BUILD_ROOT/build/android-universal/$ARCH2/ffmpeg
        mkdir -p $uni_inc_dir
        cp -rf $UNI_BUILD_ROOT/build/android-arm64/ffmpeg/include $uni_inc_dir
        for lib in $FF_FFMPEG_LIBS
        do
            uni_lib_dir=$UNI_BUILD_ROOT/build/android-universal/$ARCH2/all-$TYPE
            
            mkdir -p $uni_lib_dir
            
            if [ $INTERNAL_DEBUG = "TRUE" ];then
                cp $UNI_BUILD_ROOT/build/android-$ARCH/ffmpeg/lib/$lib.$TYPE /Users/apple/devoloper/mine/ffmpeg/ffmpeg-demo/demo-android/app/src/main/jniLibs/$ARCH2/$lib.$TYPE
            else
                cp $UNI_BUILD_ROOT/build/android-$ARCH/ffmpeg/lib/$lib.$TYPE $uni_lib_dir/$lib.$TYPE
            fi
        done
    done

}

# 命令开始执行处----------
if [ -z "$FF_TARGET" ]; then
    
    # 检查编译环境以及根据情况是否需要拉取源码
    prepare_all android $FF_ALL_ARCHS_ANDROID
    
    for ARCH in $FF_ALL_ARCHS_ANDROID
    do
        # 设置编译环境
        set_toolchain_path $ARCH
        # 编译外部库，已经编译过则跳过。如果要重新编译，删除build下的外部库
        compile_external_lib_ifneed $ARCH
        # 编译ffmpeg
        rm -rf build/android-$ARCH/ffmpeg
        rm -rf build/android-universal
        do_compile_ffmpeg $ARCH
    done
    
    # 合并库
    do_lipo_all
elif [[ "$FF_TARGET" == clean-* ]]; then
    
    # 清除对应库forksource下的源码目录和build目录
    name=${FF_TARGET#clean-*}
    rm_fork_source $name
    rm_build android $name $FF_ALL_ARCHS_ANDROID
elif [ "$FF_TARGET" == "--help" ]; then
    echo "Usage:"
    echo "  compile-android.sh"
    echo "  compile-android.sh clean-all|clean-*  (default clean ffmpeg,clean-x264 will clean x264)"
    exit 1
fi
