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

# 由于目前设备基本都是电脑64位 手机64位 所以这里脚本默认只支持 arm64 x86_64两个平台
# FF_ALL_ARCHS_IOS="armv7 armv7s arm64 i386 x86_64"
#export FF_ALL_ARCHS_IOS="arm64e arm64 x86_64"
export FF_ALL_ARCHS_IOS="arm64 x86_64"
target_ios=10.0

# libass使用Coretext还是fontconfig;TRUE代表使用CORETEXT,FALSE代表使用fontconfig
export USE_CORETEXT=FALSE
# 是否编译这些库;如果不编译将对应的值改为FALSE即可；如果ffmpeg对应的值为TRUE时，还会将其它库引入ffmpeg中，否则单独编译其它库
if [ $USE_CORETEXT = "TRUE" ];then
export LIBFLAGS=(
[ffmpeg]=TRUE [x264]=TRUE [fdkaac]=FALSE [mp3lame]=TRUE [fribidi]=TRUE [freetype]=TRUE [ass]=TRUE [openssl]=FALSE
)
else
export LIBFLAGS=(
[ffmpeg]=TRUE [x264]=TRUE [fdkaac]=FALSE [mp3lame]=TRUE [fribidi]=TRUE [freetype]=TRUE [expat]=TRUE [fontconfig]=TRUE [ass]=TRUE [openssl]=FALSE
)
fi

# 内部调试用
export INTERNAL_DEBUG=FALSE
# 开启硬编解码
ENABLE_GPU=TRUE

UNI_BUILD_ROOT=`pwd`
FF_TARGET=$1
#----------
# 配置交叉编译环境
set_toolchain_path()
{
    local ARCH=$1
    local PLATFORM=
    case $ARCH in
    arm64|arm64e)
        local PLATFORM=iphoneos
    ;;
    x86_64)
        local PLATFORM=iphonesimulator
    ;;
    esac
    mkdir -p ${UNI_BUILD_ROOT}/build/ios-$ARCH/pkgconfig
    
    HOST_PKG_CONFIG_PATH=`command -v pkg-config`
    if [ -z ${HOST_PKG_CONFIG_PATH} ]; then
        echo -e "pkg-config command not found\n"
        exit 1
    fi
    export HOST_PKG_CONFIG_PATH
    
    # xcrun 是调用iOS交叉编译工具的命令 通过xcrun --help 可以查看具体使用，后面跟具体的编译工具 如ar cc等等
    # 定义编译工具CC CXX AR等必须要用export进行声明，否则没有效果;-f代表输出对应工具的绝对路径;如下CC和CXX只要直接使用clang和clang++(否则编译mp3lame库会出错，原因未知:fixbug)
    export CC=clang
    export CXX=clang++
    export AR=$(xcrun --sdk $PLATFORM -f ar)
    export OBJC=$(xcrun --sdk $PLATFORM -f clang)
    export LD=$(xcrun --sdk $PLATFORM -f ld)
    export RANLIB=$(xcrun --sdk $PLATFORM -f ranlib)
    export STRIP=$(xcrun --sdk $PLATFORM -f strip)
    export SDKPATH=$(xcrun --sdk $PLATFORM --show-sdk-path)
    export PKG_CONFIG_LIBDIR="${UNI_BUILD_ROOT}/build/ios-$ARCH/pkgconfig"
    export ZLIB_PACKAGE_CONFIG_PATH="${PKG_CONFIG_LIBDIR}/zlib.pc"
    export BZIP2_PACKAGE_CONFIG_PATH="${PKG_CONFIG_LIBDIR}/bzip2.pc"
    export LIB_ICONV_PACKAGE_CONFIG_PATH="${PKG_CONFIG_LIBDIR}/libiconv.pc"
    export LIB_UUID_PACKAGE_CONFIG_PATH="${PKG_CONFIG_LIBDIR}/uuid.pc"
    
    if [ ! -f ${ZLIB_PACKAGE_CONFIG_PATH} ]; then
        create_zlib_system_package_config $SDKPATH $PKG_CONFIG_LIBDIR
    fi

    if [ ! -f ${LIB_ICONV_PACKAGE_CONFIG_PATH} ]; then
        create_libiconv_system_package_config $SDKPATH $PKG_CONFIG_LIBDIR
    fi

    if [ ! -f ${BZIP2_PACKAGE_CONFIG_PATH} ]; then
        create_bzip2_system_package_config $SDKPATH $PKG_CONFIG_LIBDIR
    fi

    if [ ! -f ${LIB_UUID_PACKAGE_CONFIG_PATH} ]; then
        create_libuuid_system_package_config $SDKPATH $PKG_CONFIG_LIBDIR
    fi
}
set_flags()
{
    ARCH=$1
    # 用来配置编译器参数，一般包括如下几个部分：
    # 1、平台cpu架构相关的参数，比如arm64、x86_64不同cpu架构相关的参数也不一样，一般是固定的
    # 2、编译器相关参数，比如std=c99，不同的库所使用的语言以及语言的版本等等
    # 3、编译器优化相关参数，这部分参数往往跟平台以及库无关，比如-O2 -Wno-ignored-optimization-argument等等加快编译进度的参数 -g开启编译调试信息
    # 4、系统路径以及系统版本等相关参数 -isysroot=<SDK_PATH> -I<SDK_PATH>/usr/include
    # 遇到问题：真机使用fontconfig库时奔溃
    # 分析原因：通过查看fontconfig库源码发现头文件fcatomic.h中有宏定义__IPHONE_VERSION_MIN_REQUIRED时才引入<Availability.h>，所以编译时不加此宏定义就会导致崩溃
    # 解决方案：编译时添加宏定义__IPHONE_VERSION_MIN_REQUIRED
    CFLAGS=
    ASM_FLAGS=
    if [ $ARCH = "x86_64" ];then
        PLATFORM="iphonesimulator"
        CFLAGS="-arch x86_64 -march=x86-64 -msse4.2 -mpopcnt -m64 -mtune=intel"
        CFLAGS="$CFLAGS -mios-simulator-version-min=$target_ios"
        HOST=x86_64-ios-darwin
        ASM_FLAGS="--disable-asm"
    elif [ $ARCH = "arm64" ];then
        PLATFORM="iphoneos"
        CFLAGS="-arch arm64 -march=armv8-a+crc+crypto -mcpu=generic"
        CFLAGS="$CFLAGS -miphoneos-version-min=$target_ios -fembed-bitcode -D__IPHONE_OS_MIN_REQUIRED -D__IPHONE_VERSION_MIN_REQUIRED=30000"
        HOST=aarch64-ios-darwin
        ASM_FLAGS="--enable-asm"
    elif [ $ARCH = "arm64e" ];then
        PLATFORM="iphoneos"
        CFLAGS="-arch arm64e -march=armv8.3-a+crc+crypto -mcpu=generic"
        CFLAGS="$CFLAGS -miphoneos-version-min=$target_ios -fembed-bitcode -D__IPHONE_OS_MIN_REQUIRED -D__IPHONE_VERSION_MIN_REQUIRED=30000"
        HOST=aarch64-ios-darwin
        ASM_FLAGS="--enable-asm"
    else
        echo "unsurported platform $ARCH !...."
        exit 1
    fi
    
    # -target参数一般没用(用于编译一个编译器的时候才有用)
    CFLAGS="$CFLAGS -DIOS -target $HOST"
    # -isysroot 指定了交叉编译系统的根路径，那么所有交叉编译工具或者其它相关的搜索路径都将基于此(如果不指定将按照本机/导致搜索不到路径而编译失败)
    # -I和-L指定了系统库的搜索路径，也可以在下面通过configure的配置参数--with-sysroot来指定，效果一样。
    CFLAGS="$CFLAGS -isysroot $SDKPATH -I$SDKPATH/usr/include"
    LDFLAGS="$CFLAGS -L${SDKPATH}/usr/lib -lc++"
    CXXFLAGS="$CFLAGS"
    CPPFLAGS="$CFLAGS"
    
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
    SYS_ROOT_CONF="--with-sysroot=${SDKPATH}"
    GAS_PL="gas-preprocessor.pl"
    if [ $lib = "x264" ];then
        SYS_ROOT_CONF="--sysroot=${SDKPATH}"
        GAS_PL="$SOURCE/tools/gas-preprocessor.pl"
        CONFIGURE_FLAGS="$CONFIGURE_FLAGS $ASM_FLAGS"
    elif [ $lib = "fontconfig" ];then
        SYS_ROOT_CONF=
    elif [ $lib = "ass" ];then
        CONFIGURE_FLAGS="$CONFIGURE_FLAGS $ASM_FLAGS"
    elif [ $lib = "fdk-aac" ];then
        CFLAGS="$CFLAGS -Wno-error=unused-command-line-argument-hard-error-in-future"
    else
        # C语言标准，clang编译器默认使用gnu99的C语言标准。不同的库可能使用的C语言标准不一样，不过一般影响不大，如果有影响则需要特别指定
        # -Wunused表示所有未使用给与警告(-Wunused-xx 表示具体的未使用警告,-Wno-unused-xxx 表示取消具体未使用警告)
        CFLAGS="$CFLAGS -Wunused-function"
    fi
    
    case $ARCH in
        arm64|arm64e)
            export AS="$GAS_PL -arch aarch64 -- ${CC} ${CFLAGS}"
        ;;
        *)
            export AS="${CC} ${CFLAGS}"
        ;;
    esac
    
    # 像CC AR CFLAGS CXXFLAGS等等这一类makefile用于配置编译器参数的环境变量一定要用export导入，否则不会生效
    export CFLAGS
    export CXXFLAGS
    export LDFLAGS
    export CPPFLAGS
    export SYS_ROOT_CONF
}

real_do_compile()
{
    local CONFIGURE_FLAGS=$1
    local lib=$2
    local ARCH=$3
    local SOURCE=$UNI_BUILD_ROOT/build/forksource/$lib
    local PREFIX=$UNI_BUILD_ROOT/build/ios-$ARCH/$lib
    cd $SOURCE
    
    echo ""
    echo "build $lib $ARCH ......."
    echo "CONFIGURE_FLAGS:$CONFIGURE_FLAGS"
    echo "prefix:$PREFIX"
    echo ""
    
    set_flags $ARCH
    
    set +e
    make distclean
    set -e
    if [ $lib = "ssl" ];then
        local arch_flags=
        if [ $ARCH = "x86_64" ];then
            arch_flags=darwin64-x86_64-cc
        elif [ $ARCH = "arm64" ];then
            arch_flags=iphoneos-cross
        elif [ $ARCH = "arm64e" ];then
            arch_flags=iphoneos-cross
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
            $SYS_ROOT_CONF  \
            $ASM_FLAGS
            
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
    # iOS x264 暂时无法编译动态库；会提示"ld: -read_only_relocs and -bitcode_bundle (Xcode setting ENABLE_BITCODE=YES) cannot be used together"
    local CONFIGURE_FLAGS="--enable-static --enable-pic --disable-cli --enable-strip"
    real_do_compile "$CONFIGURE_FLAGS" "x264" $1
}

#编译fdk-aac
do_compile_fdk_aac()
{
    local CONFIGURE_FLAGS="--enable-static --enable-shared --with-pic=yes "
    real_do_compile "$CONFIGURE_FLAGS" "fdk-aac" $1
}
#编译mp3lame
do_compile_mp3lame()
{
    local CONFIGURE_FLAGS="--enable-static --disable-shared --with-pic --disable-fast-install --disable-maintainer-mode --disable-frontend --disable-efence --disable-gtktest"
    real_do_compile "$CONFIGURE_FLAGS" "mp3lame" $1
}
#编译ass
do_compile_ass()
{
    # ass 依赖于freetype和fribidi，所以需要检查一下
    local pkgpath=$UNI_BUILD_ROOT/build/ios-$1/pkgconfig
    if [ ! -f $pkgpath/freetype2.pc ];then
        echo "libass dependency freetype please set [freetype]=TRUE "
        exit 1
    fi
    if [ ! -f $pkgpath/fribidi.pc ];then
        echo "libass dependency fribidi please set [fribidi]=TRUE "
        exit 1
    fi
    if [[ ! -f $pkgpath/fontconfig.pc && USE_CORETEXT="FALSE" ]];then
        echo "libfontconfig dependency fribidi please set [fontconfig]=TRUE "
        exit 1
    fi
    
    if [ ! -f $UNI_BUILD_ROOT/build/forksource/ass/configure ];then
        local SOURCE=$UNI_BUILD_ROOT/build/forksource/ass
        cd $SOURCE
        ./autogen.sh
        cd -
    fi
    
    local CONFIGURE_FLAGS="--with-pic --disable-libtool-lock --enable-static --enable-shared --disable-fontconfig --disable-harfbuzz --disable-fast-install --disable-test --enable-coretext --disable-require-system-font-provider --disable-profile "
    if [ $USE_CORETEXT = "FALSE" ];then
    CONFIGURE_FLAGS="--with-pic --disable-libtool-lock --enable-static --disable-shared --enable-fontconfig --disable-harfbuzz --disable-fast-install --disable-test --disable-profile --disable-coretext "
    fi
    real_do_compile "$CONFIGURE_FLAGS" "ass" $1
}
#编译freetype
do_compile_freetype()
{
    local CONFIGURE_FLAGS="--with-pic --with-zlib --without-png --without-harfbuzz --without-bzip2 --without-fsref --without-quickdraw-toolbox --without-quickdraw-carbon --without-ats --disable-fast-install --disable-mmap --enable-static --disable-shared "
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
    real_do_compile "$CONFIGURE_FLAGS" "fribidi" $1
}
#编译expact
do_compile_expat()
{
    local CONFIGURE_FLAGS="--with-pic --enable-static --disable-shared --disable-fast-install --without-docbook --without-xmlwf "
    real_do_compile "$CONFIGURE_FLAGS" "expat" $1
}
#编译fontconfig
do_compile_fontconfig()
{
    if [[ ! -f $UNI_BUILD_ROOT/build/ios-$1/expat/lib/libexpat.a ]];then
        echo "fontconfig dependency expat please set [expat]=TRUE "
        exit 1
    fi
    
    cd $UNI_BUILD_ROOT/build/forksource/fontconfig/test
    rm -f test-bz106632.c
    cp test-bz106618.c test-bz106632.c
    cd -
    
    local CONFIGURE_FLAGS="--with-pic --without-libintl-prefix --enable-static --disable-shared --disable-fast-install --disable-rpath --disable-libxml2 --disable-docs "
    real_do_compile "$CONFIGURE_FLAGS" "fontconfig" $1
}
#编译openssl
do_compile_ssl()
{
    local CONFIGURE_FLAGS="zlib-dynamic no-shared "
    
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
    export COMMON_FF_CFG_FLAGS=
    . $FF_BUILD_ROOT/config/module.sh
    
    COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-cross-compile --enable-pic --enable-static --disable-shared --target-os=darwin --disable-sdl2"
    
    FF_SOURCE=$FF_BUILD_ROOT/build/forksource/$FF_BUILD_NAME
    FF_PREFIX=$FF_BUILD_ROOT/build/ios-$FF_ARCH/$FF_BUILD_NAME
    if [ $INTERNAL_DEBUG = "TRUE" ];then
        COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --disable-optimizations --enable-debug --disable-small";
    else
        COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-optimizations --disable-debug --enable-small"
    fi
    mkdir -p $FF_PREFIX

    set_flags $FF_ARCH
    
    local FF_CFLAGS=
    local NEON_FLAG=
    local TARGET_ARCH=
    local TARGET_CPU=
    local ARCH_OPTIONS=
    if [ "$FF_ARCH" = "x86_64" ]; then
        NEON_FLAG=" --disable-neon"
        TARGET_CPU="x86_64"
        TARGET_CPU="armv8"
        ARCH_OPTIONS="--disable-asm"
    elif [ "$FF_ARCH" = "arm64" ]; then
        NEON_FLAG=" --enable-neon"
        TARGET_ARCH="aarch64"
        TARGET_CPU="armv8"
        ARCH_OPTIONS="--enable-asm"
        FF_CFLAGS="-Wc,-fembed-bitcode"
        FF_GASPP_EXPORT="GASPP_FIX_XCODE5=1"
    elif [ "$FF_ARCH" = "arm64e" ]; then
        NEON_FLAG=" --enable-neon"
        TARGET_ARCH="aarch64"
        TARGET_CPU="armv8.3-a"
        ARCH_OPTIONS="--enable-asm"
        FF_CFLAGS="-Wc,-fembed-bitcode"
        FF_GASPP_EXPORT="GASPP_FIX_XCODE5=1"
    else
        echo "unknown architecture $FF_ARCH";
        exit 1
    fi
    export CFLAGS="$CFLAGS $FF_CFLAGS"
    
    #硬编解码，不同平台配置参数不一样
    if [ $ENABLE_GPU = "TRUE" ];then
        # 开启Mac/IOS的videotoolbox GPU编码
        export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-encoder=h264_videotoolbox"
        # 开启Mac/IOS的videotoolbox GPU解码
        export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-hwaccel=h264_videotoolbox"
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
    echo "build ffmpeg $FF_ARCH........"
    echo "FF_CFG_FLAGS $COMMON_FF_CFG_FLAGS"
    
    cd $FF_SOURCE
    set +e
    make distclean
    set -e
    ./configure $COMMON_FF_CFG_FLAGS \
        --sysroot=${SDKPATH} \
        --prefix=${FF_PREFIX} \
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
        ${ARCH_OPTIONS} \

    make -j$(get_cpu_count) && make install || exit 1
    cd -
}

# 编译外部库
function compile_external_lib_ifneed()
{
    local FF_ARCH=$1
    
    for i in $(echo ${!LIBFLAGS[@]})
    do
        local lib=${LIBS[i]};
        if [ $lib = "ffmpeg" ];then
            continue
        fi
        
        local FF_BUILD_NAME=$lib
        local FFMPEG_DEP_LIB=$UNI_BUILD_ROOT/build/ios-$FF_ARCH/$FF_BUILD_NAME/lib

        if [[ ${LIBFLAGS[i]} == "TRUE" ]]; then
            if [ ! -f "${FFMPEG_DEP_LIB}/lib$lib.a" ]; then
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
    
    # for external lib
    for(( i=$x264;i<${#LIBS[@]};i++))
    do
        lib=${LIBS[i]};
        uni_lib_dir=$UNI_BUILD_ROOT/build/ios-universal/$lib/lib
        uni_inc_dir=$UNI_BUILD_ROOT/build/ios-universal/$lib/include
        if [[ ${LIBFLAGS[i]} == "TRUE" ]]; then
            mkdir -p $uni_lib_dir
            mkdir -p $uni_inc_dir
            cp -rf $UNI_BUILD_ROOT/build/ios-arm64/$lib/include $uni_inc_dir
        fi
        ARCH_LIB_FILE=
        ARCH_LIB_FILE2=
        for ARCH in $FF_ALL_ARCHS_IOS
        do
            if [[ ${LIBFLAGS[i]} == "TRUE" ]]; then
                if [ $lib = "ssl" ];then
                    ARCH_LIB_FILE+="$UNI_BUILD_ROOT/build/ios-$ARCH/$lib/lib/libssl.a "
                    ARCH_LIB_FILE2+="$UNI_BUILD_ROOT/build/ios-$ARCH/$lib/lib/libcrypto.a "
                else
                    ARCH_LIB_FILE+="$UNI_BUILD_ROOT/build/ios-$ARCH/$lib/lib/lib$lib.a "
                fi
            fi
        done

        if [ ! -z "$ARCH_LIB_FILE" ];then
            if [ $lib = "ssl" ];then
                xcrun lipo -create $ARCH_LIB_FILE -output $uni_lib_dir/liblibssl.a
                xcrun lipo -create $ARCH_LIB_FILE2 -output $uni_lib_dir/libcrypto.a
            else
                xcrun lipo -create $ARCH_LIB_FILE -output $uni_lib_dir/lib$lib.a
            fi
            xcrun lipo -info $uni_lib_dir/lib*.a
        fi
    done

    # for ffmpeg
    local FF_FFMPEG_LIBS="libavcodec libavfilter libavformat libavutil libswscale libswresample"
    if [[ ${LIBFLAGS[$ffmpeg]} = "FALSE" ]]; then
        echo "set [ffmpeg]=TRUE first"
        exit 1
    fi
    uni_inc_dir=$UNI_BUILD_ROOT/build/ios-universal/ffmpeg
    uni_lib_dir=$UNI_BUILD_ROOT/build/ios-universal/ffmpeg/lib
    if [ $INTERNAL_DEBUG = "TRUE" ];then
        uni_lib_dir=/Users/apple/devoloper/mine/ffmpeg/ffmpeg-demo/demo-ios/ffmpeglib/lib
    fi
    mkdir -p $uni_inc_dir
    mkdir -p $uni_lib_dir
    cp -rf $UNI_BUILD_ROOT/build/ios-arm64/ffmpeg/include $uni_inc_dir


    for lib in $FF_FFMPEG_LIBS
    do
        ARCH_LIB_FILE=
        for ARCH in $FF_ALL_ARCHS_IOS
        do
            ARCH_LIB_FILE+="$UNI_BUILD_ROOT/build/ios-$ARCH/ffmpeg/lib/$lib.a "
        done
        xcrun lipo -create $ARCH_LIB_FILE -output $uni_lib_dir/$lib.a
        xcrun lipo -info $uni_lib_dir/$lib.a
    done
    
    # copy external to ffmpeg universal dir
    for(( i=$x264;i<${#LIBS[@]};i++))
    do
        lib=${LIBS[i]};
        
        if [[ ${LIBFLAGS[i]} == "TRUE" ]]; then
            uni_lib_dir1=$UNI_BUILD_ROOT/build/ios-universal/$lib/lib/lib*.a
            cp -r $uni_lib_dir1 $uni_lib_dir
        fi
    done
}

# 命令开始执行处----------
if [ -z "$FF_TARGET" ]; then
    
    # 检查编译环境以及根据情况是否需要拉取源码
    prepare_all ios $FF_ALL_ARCHS_IOS
    
    for ARCH in $FF_ALL_ARCHS_IOS
    do
        # 设置编译环境
        set_toolchain_path $ARCH
        # 编译外部库，已经编译过则跳过。如果要重新编译，删除build下的外部库
        compile_external_lib_ifneed $ARCH
        # 编译ffmpeg
        rm -rf build/ios-$ARCH/ffmpeg
        do_compile_ffmpeg $ARCH
    done
    
    # 合并库
    do_lipo_all
elif [[ "$FF_TARGET" == clean-* ]]; then
    
    # 清除对应库forksource下的源码目录和build目录
    name=${FF_TARGET#clean-*}
    rm_fork_source $name
    rm_build ios $name $FF_ALL_ARCHS_IOS
elif [ "$FF_TARGET" == "--help" ]; then
    echo "Usage:"
    echo "  compile-ios.sh"
    echo "  compile-ios.sh clean-all|clean-*  (default clean ffmpeg,clean-x264 will clean x264)"
    exit 1
fi
