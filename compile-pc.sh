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
. ./common.sh

#当前Linux/Windows/Mac操作系统的位数，如果是64位则填写x86_64，32位则填写x86
export FF_PC_ARCH="x86_64"

# 是否编译这些库;如果不编译将对应的值改为FALSE即可；如果ffmpeg对应的值为TRUE时，还会将其它库引入ffmpeg中，否则单独编译其它库
export LIBFLAGS=(
[ffmpeg]=TRUE [x264]=TRUE [fdkaac]=TRUE [mp3lame]=TRUE [fribidi]=TRUE [freetype]=TRUE [ass]=TRUE
)

# 内部调试用
export INTERNAL_DEBUG=TRUE

# 是否开启ffplay ffmpeg ffprobe的编译；默认关闭
export ENABLE_FFMPEG_TOOLS=FALSE

# 是否开启硬编解码；默认开启(tips:目前只支持mac的硬编解码编译)
export ENABLE_GPU=TRUE

# $0 当前脚本的文件名
# $1 表示执行shell脚本时输入的第一个参数 比如./compile-ffmpeg-pc.sh arm64 x86_64 $1的值为arm64;$2的值为x86_64
# $# 传递给脚本或函数的参数个数。
# $* 传递给脚本或者函数的所有参数;
# $@ 传递给脚本或者函数的所有参数;
# 两者区别就是 不被双引号(" ")包含时，都以"$1" "$2" … "$n" 的形式输出所有参数。而"$*"表示"$1 $2 … $n";
# "$@"依然为"$1" "$2" … "$n"
# $$ 脚本所在的进程ID
# $? 上个命令的退出状态，或函数的返回值。一般命令返回值 执行成功返回0 失败返回1
UNI_BUILD_ROOT=`pwd`
FF_PC_TARGET=$1
FF_PC_ACTION=$2
export FF_PLATFORM_TARGET=$1

real-do-compile()
{	
	CONFIGURE_FLAGS=$1
	lib=$2
	SOURCE=$UNI_BUILD_ROOT/build/forksource/$lib
	PREFIX=$UNI_BUILD_ROOT/build/$FF_PC_TARGET-$FF_PC_ARCH/$lib
	cd $SOURCE
	
	echo ""
	echo "build $lib $FF_PC_ARCH ......."
	echo "CONFIGURE_FLAGS:$CONFIGURE_FLAGS"
	echo "prefix:$PREFIX"
	echo ""
    
    set +e
    make distclean
    set -e
    
	./configure \
	${CONFIGURE_FLAGS} \
	--prefix=$PREFIX 

	make -j$(get_cpu_count) && make install || exit 1
	
	cd -
}

#编译x264
do-compile-x264()
{	
	CONFIGURE_FLAGS="--enable-static --enable-shared --enable-pic --disable-cli --enable-strip"
	real-do-compile "$CONFIGURE_FLAGS" "x264"
}

#编译fdk-aac
do-compile-fdk-aac()
{
	CONFIGURE_FLAGS="--enable-static --enable-shared --with-pic "
	real-do-compile "$CONFIGURE_FLAGS" "fdk-aac"
}
#编译mp3lame
do-compile-mp3lame()
{
	#遇到问题：mp3lame连接时提示"export lame_init_old: symbol not defined"
	#分析原因：未找到这个函数的实现
	#解决方案：删除libmp3lame.sym中的lame_init_old
	SOURCE=./build/forksource/mp3lame/include/libmp3lame.sym
	$OUR_SED "/lame_init_old/d" $SOURCE
	
	CONFIGURE_FLAGS="--enable-static --enable-shared --disable-frontend "
	real-do-compile "$CONFIGURE_FLAGS" "mp3lame"
}
#编译ass
do-compile-ass()
{
    if [ ! -f $UNI_BUILD_ROOT/build/forksource/ass/configure ];then
        SOURCE=$UNI_BUILD_ROOT/build/forksource/ass
        cd $SOURCE
        ./autogen.sh
        cd -
    fi
    
    CONFIGURE_FLAGS="--with-pic --disable-libtool-lock --enable-static --enable-shared --disable-fontconfig --disable-harfbuzz --disable-fast-install --disable-test --enable-coretext --disable-require-system-font-provider --disable-profile "
    real-do-compile "$CONFIGURE_FLAGS" "ass"
}
#编译freetype
do-compile-freetype()
{
    CONFIGURE_FLAGS="--with-pic --with-zlib --without-png --without-harfbuzz --without-bzip2 --without-fsref --without-quickdraw-toolbox --without-quickdraw-carbon --without-ats --disable-fast-install --disable-mmap --enable-static --enable-shared "
    real-do-compile "$CONFIGURE_FLAGS" "freetype"
}
#编译fribidi
do-compile-fribidi()
{
    if [ ! -f $UNI_BUILD_ROOT/build/forksource/fribidi/configure ];then
        SOURCE=$UNI_BUILD_ROOT/build/forksource/fribidi
        cd $SOURCE
        ./autogen.sh
        cd -
    fi
    CONFIGURE_FLAGS="--with-pic --enable-static --enable-shared --disable-fast-install --disable-debug --disable-deprecated "
    real-do-compile "$CONFIGURE_FLAGS" "fribidi"
}
#编译png
do-compile-png()
{
    CONFIGURE_FLAGS="--with-pic --enable-static --enable-shared --disable-fast-install --disable-unversioned-libpng-pc --disable-unversioned-libpng-config "
    real-do-compile "$CONFIGURE_FLAGS" "png"
}

# 编译外部库
compile_external_lib_ifneed()
{
    for lib in $(echo ${!LIBFLAGS[*]})
    do
        FFMPEG_DEP_LIB=$UNI_BUILD_ROOT/build/$FF_PC_TARGET-$FF_PC_ARCH/${LIBS[$lib]}/lib
        
        if [[ ${LIBFLAGS[$lib]} == "TRUE" ]] && [[ ${LIBS[$lib]} != "ffmpeg" ]]; then
            if [[ ! -f "${FFMPEG_DEP_LIB}/lib${LIBS[$lib]}.a" && ! -f "${FFMPEG_DEP_LIB}/lib${LIBS[$lib]}.dll.a" && ! -f "${FFMPEG_DEP_LIB}/lib${LIBS[$lib]}.so" ]] ; then
                # 编译
                do-compile-${LIBS[$lib]}
            fi
        fi
    done;
}

do-compile-ffmpeg()
{
    if [ ${LIBFLAGS[$ffmpeg]} == "FALSE" ];then
        echo "config not build ffmpeg....return"
        return
    fi
    
	FF_BUILD_NAME=ffmpeg
	FF_BUILD_ROOT=`pwd`

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
	
	FF_SOURCE=$FF_BUILD_ROOT/build/forksource/$FF_BUILD_NAME
	FF_PREFIX=$FF_BUILD_ROOT/build/$FF_PC_TARGET-$FF_PC_ARCH/$FF_BUILD_NAME
    if [ $INTERNAL_DEBUG = "TRUE" ];then
        FF_PREFIX=/Users/apple/devoloper/mine/ffmpeg/ffmpeg-demo/demo-mac/ffmpeglib
    fi
	mkdir -p $FF_PREFIX

	# 开始编译
	# 导入ffmpeg 的配置
	export COMMON_FF_CFG_FLAGS=
		. $FF_BUILD_ROOT/../config/module.sh
	
    #硬编解码，不同平台配置参数不一样
    if [ $ENABLE_GPU = "TRUE" ] && [ $FF_PC_TARGET = "mac" ];then
        # 开启Mac/IOS的videotoolbox GPU编码
        export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-encoder=h264_videotoolbox"
        # 开启Mac/IOS的videotoolbox GPU解码
        export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-hwaccel=h264_videotoolbox"
    fi
    
	#导入ffmpeg的外部库，这里指定外部库的路径，配置参数则转移到了config/module.sh中
	EXT_ALL_LIBS=
	#${#array[@]}获取数组长度用于循环
	for(( i=1;i<${#LIBS[@]};i++))
	do
		lib=${LIBS[i]};
		lib_inc_dir=$FF_BUILD_ROOT/build/$FF_PC_TARGET-$FF_PC_ARCH/$lib/include
		lib_lib_dir=$FF_BUILD_ROOT/build/$FF_PC_TARGET-$FF_PC_ARCH/$lib/lib
		if [[ ${LIBFLAGS[i]} == "TRUE" ]] && [[ ! -z ${LIBS_PARAM[i]} ]];then

			COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS ${LIBS_PARAM[i]}"

			FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS -I${lib_inc_dir}"
			FF_EXTRA_LDFLAGS="$FF_EXTRA_LDFLAGS -L${lib_lib_dir}"
        
			EXT_ALL_LIBS="$EXT_ALL_LIBS $lib_lib_dir/lib$lib.a"
		fi
	done

	FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS $FF_CFG_FLAGS"

	# 进行裁剪
    FF_CFG_FLAGS="$FF_CFG_FLAGS";
    if [ $ENABLE_FFMPEG_TOOLS="TRUE" ];then
        FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-ffmpeg --enable-ffplay --enable-ffprobe";
    fi
    
	# 开启调试;如果关闭 则注释即可
	#FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-debug --disable-optimizations";
	#--------------------
	
    if [ $FF_PC_TARGET = "mac" ];then
        # 当执行过一次./configure 会在源码根目录生成config.h文件
        # which 是根据使用者所配置的 PATH 变量内的目录去搜寻可执行文件路径，并且输出该路径
        # fixbug:mac osX 10.15.4 (19E266)和Version 11.4 (11E146)生成的库在调用libx264编码的avcodec_open2()函数
        # 时奔溃(报错stack_not_16_byte_aligned_error)，添加编译参数--disable-optimizations解决问题(fix：2020.5.2)
        FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-ffmpeg --enable-ffplay --disable-optimizations";
    fi
    
	echo ""
	echo "--------------------"
	echo "[*] configurate ffmpeg"
	echo "--------------------"
	echo "FF_CFG_FLAGS=$FF_CFG_FLAGS"
	echo "--extra-cflags=$FF_EXTRA_CFLAGS"
	echo "--extra-ldflags=$FF_EXTRA_LDFLAGS"

	cd $FF_SOURCE
    set +e
    make distclean
    set -e
    ./configure $FF_CFG_FLAGS \
        --prefix=$FF_PREFIX \
        --extra-cflags="$FF_EXTRA_CFLAGS" \
        --extra-ldflags="$FF_EXTRA_LDFLAGS" \
    

	#------- 编译和连接 -------------
	#生成各个模块对应的静态或者动态库(取决于前面是生成静态还是动态库)
	echo ""
	echo "--------------------"
	echo "[*] compile ffmpeg"
	echo "--------------------"
	cp config.* $FF_PREFIX
	make && make install
	mkdir -p $FF_PREFIX/include/libffmpeg
	cp -f config.h $FF_PREFIX/include/libffmpeg/config.h
	# 拷贝外部库
	for lib in $EXT_ALL_LIBS
	do
		cp -f $lib $FF_PREFIX/lib
	done
	cd -
}

useage()
{
    echo "Usage:"
    echo "  compile-ffmpeg-pc.sh mac|windows|linux"
    echo "  compile-ffmpeg-pc.sh mac|windows|linux clean-all|clean-*  (default clean ffmpeg,clean-x264 will clean x264)"
    exit 1
}

# 命令开始执行处----------
if [ "$FF_PC_TARGET" != "mac" ] && [ "$FF_PC_TARGET" != "windows" ] && [ "$FF_PC_TARGET" != "linux" ]; then
    useage
fi

# 检查是否安装了pkg-config;linux和windows才需要安装pkg-config
if [ "$FF_PC_TARGET" != "mac" ] && [ ! `which pkg-config` ]; then
    echo "check pkg-config env......"
    echo "pkg-config not found begin install....."
    apt-cyg install pkg-config || exit 1
    echo -e "check pkg-config ok......"
fi

#=== sh脚本执行开始 ==== #
# $FF_PC_ACTION 表示脚本执行时输入的第一个参数
case "$FF_PC_ACTION" in
    clean-*)
        # 清除对应库forksource下的源码目录和build目录
        name=${FF_PC_ACTION#clean-*}
        rm_fork_source $FF_PC_TARGET $name $FF_PC_ARCH
        rm_build $FF_PC_TARGET $name $FF_PC_ARCH
            
        #    echo "clean ffmpeg"
        #    cd $FF_PC_TARGET/forksource/ffmpeg && git clean -xdf && cd -
        #    echo "clean build cache"
        #    rm -rf $FF_PC_TARGET/build/ffmpeg-*
        #    echo "clean success"
    ;;
    *)
        prepare_all $FF_PC_TARGET $FF_PC_ARCH
        
        rm -rf build/$FF_PC_TARGET-$FF_PC_ARCH/ffmpeg
        
        # 先编译外部库
        compile_external_lib_ifneed
        
        # 最后编译ffmpeg
        do-compile-ffmpeg
    ;;
esac
